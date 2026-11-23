import json, sys, unittest, struct
from pathlib import Path
import numpy as np
import trimesh
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools/terrain"))
from build_preview_meshes import load_exr, build_mesh
class TerrainStage1Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.assets=json.loads((ROOT/"data/terrain/sources.json").read_text())["assets"]
    def test_four_islands(self):
        self.assertEqual(len(self.assets),4)
    def test_sources(self):
        for a in self.assets:
            im=load_exr(ROOT/a["source"],a)
            self.assertEqual(im.dtype,np.float32)
    def test_untextured_preview_topology(self):
        for a in self.assets:
            m=trimesh.load(ROOT/a["preview_mesh"],force="mesh")
            nx,nz=a["preview_grid"]
            self.assertEqual(len(m.faces),2*(nx-1)*(nz-1))
            self.assertTrue(np.all(m.face_normals[:,1]>=-1e-4))
            b=(ROOT/a["preview_mesh"]).read_bytes()
            n=struct.unpack_from("<I",b,12)[0]; g=json.loads(b[20:20+n])
            self.assertFalse(g.get("materials"))
            self.assertFalse(g.get("textures"))
            self.assertFalse(g.get("images"))
    def test_external_references_only(self):
        for a in self.assets:
            s=(ROOT/"scenes/terrain"/(a["id"]+".tscn")).read_text()
            self.assertNotIn("[sub_resource",s)
            self.assertIn("ExtResource(\"3_mesh\")",s)
            self.assertIn("ExtResource(\"2_definition\")",s)
    def test_modified_source_rejected(self):
        a=dict(self.assets[0]);a["sha256"]="0"*64
        with self.assertRaises(ValueError):load_exr(ROOT/a["source"],a)
    def test_grid_boundary(self):
        im=np.linspace(0,1,35,dtype=np.float32).reshape(5,7)
        m=build_mesh(im,7,5)
        self.assertAlmostEqual(m.vertices[:,1].min(),0.0,places=6)
        self.assertAlmostEqual(m.vertices[:,1].max(),1.0,places=6)
if __name__=="__main__":unittest.main()
