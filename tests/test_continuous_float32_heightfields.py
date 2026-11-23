"""Check that revised terrain is genuinely continuous float32, not a renamed 8-bit source."""
import os
os.environ.setdefault("OPENCV_IO_ENABLE_OPENEXR", "1")
from pathlib import Path
import json, unittest, hashlib
import cv2, numpy as np
ROOT=Path(__file__).resolve().parents[1]

class TestContinuousTerrain(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.assets=json.loads((ROOT/"data/terrain/sources.json").read_text())["assets"]
    def test_real_exr_float32_and_many_distinct_height_values(self):
        for a in self.assets:
            with self.subTest(id=a["id"]):
                p=ROOT/a["source"]
                b=p.read_bytes()
                self.assertEqual(b[:4],bytes.fromhex("762f3101"))
                self.assertIn(b"Y\x00\x02\x00\x00\x00",b[:256])
                h=cv2.imread(str(p),cv2.IMREAD_UNCHANGED)
                self.assertEqual(h.dtype,np.float32)
                self.assertEqual(h.ndim,2)
                self.assertTrue(np.isfinite(h).all())
                self.assertEqual(np.unique(h).size,a["result_unique_sample_values"])
                self.assertGreater(np.unique(h).size,100000)
                self.assertEqual(hashlib.sha256(b).hexdigest(),a["sha256"])
    def test_original_unchanged_and_v2_not_copy_of_old(self):
        for a in self.assets:
            with self.subTest(id=a["id"]):
                p=ROOT/a["previous_source"]
                self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),a["previous_sha256"])
                old=cv2.imread(str(p),-1)
                new=cv2.imread(str(ROOT/a["source"]),-1)
                self.assertLessEqual(np.unique(old).size,256)
                self.assertEqual(old.shape,new.shape)
                self.assertGreater(float(np.abs(new-old).mean()),.01)
    def test_reduced_preview_grid_roughness(self):
        for a in self.assets:
            with self.subTest(id=a["id"]):
                old=cv2.imread(str(ROOT/a["previous_source"]),-1)
                new=cv2.imread(str(ROOT/a["source"]),-1)
                nx,nz=a["preview_grid"]
                x,z=np.meshgrid(np.linspace(0,old.shape[1]-1,nx).astype("float32"),
                                np.linspace(0,old.shape[0]-1,nz).astype("float32"))
                def q99(h):
                    h=cv2.remap(h,x,z,cv2.INTER_LINEAR)
                    vals=np.concatenate([np.abs(np.diff(h,axis=0)).ravel(),
                                         np.abs(np.diff(h,axis=1)).ravel()])
                    return np.percentile(vals,99)
                self.assertLess(q99(new),q99(old))
if __name__ == "__main__":unittest.main()
