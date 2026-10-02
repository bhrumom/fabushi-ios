#!/usr/bin/env python3
import json
import re
from pathlib import Path

OLD="9467112079551dc9ff64d40ba2c0bed0f62a114a"
NEW="f6d4c48d113d02ec2e223c4fcbad1e6417549424"

def dump(path,value):
    Path(path).write_text(json.dumps(value,ensure_ascii=False,indent=2)+"\n")

mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==OLD and mi["fileCount"]==7926
assert li["source"]["commit"]==OLD and li["rowCount"]==7926
for g in mi["groups"]:
    p=Path(g["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD
    v["sourceCommit"]=NEW; dump(p,v)
for c in li["chunks"]:
    p=Path(c["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD
    v["sourceCommit"]=NEW; dump(p,v)
mi["authority"]["commit"]=NEW; dump("manifests/desktop-pr20-reference-index.json",mi)
li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)

p=Path("scripts/check-desktop-pr20-ios-architecture.py"); t=p.read_text()
old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in t
p.write_text(t.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))

p=Path("MIGRATION_SOURCE.md"); t=p.read_text()
t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1
p.write_text(t)

p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); t=p.read_text()
old=f"- pinned source commit for this baseline: `{OLD}`".replace("\\",""); assert old in t
t=t.replace(old,f"- pinned source commit for this baseline: `{NEW}`".replace("\\",""),1)
assert "### 1.17 Exact-HEAD rebaseline" not in t
section="""### 1.17 Exact-HEAD rebaseline: 2026-10-03 / f6d4c48d113d02ec2e223c4fcbad1e6417549424

Desktop PR #20 advanced one evidence-only commit from `9467112079551dc9ff64d40ba2c0bed0f62a114a` to `f6d4c48d113d02ec2e223c4fcbad1e6417549424`. The commit changes only `projects/grok-fabu-parity/architecture-manifest.json`; no selected `frontend/** + source/**` path or blob changed, so the authoritative selected inventory remains exactly 7,926 paths and no source responsibility/status is promoted or demoted solely by this move. Nevertheless every manifest/ledger `sourceCommit`, both authority indexes, `MIGRATION_SOURCE.md`, and the strict checker are rebound to the new exact HEAD before further current-head parity claims.

The preceding production-source audit remains semantically current because all selected source blobs are identical. The iOS Rust CI-session transport fix is retained as production code, but acceptance results tied to its pre-rebaseline iOS SHA are not used as proof for the post-rebaseline exact HEAD; that exact HEAD must earn its own architecture, Rust, Swift/UI, archive and protected complete-state evidence.

"""
assert "## 2. Product goal" in t
p.write_text(t.replace("## 2. Product goal",section+"## 2. Product goal",1))

# static authority integrity
mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==NEW and mi["fileCount"]==7926
assert li["source"]["commit"]==NEW and li["rowCount"]==7926
mc=lc=0
for g in mi["groups"]:
    v=json.loads(Path(g["path"]).read_text()); assert v["sourceCommit"]==NEW
    mc += len(v["files"])
for c in li["chunks"]:
    v=json.loads(Path(c["path"]).read_text()); assert v["sourceCommit"]==NEW
    lc += len(v["rows"])
assert mc==7926 and lc==7926
print("rebaseline-f6d4c48-static-integrity: ok")
