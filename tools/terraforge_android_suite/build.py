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
# Walk only declared test inheritance, including shared non-test_ bases.
# Reject cycles or unknown paths rather than leaving SceneTree scripts in Node runner.
done=set()
active=set()
def adapt(relative):
    if relative in done: return
    if relative in active: raise SystemExit("Cyclic test inheritance: "+relative)
    if not re.fullmatch(r"[A-Za-z0-9_]+(?:/[A-Za-z0-9_]+)*\.gd", relative):
        raise SystemExit("Unsupported test path: "+relative)
    active.add(relative)
    s=(repo/"addons/terra_forge/tests"/relative).read_text()
    s,n=re.subn(r'(?m)^extends SceneTree[ \t]*$', 'extends "res://test_adapter.gd"',s,count=1)
    if not n:
        match=re.search(r'(?m)^extends "res://addons/terra_forge/tests/([A-Za-z0-9_/]+\.gd)"[ \t]*$',s)
        if not match: raise SystemExit("Unsupported test inheritance: "+relative)
        parent=match.group(1)
        adapt(parent)
        s=s[:match.start()]+'extends "res://mobile_tests/'+parent+'"'+s[match.end():]
    s=re.sub(r'\bget_tree\(\)\.quit\(', 'quit(',s)
    target=mobile/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(s)
    active.remove(relative)
    done.add(relative)
for name in names:
    adapt(name+".gd")
print(f"Adapted {len(done)} scripts for {len(names)} runnable tests")
sha=subprocess.check_output(["git","rev-parse","HEAD"],cwd=repo,text=True).strip()
terrain_commit="d7aa19b503497ae34298957e8d141409829fd828"
def terrain_tree(ref):
    return subprocess.check_output(["git","rev-parse",ref+":addons/terra_forge"],cwd=repo,text=True).strip()
if terrain_tree("HEAD")!=terrain_tree(terrain_commit):
    raise SystemExit("Terrain differs from pinned integrated snapshot")
quick=["test_i0_integrated_route","test_i0_integrated_route_v2","test_h3_capacity_matrix","test_h3_capacity_matrix_v2"]
if not set(quick).issubset(names): raise SystemExit("Missing targeted tests")
(out/"suite.json").write_text(json.dumps({"build_commit":sha,"terrain_commit":terrain_commit,"terrain_tree":terrain_tree("HEAD"),"tests":names,"quick_tests":quick},indent=2)+"\n")
z=Path(a.zip)
z.parent.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(z,"w",zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for f in sorted(out.rglob("*")):
        if f.is_file(): archive.write(f, "TerraForge_Android_Test/"+str(f.relative_to(out)))
print(f"Packed {len(names)} adapted regression tests, original sources and automatic renderer profiler: {z}")
