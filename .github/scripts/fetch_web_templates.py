# Godot の書き出しテンプレート（1GB超の .tpz）から、必要なファイルだけを
# HTTP Range で抜き出す。使い方: python3 fetch_web_templates.py <tpz URL> <出力先> <ファイル名...>
import io, os, sys, zipfile, urllib.request
url=sys.argv[1]; outdir=sys.argv[2]; want=sys.argv[3:]
os.makedirs(outdir, exist_ok=True)
class R(io.RawIOBase):
    def __init__(s,u):
        s.u=u; s.pos=0
        req=urllib.request.Request(u,method='HEAD'); s.size=int(urllib.request.urlopen(req).headers['Content-Length'])
    def seekable(s): return True
    def readable(s): return True
    def seek(s,o,w=0):
        s.pos = o if w==0 else (s.pos+o if w==1 else s.size+o); return s.pos
    def tell(s): return s.pos
    def readinto(s,b):
        n=len(b)
        if s.pos>=s.size: return 0
        end=min(s.pos+n,s.size)-1
        req=urllib.request.Request(s.u,headers={'Range':f'bytes={s.pos}-{end}'})
        d=urllib.request.urlopen(req).read(); b[:len(d)]=d; s.pos+=len(d); return len(d)
f=io.BufferedReader(R(url),buffer_size=1<<20)
z=zipfile.ZipFile(f)
names=z.namelist()
for n in names:
    if any(n.endswith(w) for w in want):
        out=os.path.join(outdir, n.split('/')[-1])
        with z.open(n) as src, open(out,'wb') as dst:
            while True:
                c=src.read(1<<22)
                if not c: break
                dst.write(c)
        print('saved',out)
