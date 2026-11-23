#!/usr/bin/env python3
"""Convert a lossy 8-bit grayscale/RGB elevation drawing to float32 EXR.

No reconstruction, sharpening, quantization repair, gamma, min/max stretch or resampling.
Requirements: Python, Pillow, NumPy, OpenCV built with OpenEXR support.
"""
import os
os.environ.setdefault("OPENCV_IO_ENABLE_OPENEXR", "1")
import argparse
import hashlib
import json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for b in iter(lambda: f.read(1024 * 1024), b""):
            h.update(b)
    return h.hexdigest()


def convert(src: Path, dst: Path) -> dict:
    src, dst = Path(src), Path(dst)
    if not src.is_file():
        raise FileNotFoundError(src)
    with Image.open(src) as im:
        actual_codec = im.format
        mode = im.mode
        if mode not in ("L", "RGB", "RGBA"):
            raise ValueError("Only 8-bit L/RGB/RGBA source supported; never silently truncate high precision.")
        if mode == "RGBA":
            a = np.asarray(im.getchannel("A"), dtype=np.uint8)
            if not np.all(a == 255):
                raise ValueError("Heightmap has transparency. Explicit compositing/alpha policy required.")
        gray = np.array(im.convert("L"), dtype=np.uint8, copy=True)
    height = gray.astype(np.float32) / np.float32(255.0)
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.suffix.lower() != ".exr":
        raise ValueError("Output filename must end in .exr")
    if not cv2.imwrite(str(dst), height, [
        cv2.IMWRITE_EXR_TYPE, cv2.IMWRITE_EXR_TYPE_FLOAT,
        cv2.IMWRITE_EXR_COMPRESSION, cv2.IMWRITE_EXR_COMPRESSION_PIZ,
    ]):
        raise RuntimeError("EXR writer failed")
    reread = cv2.imread(str(dst), cv2.IMREAD_UNCHANGED)
    if reread is None or reread.shape != height.shape or reread.dtype != np.float32:
        raise RuntimeError("EXR round-trip shape/format invalid")
    if not np.array_equal(reread, height):
        raise RuntimeError("EXR changed sample values")
    result = {
        "width": int(gray.shape[1]), "height": int(gray.shape[0]),
        "source_format": actual_codec, "source_mode": mode,
        "source_sha256": sha256(src), "output_sha256": sha256(dst),
        "output_pixel_type": "float32", "channels": 1,
        "normalization": "byte / 255.0 (no gamma or stretch)",
        "min": float(height.min()), "max": float(height.max()),
        "lossy_source_precision_restored": False,
    }
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output_exr", type=Path)
    parser.add_argument("--manifest", type=Path, default=None)
    args = parser.parse_args()
    result = convert(args.source, args.output_exr)
    if args.manifest is not None:
        args.manifest.parent.mkdir(parents=True, exist_ok=True)
        args.manifest.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
