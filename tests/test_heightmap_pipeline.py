import os
os.environ.setdefault("OPENCV_IO_ENABLE_OPENEXR", "1")
import sys
import tempfile
import unittest
from pathlib import Path
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "heightmap"))
from convert_heightmap import convert


class HeightmapTests(unittest.TestCase):
    def test_exact_pixel_mapping_and_max(self):
        with tempfile.TemporaryDirectory() as td:
            src, dst = Path(td) / "source.png", Path(td) / "test.exr"
            samples = np.array([[0, 1, 127, 128, 254, 255]], dtype=np.uint8)
            Image.fromarray(samples, "L").save(src)
            record = convert(src, dst)
            import cv2
            out = cv2.imread(str(dst), cv2.IMREAD_UNCHANGED)
            np.testing.assert_array_equal(out, samples.astype(np.float32) / np.float32(255.0))
            self.assertEqual(record["source_format"], "PNG")
            self.assertEqual(record["output_pixel_type"], "float32")

    def test_real_codec_not_filename(self):
        with tempfile.TemporaryDirectory() as td:
            src, dst = Path(td) / "looks_like_png.png", Path(td) / "test.exr"
            Image.new("RGB", (7, 5), (20, 20, 20)).save(src, format="JPEG")
            record = convert(src, dst)
            self.assertEqual(record["source_format"], "JPEG")
            self.assertEqual(record["width"], 7)

    def test_rejects_transparent_source(self):
        with tempfile.TemporaryDirectory() as td:
            src, dst = Path(td) / "alpha.png", Path(td) / "test.exr"
            Image.new("RGBA", (4, 4), (3, 4, 5, 0)).save(src)
            with self.assertRaises(ValueError):
                convert(src, dst)

    def test_rejects_accidental_high_precision_truncation(self):
        with tempfile.TemporaryDirectory() as td:
            src, dst = Path(td) / "hi.tiff", Path(td) / "test.exr"
            Image.fromarray(np.array([[5000, 40000]], dtype=np.uint16)).save(src)
            with self.assertRaises(ValueError):
                convert(src, dst)

    def test_rejects_wrong_extension(self):
        with tempfile.TemporaryDirectory() as td:
            src, dst = Path(td) / "low.png", Path(td) / "test.png"
            Image.new("L", (2, 2), 50).save(src)
            with self.assertRaises(ValueError):
                convert(src, dst)


if __name__ == "__main__":
    unittest.main()
