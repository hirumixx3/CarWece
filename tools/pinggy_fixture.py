#!/usr/bin/env python3
"""Independent local SSH and SSH-over-TLS relay fixture (requires paramiko).
It implements SSH remote forwarding and Pinggy's documented /urls API.
It does not claim to emulate public DNS, SNI routing or provider availability.
"""
import base64,hashlib,json,os,socket,ssl,sys,threading,time
from pathlib import Path
import paramiko

root=Path(__file__).resolve().parent.parent
directory=Path(os.environ.get('CARWECE_RELAY_FIXTURE',str(root/'build/pinggy_fixture')));directory.mkdir(parents=True,exist_ok=True)
identity=root/'build/host_identity'
cert=identity/'certificate.pem';key=identity/'key.pem'
context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(cert,key)
host_key=paramiko.RSAKey.generate(2048)
stop=directory/'stop'
if stop.exists():stop.unlink()
lock=threading.Lock();transports=[];serial=0
listener=socket.socket();listener.bind(('127.0.0.1',0));listener.listen(16);listener.settimeout(.4)
pin=base64.urlsafe_b64encode(hashlib.sha256(ssl.PEM_cert_to_DER_cert(cert.read_text())).digest()).decode().rstrip('=')
state={'host':'127.0.0.1','port':listener.getsockname()[1],'tlsPin':pin,'probeLoopback':True,'forwards':{},'sessions':0,'apiCalls':0,'rawSessions':0,'tlsSessions':0,'activeSessions':0}
def save():
 target=directory/'connection.json';temp=directory/'connection.tmp'
 temp.write_text(json.dumps(state));temp.replace(target)
save()
def mode():
 try:return json.loads((directory/'mode.json').read_text()).get('mode','normal')
 except (FileNotFoundError,json.JSONDecodeError):return 'normal'
def pump(left,right):
 try:
  while True:
   data=left.recv(65536)
   if not data:break
   right.sendall(data)
 except Exception:pass
 finally:
  try:left.close()
  except Exception:pass
  try:right.close()
  except Exception:pass
def duplex(left,right):
 threading.Thread(target=pump,args=(left,right),daemon=True).start()
 threading.Thread(target=pump,args=(right,left),daemon=True).start()
class Session(paramiko.ServerInterface):
 def __init__(self,transport,number,selected_mode):
  self.transport=transport;self.name='session-'+str(number)+'.a.pinggy.link'
  self.direct={};self.listeners=[];self.peers=[];self.selected_mode=selected_mode;self.api_calls=0
 def get_allowed_auths(self,username):return 'none,password'
 def check_auth_none(self,username):return paramiko.AUTH_SUCCESSFUL
 def check_auth_password(self,username,password):return paramiko.AUTH_SUCCESSFUL
 def check_channel_request(self,kind,channel_id):
  return paramiko.OPEN_SUCCEEDED if kind=='session' else paramiko.OPEN_FAILED_ADMINISTRATIVELY_PROHIBITED
 def check_global_request(self,kind,msg):return kind.startswith('keepalive')
 def check_channel_pty_request(self,*args):return True
 def check_channel_shell_request(self,channel):
  channel.send(b'Local relay fixture. No public connectivity asserted.\r\n')
  if self.selected_mode=='api_disabled':
   # An edge may advertise its URL in output while /urls is unavailable.
   def announce():
    try:
     channel.send(b'\x1b[32mTLS route: tls://sess')
     time.sleep(.05)
     channel.send((self.name[len('sess'):]+ '\x1b[0m\r\n').encode())
    except Exception:pass
   threading.Thread(target=announce,daemon=True).start()
  return True
 def check_channel_direct_tcpip_request(self,channel_id,origin,destination):
  if destination!=('localhost',4300):return paramiko.OPEN_FAILED_ADMINISTRATIVELY_PROHIBITED
  self.direct[channel_id]=True;return paramiko.OPEN_SUCCEEDED
 def check_port_forward_request(self,address,port):
  if self.selected_mode=='refuse_forward':return False
  public=socket.socket();public.bind(('127.0.0.1',0));public.listen(32);public.settimeout(.3)
  assigned=public.getsockname()[1];self.listeners.append(public)
  with lock:state['forwards'][self.name]=assigned;save()
  def accept():
   while self.transport.is_active() and not stop.exists():
    try:peer,origin=public.accept()
    except socket.timeout:continue
    except OSError:break
    try:
     self.peers.append(peer)
     if self.selected_mode=='broken_public':
      peer.sendall(b'HTTP/1.0 503 Service Unavailable\r\n\r\n');peer.close();continue
     channel=self.transport.open_forwarded_tcpip_channel(origin,(address,assigned))
     duplex(peer,channel)
    except Exception:peer.close()
   public.close()
  threading.Thread(target=accept,daemon=True).start()
  return assigned
 def api(self,channel):
  try:
   request=b'';channel.settimeout(5)
   while b'\r\n\r\n' not in request and len(request)<8192:request+=channel.recv(4096)
   self.api_calls+=1
   with lock:state['apiCalls']+=1;save()
   if self.selected_mode=='api_disabled':
    channel.sendall(b'HTTP/1.0 503 Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n');return
   urls=['tls://'+self.name] if self.selected_mode!='bad_urls' else ['tls://untrusted.invalid']
   if self.selected_mode=='delayed_urls' and self.api_calls<3:urls=[]
   data=json.dumps({'urls':urls}).encode()
   response=b'HTTP/1.0 200 OK\r\nContent-Type: application/json\r\nContent-Length: '+str(len(data)).encode()+b'\r\nConnection: close\r\n\r\n'+data
   channel.sendall(response)
  finally:channel.close()
def serve(raw,number):
 transport=None;session=None
 try:
  selected=mode();raw.settimeout(5)
  first=raw.recv(1,socket.MSG_PEEK)
  is_tls=first==b'\x16'
  if (selected=='raw_only' and is_tls) or (selected=='tls_only' and not is_tls):
   raw.close();return
  secured=context.wrap_socket(raw,server_side=True) if is_tls else raw
  secured.settimeout(None)
  transport=paramiko.Transport(secured);transport.add_server_key(host_key)
  with lock:
   transports.append(transport);state['tlsSessions' if is_tls else 'rawSessions']+=1;state['activeSessions']+=1;save()
  if selected=='drop_ssh':transport.close();return
  session=Session(transport,number,selected);transport.start_server(server=session)
  while transport.is_active() and not stop.exists():
   channel=transport.accept(.3)
   if channel is not None and channel.chanid in session.direct:
    threading.Thread(target=session.api,args=(channel,),daemon=True).start()
 except (OSError,EOFError,paramiko.SSHException):
  pass  # Refused TLS pins and disconnect injection intentionally abort handshakes.
 finally:
  print('SSH control session closed: '+str(number),flush=True)
  if session:
   for peer in session.peers:
    try:peer.shutdown(socket.SHUT_RDWR);peer.close()
    except OSError:pass
   for public in session.listeners:public.close()
  if transport:transport.close()
  else:raw.close()
  if transport:
   with lock:state['activeSessions']-=1;save()
try:
 print('SSH/TLS relay fixture ready',flush=True)
 while not stop.exists():
  try:raw,_=listener.accept()
  except socket.timeout:continue
  serial+=1
  with lock:state['sessions']=serial;save()
  threading.Thread(target=serve,args=(raw,serial),daemon=True).start()
finally:
 listener.close()
 for t in transports:t.close()
