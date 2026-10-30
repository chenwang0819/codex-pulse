#!/usr/bin/env python3
"""Read-only Codex telemetry. No credentials or message text is read into the API."""
import argparse, json, os, threading, time
from pathlib import Path
from datetime import datetime
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
ROOT = Path(__file__).resolve().parent
HOME = Path(os.environ.get('CODEX_HOME', Path.home()/'.codex'))
cache = {}
lock = threading.Lock()

def scan():
    sessions=[]; latest=None; history=[]
    files=sorted((HOME/'sessions').rglob('*.jsonl'), key=lambda p:p.stat().st_mtime, reverse=True)[:80] if (HOME/'sessions').exists() else []
    for p in files:
        try:
            st=p.stat(); key=str(p)
            if key not in cache or cache[key]['size']!=st.st_size:
                prior=cache.get(key)
                state=prior.copy() if prior and st.st_size>=prior['size'] else {'offset':0,'active':False,'event':None,'model':None,'usage':{},'limits':None,'samples':[]}
                with p.open('rb') as f:
                    f.seek(state['offset'])
                    for line in f:
                        if not line.endswith(b'\n'): break
                        state['offset']+=len(line)
                        try: d=json.loads(line)
                        except (ValueError,UnicodeDecodeError): continue
                        a=d.get('payload',{}); typ=a.get('type'); ts=d.get('timestamp')
                        if d.get('type')=='turn_context': state['model']=a.get('model',state['model'])
                        if d.get('type')!='event_msg': continue
                        if typ=='task_started': state.update(active=True,event=ts)
                        elif typ in ('task_complete','task_completed','turn_aborted'): state.update(active=False,event=ts)
                        if typ=='token_count':
                            state['usage']=a.get('info') or state['usage']
                            if a.get('rate_limits'):
                                state['limits']={'at':ts,'value':a['rate_limits']}
                                state['samples']=(state['samples']+[{'at':ts,'primary':(a['rate_limits'].get('primary') or {}).get('used_percent'),'secondary':(a['rate_limits'].get('secondary') or {}).get('used_percent')}])[-120:]
                state['size']=st.st_size;cache[key]=state
            s=cache[key]; age=time.time()-st.st_mtime
            status='working' if s['active'] and age<180 else 'unknown' if s['active'] else 'idle'
            sessions.append({'id':p.stem[-36:],'updated':st.st_mtime,'status':status,'model':s['model'],'usage':s['usage'],'event':s['event']})
            if s['limits'] and (latest is None or s['limits']['at']>latest['at']):latest=s['limits']
            history.extend(s['samples'])
        except (OSError,ValueError): continue
    working=sum(s['status']=='working' for s in sessions)
    return {'collected_at':time.time(),'source':'Local Codex session logs','limits':latest,'sessions':sessions[:20],'working':working,'unknown':sum(s['status']=='unknown' for s in sessions),'history':sorted(history,key=lambda s:s['at'])[-120:],'scanned':len(files)}

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.headers.get('Host','').split(':')[0] not in ('127.0.0.1','localhost'):
            self.send_error(403);return
        path=self.path.split('?')[0]
        if path=='/api/status':
            with lock: data=json.dumps(scan()).encode()
            kind='application/json'
        elif path in ('/','/index.html'):
            data=(ROOT/'index.html').read_bytes();kind='text/html; charset=utf-8'
        else:self.send_error(404);return
        self.send_response(200);self.send_header('Content-Type',kind);self.send_header('Cache-Control','no-store');self.send_header('X-Content-Type-Options','nosniff');self.send_header('Content-Security-Policy',"default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; connect-src 'self'; img-src 'self' data:");self.end_headers();self.wfile.write(data)
    def log_message(self,*args):pass
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=8765);args=parser.parse_args()
    print(f'CODEX PULSE → http://127.0.0.1:{args.port}',flush=True)
    ThreadingHTTPServer(('127.0.0.1',args.port),Handler).serve_forever()
