#!/usr/bin/env python3
"""Reads unchanged uploaded JPEG sources; outputs untextured GLB MESHES only.
Does not create, smooth, convert, retouch, or write any heightmap images.
"""
import json
import hashlib
import struct
from pathlib import Path
import cv2
import numpy as np
import trimesh
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def build(root=ROOT):
    registry=json.loads((root/"data/terrain/sources.json").read_text())
    results=[]
    for a in registry["assets"]:
        src=root/a["source"]
        if src.read_bytes()[:3] != bytes.fromhex("ffd8ff") or sha(src)!=a["sha256"]:
            raise ValueError("Original uploaded bytes were altered: "+a["id"])
        with Image.open(src) as im:
            if im.format != "JPEG" or list(im.size) != a["dimensions"]:
                raise ValueError("Image codec/dimensions mismatch: "+a["id"])
            pixels=np.asarray(im.convert("L"),dtype=np.uint8).astype(np.float32)/255.0
        nx,nz=a["preview_grid"]
        height,width=pixels.shape
        px,pz=np.meshgrid(
            np.linspace(0,width-1,nx,dtype=np.float32),
            np.linspace(0,height-1,nz,dtype=np.float32))
        sampled=cv2.remap(pixels,px,pz,cv2.INTER_LINEAR,borderMode=cv2.BORDER_REPLICATE)
        vx,vz=np.meshgrid(
            np.linspace(-.5,.5,nx,dtype=np.float32),
            np.linspace(-.5,.5,nz,dtype=np.float32))
        threshold=float(a["sea_clip_display_threshold"])
        vertices=np.stack([vx,sampled-threshold,vz],axis=-1).reshape(-1,3).astype(np.float32)
        cx,cz=np.meshgrid(np.arange(nx-1,dtype=np.uint32),np.arange(nz-1,dtype=np.uint32))
        i=(cz*nx+cx).ravel();j=i+1;k=i+nx;l=k+1
        faces0=np.stack([np.stack([i,k,j],axis=-1),np.stack([j,k,l],axis=-1)],axis=1).reshape(-1,3)
        land=vertices[:,1]>0
        mask=land[faces0]
        full=mask.all(axis=1)
        partial=mask.any(axis=1)&~full
        faces=faces0[full].astype(np.uint32).tolist()
        verts=vertices.tolist()
        edge_cache={}
        def clip_edge(p,q):
            key=(min(p,q),max(p,q))
            if key in edge_cache:
                return edge_cache[key]
            t=-float(vertices[p,1])/float(vertices[q,1]-vertices[p,1])
            new=vertices[p]+t*(vertices[q]-vertices[p])
            new[1]=0.0
            idx=len(verts)
            verts.append(new.tolist())
            edge_cache[key]=idx
            return idx
        for tri in faces0[partial]:
            tri=[int(v) for v in tri]
            poly=[]
            for index in range(3):
                prev=tri[index-1]
                curr=tri[index]
                if land[prev] != land[curr]:
                    poly.append(clip_edge(prev,curr))
                if land[curr]:
                    poly.append(curr)
            for index in range(1,len(poly)-1):
                faces.append([poly[0],poly[index],poly[index+1]])
        mesh=trimesh.Trimesh(
            vertices=np.asarray(verts,dtype=np.float32),
            faces=np.asarray(faces,dtype=np.int64),
            process=False,validate=False)
        mesh.remove_unreferenced_vertices()
        scene=trimesh.Scene()
        scene.add_geometry(mesh,geom_name=a["id"])
        dest=root/a["preview_mesh"]
        dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_bytes(trimesh.exchange.gltf.export_glb(scene,include_normals=True))
        data=dest.read_bytes()
        length=struct.unpack_from("<I",data,12)[0]
        info=json.loads(data[20:20+length])
        assert not info.get("materials") and not info.get("images") and not info.get("textures")
        results.append({"island":a["id"],"triangles":len(mesh.faces),"sha256":sha(dest)})
    return results

if __name__=="__main__":
    print(json.dumps(build(),indent=2))
