"""Offline Float32 1 km terrain. Independent world-space landforms, not resized prior map."""
import hashlib,json,pathlib,numpy as np
from scipy.ndimage import map_coordinates, gaussian_filter
from PIL import Image
N=4096; SP=.25; SEED=271127
out=pathlib.Path(__file__).parent/"world";out.mkdir(exist_ok=True)
rng=np.random.default_rng(SEED)
# Smooth gradient-like lattice noise in metres, at separate spatial scales.
scales=[256,112,48,20,8,2,.75]
grids=[rng.uniform(-1,1,(int(1024/s)+5,int(1024/s)+5)).astype(np.float32) for s in scales]
def noise(x,z,k):
    s=scales[k]; return map_coordinates(grids[k],[z/s+1,x/s+1],order=3,mode="nearest",prefilter=True).astype(np.float32)
def gauss(x,z,cx,cz,wx,wz):return np.exp(-((x-cx)/wx)**2-((z-cz)/wz)**2)
h=np.empty((N,N),dtype="<f4")
# Main valley runs north to south with connected tributaries, low basin floor,
# mountain massifs to the NW/SE, a plateau to the NE, lake and coastal lowlands.
for start in range(0,N,128):
    end=min(N,start+128)
    z,x=np.meshgrid(np.arange(start,end,dtype=np.float32)*SP,np.arange(N,dtype=np.float32)*SP,indexing="ij")
    n0,n1,n2,n3,n4,n5,n6=[noise(x,z,k) for k in range(7)]
    west=gauss(x,z,200,215,220,270)
    southeast=gauss(x,z,805,745,210,270)
    plateau=gauss(x,z,804,200,250,180)
    foothills=gauss(x,z,240,770,180,260)
    river=480+95*np.sin(z/180)+28*np.sin(z/61)
    d=np.abs(x-river)
    valley=1-np.exp(-(d/95)**2)
    ridge=(1-np.abs(n1))**2
    macro=7+valley*(92*west+115*southeast+38*plateau+29*foothills)
    macro+=valley*(8*n0+12*ridge*(west+southeast)+6*n1)
    terrace=34+2.6*n1+1.4*n2
    macro=macro*(1-plateau*.42)+terrace*plateau*.42
    # Broad floodplain plus deeply cut channel; two confluences on the flanks.
    floor=1.7+z*.004+0.55*n2
    river_blend=np.exp(-(d/44)**2)
    base=macro*(1-river_blend)+floor*river_blend
    base-=2.0*np.exp(-(d/7.5)**2)
    tributary1=river-(z-350)*.73-6*np.sin(z/15)
    t1=np.exp(-((x-tributary1)/12)**2)*np.exp(-((z-465)/140)**4)
    tributary2=river+(z-695)*.85+8*np.sin(z/19)
    t2=np.exp(-((x-tributary2)/10)**2)*np.exp(-((z-770)/145)**4)
    base-=np.minimum(11,base*.5)*(t1+t2)
    lake=gauss(x,z,265,740,83,65)
    lake_blend=np.clip((lake-.20)/.58,0,1)
    base=base*(1-lake_blend)+(-2.0+0.5*n2)*lake_blend
    # Small erosion-like gullies and ridge detail, floor microtopography is gentle.
    erosion=np.abs(n3)*np.abs(n2)
    base-=valley*erosion*(2.2+5.0*(west+southeast))
    detail=(.35+valley*2.7)*n3+(.16+valley*.65)*n4+.055*n5+.022*n6
    # South shore with real low coastal strip, not a water mesh.
    coast=np.clip((z-910-14*n0)/98,0,1)
    base=base*(1-coast)+(-4+1.4*n1)*coast
    h[start:end]=base+detail
assert np.isfinite(h).all()
raw=h.tobytes();(out/"height.r32").write_bytes(raw)
# Original seamless photographic-style procedural color maps, not external PBR scans.
# Periodic wrap interpolation ensures tiles repeat without a seam.
def tile_noise(size,cell):
    g=rng.random((cell,cell),dtype=np.float32)
    u=np.arange(size,dtype=np.float32)*cell/size
    yy,xx=np.meshgrid(u,u,indexing="ij")
    return map_coordinates(g,[yy,xx],order=1,mode="grid-wrap")-.5
def texture(name,base,amp):
    size=512
    a=tile_noise(size,6);b=tile_noise(size,22);c=tile_noise(size,83)
    grain=rng.random((size,size),dtype=np.float32)-.5
    pattern=a*.48+b*.55+c*.36+grain*.22
    if name=="rock":pattern+=.13*np.sin(2*np.pi*(np.arange(size)[None,:]/size*7+np.arange(size)[:,None]/size*3)+b*4)
    color=np.asarray(base,dtype=np.float32)[None,None,:]+pattern[:,:,None]*np.array(amp)[None,None,:]
    Image.fromarray(np.clip(color,0,255).astype(np.uint8),"RGB").save(out/(name+".png"))
for args in [("soil",(104,79,54),(95,79,56)),("rock",(112,111,104),(114,108,98)),("sand",(157,136,98),(75,68,49)),("grass",(79,101,54),(88,100,66))]:texture(*args)
# Spawn at broad central valley; heightmap overview for world design, outside game package.
spawn_z=480.;spawn_x=float(480+95*np.sin(spawn_z/180)+28*np.sin(spawn_z/61)+21)
info={"name":"Dört Havza","version":"1.5-native-world-v2","seed":SEED,"samples":N,"spacing_m":SP,"extent_m":(N-1)*SP,"regions":64,"region_samples":512,"mesh_lods":7,"height_format":"float32_le_meters","height_min_m":float(h.min()),"height_max_m":float(h.max()),"sha256":hashlib.sha256(raw).hexdigest(),"spawn_m":[spawn_x,spawn_z],"features":["two mountain massifs","plateau","foothills","connected river valleys","lake basin","coastal plain","gullies","microrelief"],"textures":["soil","rock","sand","grass"],"objects":0}
(out/"world.json").write_text(json.dumps(info,indent=2))
print("WORLD_BAKED",json.dumps(info),len(raw))
