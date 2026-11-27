#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
if [[ -e addons/terrain_3d ]]; then
  echo 'Refusing to overwrite existing Terrain3D installation' >&2
  exit 1
fi
gh release download v1.1.0-stable --repo TokisanGames/Terrain3D --pattern '*.zip' --dir "$tmp"
python3 - "$tmp" <<'PY'
import pathlib, sys, zipfile, hashlib
archives = []
for path in sorted(pathlib.Path(sys.argv[1]).glob("*.zip")):
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        roots = [n[:-len("terrain.gdextension")] for n in names if n.endswith("addons/terrain_3d/terrain.gdextension")]
        for root in roots:
            files = [n for n in names if n.startswith(root) and not n.endswith("/")]
            if any("linux" in n and ".so" in n for n in files) and any("android" in n and ".so" in n for n in files):
                archives.append((path, root, files))
if len(archives) != 1:
    raise SystemExit(f"Expected exactly one compatible multi-platform release archive; found {len(archives)}")
path, root, files = archives[0]
digest = hashlib.sha256(path.read_bytes()).hexdigest()
if digest != "51b78bc758f5759cbc8eaaab14e5cf4e8661717e265fdd760f5abf945f15b243":
    raise SystemExit("Pinned Terrain3D release SHA256 mismatch")
print("Terrain3D release archive", path.name, "SHA256", digest)
with zipfile.ZipFile(path) as z:
    for name in files:
        rel = pathlib.PurePosixPath(name[len(root):])
        if rel.is_absolute() or ".." in rel.parts:
            raise SystemExit("Unsafe archive entry")
        dest = pathlib.Path("addons/terrain_3d").joinpath(*rel.parts)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(z.read(name))
PY
