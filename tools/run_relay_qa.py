#!/usr/bin/env python3
"""Run an independent SSH/TLS relay and the game's clients in one environment."""
import argparse,os,shutil,subprocess,sys,time,uuid
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--dart',default=shutil.which('dart'));args=p.parse_args()
if not args.dart:raise SystemExit('Dart não encontrado.')
root=Path(__file__).resolve().parent.parent
folder=root/'build/pinggy_fixture'/('run-'+uuid.uuid4().hex[:12]);folder.mkdir(parents=True,exist_ok=True)
state=folder/'connection.json'
if state.exists():state.unlink()
with (root/'verification/ssh_fixture_v0143.txt').open('w') as log:
 env=os.environ.copy();env['CARWECE_RELAY_FIXTURE']=str(folder)
 relay=subprocess.Popen([sys.executable,str(root/'tools/pinggy_fixture.py')],cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT)
 try:
  limit=time.monotonic()+15
  while not state.exists():
   if relay.poll() is not None or time.monotonic()>limit:raise SystemExit('SSH fixture failed to start')
   time.sleep(.05)
  for script,options,name in [
   ('adaptive_relay_qa.dart',[],'adaptive_relay_v0143.txt'),
   ('relay_faults_qa.dart',[],'relay_faults_v0143.txt'),
   ('friends_qa.dart',['--ssh'],'friends_ssh_tls_v0143.txt'),
   ('friends_qa.dart',['--ssh','--raw'],'friends_ssh_raw_v0143.txt'),
  ]:
   with (root/'verification'/name).open('w') as output:
    r=subprocess.run([args.dart,'-DCARWECE_NETWORK_QA=true','run','tools/'+script,*options],cwd=root,env=env,stdout=output,stderr=subprocess.STDOUT,timeout=120)
   print(name+': '+str(r.returncode),flush=True)
   if r.returncode:raise SystemExit(r.returncode)
 finally:
  (folder/'stop').touch()
  try:relay.wait(timeout=5)
  except subprocess.TimeoutExpired:relay.kill();relay.wait()
