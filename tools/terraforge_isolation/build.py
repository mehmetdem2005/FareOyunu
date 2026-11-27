"""Assemble the camera-only isolation project from the checked-out terrain sources."""
import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--zip", type=Path, required=True)
args = parser.parse_args()
source = Path(__file__).resolve().parent
repo = source.parents[1]
out = args.output.resolve()
shutil.copytree(source / "project", out)
# Include the scripts reached by the two entry points. Unrelated editor and
# profiling scripts have their own resource dependencies outside this project.
pending = ["addons/terra_forge/core/region_fixture_v2.gd", "addons/terra_forge/terrain/paged_terrain_preview.gd"]
seen = set()
while pending:
    relative = pending.pop()
    if relative in seen:
        continue
    seen.add(relative)
    path = repo / relative
    target = out / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, target)
    pending.extend(re.findall(r'"res://(addons/terra_forge/[^"]+\.gd)"', path.read_text()))
def revision(ref):
    return subprocess.check_output(["git", "rev-parse", ref], cwd=repo, text=True).strip()
(out / "build.json").write_text(json.dumps({"commit": revision("HEAD"), "terrain_tree": revision("HEAD:addons/terra_forge")}))
(out / "baked").mkdir()
subprocess.run(["godot", "--headless", "--path", str(out), "--script", str(source / "bake.gd")], check=True, timeout=60)
with ZipFile(args.zip, "x", ZIP_DEFLATED) as package:
    for file in sorted(out.rglob("*")):
        if file.is_file() and ".godot" not in file.relative_to(out).parts:
            package.write(file, "TerraForge_Isolation/" + str(file.relative_to(out)))
