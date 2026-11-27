"""Bake a fixed original terrain (not the previous demo) to Float32 little-endian."""
import hashlib,json,pathlib,random,math,array,sys
N=2048
SPACING=.25
SEED=271126
out=pathlib.Path(__file__).parent/"world"
out.mkdir(exist_ok=True)
rng=random.Random(SEED)
def noise_grid(step):
    side=math.ceil((N-1)/step)+2
    return step,[[rng.uniform(-1,1) for _ in range(side)] for _ in range(side)]
# Large landforms, drainage, weathering, local variation.
grids=[noise_grid(s) for s in (512,256,96,32,8)]
def weights(i,step):
    a,t=divmod(i,step)
    f=t/step
    return a,f*f*(3-2*f)
axes=[ [weights(i,step) for i in range(N)] for step,_ in grids]
def row_noise(k,z):
    _,g=grids[k]
    j,t=axes[k][z]
    return [a+(b-a)*t for a,b in zip(g[j],g[j+1])]
def value(k,x,row):
    i,t=axes[k][x]
    return row[i]+(row[i+1]-row[i])*t
data=array.array("f")
lo=math.inf;hi=-math.inf
xs=[i/(N-1) for i in range(N)]
for z in range(N):
    v=xs[z]
    rows=[row_noise(k,z) for k in range(len(grids))]
    # Meandering valley, asymmetric ridge systems and broad floodplain.
    center=.51+.105*math.sin(v*math.tau*1.15)+.035*math.sin(v*math.tau*2.7)
    for x,u in enumerate(xs):
        d=abs(u-center)
        valley=1-math.exp(-(d/.115)**2)
        west=math.exp(-((u-.21)/.20)**2-((v-.27)/.30)**2)
        east=math.exp(-((u-.79)/.17)**2-((v-.69)/.32)**2)
        north=math.exp(-((u-.58)/.26)**2-((v-.10)/.17)**2)
        hills=5+valley*(30*west+41*east+21*north+8)
        n0,n1,n2,n3,n4=(value(k,x,rows[k]) for k in range(5))
        h=hills+(2+valley*5)*n0+(1+valley*3)*n1+(0.35+valley*1.1)*n2+.16*n3+.045*n4
        # Walkable valley floor; raised mountains and rocky side gullies.
        gully=math.exp(-((u-(.19+.16*v+.025*math.sin(v*20)))/.021)**2)
        h-=gully*valley*3
        data.append(h);lo=min(lo,h);hi=max(hi,h)
if sys.byteorder!="little":data.byteswap()
raw=data.tobytes()
(out/"height.r32").write_bytes(raw)
(out/"world.json").write_text(json.dumps({"name":"Kuzey Vadisi","version":"1.5-native-world-v1","seed":SEED,"samples":N,"spacing_m":SPACING,"extent_m":(N-1)*SPACING,"regions":64,"height_format":"float32_le_meters","height_min_m":lo,"height_max_m":hi,"sha256":hashlib.sha256(raw).hexdigest(),"features":["meandering valley","asymmetric ridge systems","gullies","rolling foothills","micro undulations"],"objects":0},indent=2))
print("WORLD_BAKED",N,len(raw),lo,hi)
