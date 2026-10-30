#!/usr/bin/env python3
"""Create complete, small AAC-LC tracks; original MP3 files are never overwritten.
Requires ffmpeg/ffprobe. Run from the project; optional --originals directory.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess

def run(args):
 return subprocess.run(args,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True).stdout
def probe(path):
 return json.loads(run(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(path)]))
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--originals',type=Path)
 args=parser.parse_args();root=Path(__file__).resolve().parents[1];music=root/'assets/music'
 catalog=json.loads((music/'catalog.json').read_text());rows=[]
 stage=root.parents[1]/'audio_encoding_stage_v0123';stage.mkdir(exist_ok=True)
 for song in catalog['tracks']:
  src=(args.originals or music)/(song['id']+'.mp3');dest=music/(song['id']+'.m4a')
  assert src.is_file(),src
  work=stage/dest.name
  original=probe(src);original_duration=float(original['format']['duration'])
  run(['ffmpeg','-v','error','-y','-i',str(src),'-map','0:a:0','-vn','-map_metadata','-1',
    '-c:a','aac','-profile:a','aac_low','-b:a','32k','-ac','1','-ar','24000',
    '-movflags','+faststart','-threads','1',str(work)])
  encoded=probe(work);stream=encoded['streams'][0];duration=float(encoded['format']['duration'])
  assert stream['codec_name']=='aac' and stream['profile']=='LC' and stream['channels']==1
  assert stream['sample_rate']=='24000' and abs(duration-original_duration)<.3,(src,duration,original_duration)
  # Decode every encoded sample, not just the header.
  run(['ffmpeg','-v','error','-i',str(work),'-map','0:a:0','-f','null','-'])
  data=work.read_bytes();original_data=src.read_bytes()
  work.replace(dest)
  song.update(file=dest.name,bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),
    originalBytes=len(original_data),originalSha256=hashlib.sha256(original_data).hexdigest(),
    encoding={'codec':'AAC-LC','container':'M4A','bitrate':32000,'channels':1,'sampleRate':24000})
  rows.append({'id':song['id'],'originalBytes':len(original_data),'encodedBytes':len(data),
    'originalDuration':original_duration,'encodedDuration':duration,'completeDecode':True,
    'sha256':song['sha256']})
  print(song['id'],len(original_data),'->',len(data),flush=True)
 (music/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
 result={'codec':'AAC-LC mono 24kHz 32kbps','completeTracks':20,
   'originalBytes':sum(r['originalBytes'] for r in rows),
   'encodedBytes':sum(r['encodedBytes'] for r in rows),'tracks':rows}
 (root/'verification/audio_compression_v0123.json').write_text(json.dumps(result,indent=2))
 print(json.dumps({k:v for k,v in result.items() if k!='tracks'}))
if __name__=='__main__':main()
