#!/usr/bin/env python3
import json,re
from pathlib import Path
OLD="612a075e7a7de5d845f765ade4eb51c7c318e3c8"; NEW="9f22a1974f02683f4ad27a2fe856987b7dd1d20f"
P="source/host/tests/host_runner_composition_production_wiring_contract.rs"
SHA="20e552bc4404ade4c96e5d1e9315fa55bf99dbe8"
SIZE=7341

def dump(p,v): Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+"\n")

mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==OLD and mi["fileCount"]==7927
assert li["source"]["commit"]==OLD and li["rowCount"]==7927

for g in mi["groups"]:
    p=Path(g["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD
    v["sourceCommit"]=NEW
    if g["name"]=="source-host":
        row=next(x for x in v["files"] if x["path"]==P)
        row["blobSha"]=SHA; row["size"]=SIZE
        assert len(v["files"])==957
    dump(p,v)

for c in li["chunks"]:
    p=Path(c["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD
    v["sourceCommit"]=NEW
    if c["name"]=="source-host":
        row=next(x for x in v["rows"] if x["desktop_path"]==P)
        row["desktop_blob_sha"]=SHA
        assert row["implementation_status"]=="implemented"
        row["notes"]=(row.get("notes") or "") + f" Revalidated at Desktop PR #20 {NEW}: contract-only delta requires the shipping worker to consume the same HostRunnerComposition via Arc::clone; production ownership/state semantics are unchanged, so the reviewed iOS NativeRunnerComposition implementation remains implemented but not verified."
        assert len(v["rows"])==957
    dump(p,v)

mi["authority"]["commit"]=NEW; dump("manifests/desktop-pr20-reference-index.json",mi)
li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)

p=Path("scripts/check-desktop-pr20-ios-architecture.py")
t=p.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in t
p.write_text(t.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))

p=Path("MIGRATION_SOURCE.md")
t=p.read_text(); t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1
p.write_text(t)

p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md")
t=p.read_text(); old=f"- pinned source commit for this baseline: `{OLD}`"; assert old in t
t=t.replace(old,f"- pinned source commit for this baseline: `{NEW}`",1)
assert "### 1.24 Exact-HEAD rebaseline" not in t
section="""### 1.24 Exact-HEAD rebaseline: 2026-10-03 / `9f22a1974f02683f4ad27a2fe856987b7dd1d20f`

Desktop PR #20 advanced one contract-only commit from `612a075e7a7de5d845f765ade4eb51c7c318e3c8` to `9f22a1974f02683f4ad27a2fe856987b7dd1d20f`. The selected inventory remains exactly **7,927** blobs and `source-host` remains 957 rows. The only selected blob change is `source/host/tests/host_runner_composition_production_wiring_contract.rs`.

The strengthened contract now explicitly requires the asynchronous shipping turn worker to consume the same `HostRunnerComposition` owner through `Arc::clone(&host_runner_composition)`, then invoke `worker_host_runner_composition.compose_production_turn(...)`. No shipping source, owner, state machine, or product effect changed. The iOS `MahayanaHost::build_runtime -> NativeRunnerComposition` implementation remains the reviewed platform adaptation because it likewise constructs one shared native Runner graph and passes the same `NativeEngine` ownership into Runtime and NativeAgent. The affected contract row remains `implemented`, never `verified`, until the same iOS exact HEAD completes required CI.

"""
p.write_text(t.replace("## 2. Product goal",section+"## 2. Product goal",1))

mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==NEW and mi["fileCount"]==7927
assert li["source"]["commit"]==NEW and li["rowCount"]==7927
for g in mi["groups"]: assert json.loads(Path(g["path"]).read_text())["sourceCommit"]==NEW
for c in li["chunks"]: assert json.loads(Path(c["path"]).read_text())["sourceCommit"]==NEW
print("rebaseline-9f22a19-static-integrity: ok")
