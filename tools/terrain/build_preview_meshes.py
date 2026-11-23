#!/usr/bin/env python3
"""Generate external, untextured GLB editor preview meshes from immutable float32 EXR files."""
from pathlib import Path
import os, json, hashlib, argparse
os.environ.setdefault("OPENCV_IO_ENABLE_OPENEXR", "1")
import cv2
import numpy as np
import trimesh
ROOT = Path(__file__).resolve().parents[2]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def load_exr(path, info):
    if digest(path) != info["sha256"]:
        raise ValueError("heightmap SHA mismatch: " + info["id"])
    im = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
    if im is None or im.dtype != np.float32 or im.ndim != 2:
        raise ValueError("expected single-channel float32 EXR")
    if [im.shape[1], im.shape[0]] != info["dimensions"] or not np.isfinite(im).all():
        raise ValueError("invalid dimensions or nonfinite height")
    if im.min() < -1e-5 or im.max() > 1+1e-5:
        raise ValueError("height must be normalized 0..1")
    return im

def build_mesh(im, nx, nz):
    if min(nx,nz) < 3 or max(nx,nz) > 513: raise ValueError("unsafe preview resolution")
    h,w=im.shape
    sx=np.linspace(0,w-1,nx,dtype=np.float32)
    sz=np.linspace(0,h-1,nz,dtype=np.float32)
    xx,zz=np.meshgrid(sx,sz)
    heights=cv2.remap(im,xx,zz,cv2.INTER_LINEAR,borderMode=cv2.BORDER_REPLICATE)
    vx,vz=np.meshgrid(np.linspace(-.5,.5,nx),np.linspace(-.5,.5,nz))
    verts=np.stack([vx,heights,vz],axis=-1).reshape(-1,3).astype(np.float32)
    cx,cz=np.meshgrid(np.arange(nx-1,dtype=np.uint32),np.arange(nz-1,dtype=np.uint32))
    a=(cz*nx+cx).ravel(); b=a+1; c=a+nx; d=c+1
    faces=np.stack([np.stack([a,c,b],axis=-1),np.stack([b,c,d],axis=-1)],axis=1).reshape(-1,3)
    return trimesh.Trimesh(vertices=verts,faces=faces,process=False,validate=False)

def main(root=ROOT):
    reg=json.loads((root/"data/terrain/sources.json").read_text())
    for a in reg["assets"]:
        im=load_exr(root/a["source"],a)
        mesh=build_mesh(im,*a["preview_grid"])
        scene=trimesh.Scene()
        scene.add_geometry(mesh,geom_name=a["id"])
        out=root/a["preview_mesh"]
        out.parent.mkdir(parents=True,exist_ok=True)
        out.write_bytes(trimesh.exchange.gltf.export_glb(scene,include_normals=True))
        scene2=trimesh.load(out,force="scene")
        assert sum(len(g.faces) for g in scene2.geometry.values()) == (a["preview_grid"][0]-1)*(a["preview_grid"][1]-1)*2
        print(a["id"],out,digest(out))
if __name__=="__main__":
    p=argparse.ArgumentParser(); p.add_argument("--root",type=Path,default=ROOT)
    main(p.parse_args().root)
