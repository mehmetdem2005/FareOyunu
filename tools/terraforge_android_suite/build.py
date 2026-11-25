#!/usr/bin/env python3
"""Build an isolated Godot project from the current TerraForge snapshot."""
import argparse, json, re, shutil, subprocess, zipfile
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument("--output", required=True)
p.add_argument("--zip", required=True)
a=p.parse_args()
repo=Path(__file__).resolve().parents[2]
out=Path(a.output).resolve()
if out.exists(): raise SystemExit("Use a new output directory")
out.mkdir(parents=True)
shutil.copytree(repo/"addons/terra_forge",out/"addons/terra_forge",ignore=shutil.ignore_patterns(".godot","__pycache__"))
for path in (Path(__file__).parent/"project").iterdir():
    if path.is_file(): shutil.copy2(path,out/path.name)
mobile=out/"mobile_tests"
mobile.mkdir()
suite=(repo/"addons/terra_forge/tests/run_all.sh").read_text()
names=re.findall(r"^\s+(test_\w+)\s*$",suite.split("suite=(\n",1)[1].split("\n)",1)[0],re.M)
if len(names)!=len(set(names)) or len(names)<90: raise SystemExit("Unexpected regression inventory")
for name in names:
    s=(repo/"addons/terra_forge/tests"/(name+".gd")).read_text()
    s,n=re.subn(r'(?m)^extends SceneTree\s*$', 'extends "res://test_adapter.gd"',s,count=1)
    if not n:
        s,n=re.subn(r'(?m)^extends "res://addons/terra_forge/tests/(test_\w+\.gd)"',r'extends "res://mobile_tests/\1"',s,count=1)
    if n!=1: raise SystemExit("Unsupported test inheritance: "+name)
    # Do not alter test assertions, delays, inputs or expected results.
    # Only SceneTree entry and exit are adapted to the shared Android tree.
    s=re.sub(r'\bget_tree\(\)\.quit\(', 'quit(',s)
    (mobile/(name+".gd")).write_text(s)
sha=subprocess.check_output(["git","rev-parse","HEAD"],cwd=repo,text=True).strip()
(out/"suite.json").write_text(json.dumps({"build_commit":sha,"terrain_commit":"a30ca86df848e2360d0b1dcc328bbd9a660ce8db","tests":names},indent=2)+"\n")
z=Path(a.zip)
z.parent.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(z,"w",zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for f in sorted(out.rglob("*")):
        if f.is_file(): archive.write(f, "TerraForge_Android_Test/"+str(f.relative_to(out)))
print(f"Packed {len(names)} adapted regression tests, original sources and automatic renderer profiler: {z}")
