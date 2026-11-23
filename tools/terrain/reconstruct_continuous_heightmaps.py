#!/usr/bin/env python3
"""Non-destructive deterministic reconstruction of continuous FLOAT32 terrain.
Artist 8-bit-derived data cannot regain lost measured elevations. New relief
is synthesized mathematically. Existing input EXRs are never overwritten.
"""
from __future__ import annotations
import os
os.environ.setdefault("OPENCV_IO_ENABLE_OPENEXR", "1")
from pathlib import Path
import argparse
import json
import hashlib
import cv2
import numpy as np
from scipy.ndimage import gaussian_filter, distance_transform_edt

PRESETS = {}

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def fractal_noise(shape, rng):
    h, w = shape
    sum_n = np.zeros(shape, dtype=np.float32)
    for roughness, amplitude in [(80, .36), (38, .34), (16, .20), (6, .10)]:
        sy = max(3, round(h / (roughness * 2)))
        sx = max(3, round(w / (roughness * 2)))
        src = rng.standard_normal((sy, sx)).astype(np.float32)
        field = cv2.resize(src, (w, h), interpolation=cv2.INTER_CUBIC)
        field = gaussian_filter(field, 2.0).astype(np.float32)
        field = (field - float(field.mean())) / (float(field.std()) + 1e-6)
        sum_n += np.float32(amplitude) * field
    return np.clip(sum_n, -2.0, 2.0)

def connected_ocean(a):
    seed = (a < .10).astype(np.uint8)
    seed = cv2.morphologyEx(seed, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    n, labels, stats, _ = cv2.connectedComponentsWithStats(seed, connectivity=8)
    border_ids = np.unique(np.concatenate(
        (labels[0], labels[-1], labels[:, 0], labels[:, -1])))
    ocean = np.isin(labels, border_ids[border_ids != 0])
    return ocean

def smooth_elevation(source, kind):
    params = PRESETS[kind]
    sea = connected_ocean(source)
    shore_distance = distance_transform_edt(~sea).astype(np.float32)
    H, W = source.shape
    Y, X = np.mgrid[:H, :W].astype(np.float32)
    sigma = params['smooth']
    sm3 = gaussian_filter(source, 3.2).astype(np.float32)
    sm1 = gaussian_filter(source, sigma).astype(np.float32)
    sm2 = gaussian_filter(source, sigma * 2.6).astype(np.float32)
    g = .13 * sm3 + .64 * sm1 + .23 * sm2
    reference = float(np.percentile(g[~sea], 99.6))
    cap = params['cap']
    g = np.minimum(g / max(reference, 1e-3), 1.3)
    g = cap * (1.0 - np.exp(-2.05 * g)) / (1.0 - np.exp(-2.05))
    coast_field = (np.sin(X/108.0 + np.cos(Y/202.0))
                  + .66 * np.cos(Y/144.0 - X/218.0)) / 1.66
    cliff_blend = gaussian_filter(np.clip((coast_field-.47)/.25, 0, 1), 12.0)
    shore_width = params['coast'] * (1.0 - .68 * cliff_blend)
    ramp = np.clip(shore_distance / shore_width, 0, 1)
    ramp = ramp*ramp*(3.0-2.0*ramp)
    coast_atten = .12+.88*ramp
    g *= coast_atten
    rng = np.random.default_rng(params['seed'])
    noise = fractal_noise(source.shape, rng)
    strength = (.0048 if kind in ('island_nw_01', 'island_sw_01') else .0090)
    in_land = np.clip((shore_distance/32), 0, 1)
    g += np.float32(strength)*noise*in_land*np.minimum(g/.12, 1)
    g[sea] = 0
    g = np.maximum(g, 0)
    g = gaussian_filter(g, 1.5).astype(np.float32)
    g[g < 0.00015] = 0
    assert np.isfinite(g).all() and g.min() >= 0 and g.max() < 1.0
    return g, sea

def main(root: Path) -> None:
    global PRESETS
    root = root.resolve()
    PRESETS = json.loads((root / "data/terrain/continuous_v2_presets.json").read_text(encoding="utf-8"))["presets"]
    manifest = json.loads((root / "data/terrain/sources.json").read_text(encoding="utf-8"))
    for asset in manifest["assets"]:
        asset_id = asset["id"]
        previous = root / asset["previous_source"]
        output = root / asset["source"]
        if not previous.is_file() or sha(previous) != asset["previous_sha256"]:
            raise ValueError("Missing/corrupt prior EXR: " + asset_id)
        original = cv2.imread(str(previous), cv2.IMREAD_UNCHANGED)
        if original is None or original.ndim != 2 or original.dtype != np.float32:
            raise ValueError("Source must be single-channel float32 EXR: " + asset_id)
        continuous, _ = smooth_elevation(original, asset_id)
        if output.exists():
            saved = cv2.imread(str(output), cv2.IMREAD_UNCHANGED)
            if saved is None or not np.array_equal(saved, continuous):
                raise ValueError("Output differs from deterministic reconstruction: " + asset_id)
        else:
            output.parent.mkdir(parents=True, exist_ok=True)
            if not cv2.imwrite(str(output), continuous,
                [cv2.IMWRITE_EXR_TYPE, cv2.IMWRITE_EXR_TYPE_FLOAT,
                 cv2.IMWRITE_EXR_COMPRESSION, cv2.IMWRITE_EXR_COMPRESSION_PIZ]):
                raise IOError("OpenEXR save failed")
        if sha(output) != asset["sha256"]:
            raise ValueError("Output SHA mismatch (library/codec drift?): " + asset_id)
        print(f"{asset_id}: OK {output} {np.unique(continuous).size} distinct float32 samples")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    main(parser.parse_args().root)
