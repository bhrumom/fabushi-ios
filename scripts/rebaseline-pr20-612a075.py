#!/usr/bin/env python3
import json,re
from pathlib import Path
OLD="1d9d9b72d2b6cf2a28d641159d68ffcb3c85dbef"; NEW="612a075e7a7de5d845f765ade4eb51c7c318e3c8"
MAIN="source/host/app/src/main.rs"; SHA="eaf198bd91f46b79b042fe6a58728766715ffe2a"; SIZE=522004
def dump(p,v): Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+"\n")
mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text()); li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==OLD and mi["fileCount"]==7927; assert li["source"]["commit"]==OLD and li["rowCount"]==7927
for g in mi["groups"]:
 p=Path(g["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD; v["sourceCommit"]=NEW
 if g["name"]=="source-host":
  row=next(x for x in v["files"] if x["path"]==MAIN); row["blobSha"]=SHA; row["size"]=SIZE
 dump(p,v)
for c in li["chunks"]:
 p=Path(c["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD; v["sourceCommit"]=NEW
 if c["name"]=="source-host":
  row=next(x for x in v["rows"] if x["desktop_path"]==MAIN)
  row["desktop_blob_sha"]=SHA
  row["implementation_status"]="mapped"
  row["production_evidence"]=""
  row["test_evidence"]=""
  row["notes"]=f"Revalidated against Desktop PR #20 {NEW}. This upstream commit only fixes worker-closure capture to call the already canonical worker_host_runner_composition for compose_production_turn/compose_production_runner; ownership semantics are unchanged. iOS has a shipping NativeRunnerComposition implementation at its current branch but remains mapped until same-head CI."
 dump(p,v)
mi["authority"]["commit"]=NEW; dump("manifests/desktop-pr20-reference-index.json",mi); li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)
p=Path("scripts/check-desktop-pr20-ios-architecture.py"); t=p.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in t; p.write_text(t.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))
p=Path("MIGRATION_SOURCE.md"); t=p.read_text(); t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1; p.write_text(t)
p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); t=p.read_text(); old=f"- pinned source commit for this baseline: `{OLD}`"; assert old in t; t=t.replace(old,f"- pinned source commit for this baseline: `{NEW}`",1); assert "### 1.23 Exact-HEAD rebaseline" not in t
section="""### 1.23 Exact-HEAD rebaseline: 2026-10-03 / `612a075e7a7de5d845f765ade4eb51c7c318e3c8`

Desktop PR #20 advanced one commit from `1d9d9b72d2b6cf2a28d641159d68ffcb3c85dbef` to `612a075e7a7de5d845f765ade4eb51c7c318e3c8`. The selected inventory remains **7,927** and `source-host` remains 957; only `source/host/app/src/main.rs` changed. The production delta is a worker-closure capture correction: the asynchronous turn worker now calls the cloned `worker_host_runner_composition` for `compose_production_turn` and `compose_production_runner` rather than referencing the outer binding. No Host/Runner ownership, lifecycle state machine, or product effect changed.

The iOS native Runner composition closure defined in Section 1.22 therefore remains the correct adaptation. This rebaseline only refreshes Desktop authority/blob identity; it does not promote the affected row. Same-iOS-HEAD production/test evidence remains required.

"""
p.write_text(t.replace("## 2. Product goal",section+"## 2. Product goal",1))
for g in mi["groups"]: assert json.loads(Path(g["path"]).read_text())["sourceCommit"]==NEW
for c in li["chunks"]: assert json.loads(Path(c["path"]).read_text())["sourceCommit"]==NEW
print("rebaseline-612a075-static-integrity: ok")
