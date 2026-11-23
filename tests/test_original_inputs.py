"""Direct-source stage: binary originals exist only in separately delivered ZIP until uploaded."""
import hashlib, json, struct, unittest
from pathlib import Path
from PIL import Image
import trimesh
ROOT=Path(__file__).resolve().parents[1]
class TestDirectSources(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.assets=json.loads((ROOT/"data/terrain/sources.json").read_text())["assets"]
    def test_manifest_and_four_independent_scenes(self):
        self.assertEqual(len(self.assets),4)
        scene=(ROOT/"scenes/world/world_preview.tscn").read_text()
        self.assertEqual(scene.count('instance=ExtResource('),4)
        self.assertNotIn("[sub_resource",scene)
    def test_byte_identical_jpeg_and_untextured_meshes(self):
        for a in self.assets:
            with self.subTest(island=a["id"]):
                path=ROOT/a["source"]; b=path.read_bytes()
                self.assertEqual(b[:3],bytes.fromhex("ffd8ff"))
                self.assertEqual(hashlib.sha256(b).hexdigest(),a["sha256"])
                with Image.open(path) as im:
                    self.assertEqual(im.format,"JPEG")
                    self.assertEqual(list(im.size),a["dimensions"])
                out=ROOT/a["preview_mesh"]; glb=out.read_bytes()
                self.assertEqual(glb[:4],b"glTF")
                n=struct.unpack_from("<I",glb,12)[0]
                gltf=json.loads(glb[20:20+n])
                self.assertFalse(gltf.get("materials"))
                self.assertFalse(gltf.get("textures"))
                self.assertFalse(gltf.get("images"))
                mesh=trimesh.load(out,force="mesh")
                self.assertGreater(len(mesh.faces),10000)
                self.assertGreaterEqual(float(mesh.face_normals[:,1].min()),-1e-4)
    def test_no_generated_heightmap(self):
        self.assertEqual(len(list((ROOT/"assets/terrain/heightmaps").glob("*.jpg"))),4)
        self.assertEqual(len(list(ROOT.rglob("*.exr"))),0)
if __name__=="__main__":unittest.main()
