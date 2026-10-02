#!/usr/bin/env python3
import json
from pathlib import Path
OLD="61f8518a5e0b4bead224ec3c081da64523316908"
NEW="ed06d2c96471d5e80b66cd3c4b09116e968a0e56"
P="source/host/tests/turn_telemetry_production_wiring_contract.rs"
SHA="91ae76ed3f0fc6d8992ca9b03ba039ca80bf62f2"
SIZE=6082
def dump(p,o): Path(p).write_text(json.dumps(o,ensure_ascii=False,indent=2)+"\n")
mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
assert mi["authority"]["commit"]==OLD and mi["fileCount"]==7926
for g in mi["groups"]:
    o=json.loads(Path(g["path"]).read_text()); assert o["sourceCommit"]==OLD; o["sourceCommit"]=NEW
    if g["name"]=="source-host":
        r=next(x for x in o["files"] if x["path"]==P); r["blobSha"]=SHA; r["size"]=SIZE
    dump(g["path"],o)
mi["authority"]["commit"]=NEW; mi["authority"]["generatedAt"]="2026-10-03"; dump("manifests/desktop-pr20-reference-index.json",mi)
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text()); assert li["source"]["commit"]==OLD
for ch in li["chunks"]:
    o=json.loads(Path(ch["path"]).read_text()); assert o["sourceCommit"]==OLD; o["sourceCommit"]=NEW
    if ch["name"]=="source-host":
        r=next(x for x in o["rows"] if x["desktop_path"]==P)
        r["desktop_blob_sha"]=SHA; r["implementation_status"]="mapped"
        r["desktop_responsibility"]="Focused production-wiring evidence that closing-send telemetry and terminal projection use the same canonical SendMessage-or-reaction delivery-debt predicate through existing shipping Host owners."
        r["desktop_visible_effect"]="Reaction delivery and SendMessage delivery cannot disagree between terminal state and closing-send telemetry, and no parallel telemetry/TurnRuntime owner may synthesize delivery."
        r["test_evidence"]="Desktop ed06d2c changes this exact production-wiring contract. iOS must prove the platform-adapted NativeEngine/Host closing-send and empty-delivery behavior from one canonical delivery state on an exact iOS HEAD."
        r["notes"] += " Rebased to ed06d2c. Desktop also marks the broader TurnRuntime responsibility implemented in its architecture manifest by explicitly composing existing Host/Runner owners; this row stays mapped until the iOS canonical runtime proves the equivalent behavior."
    dump(ch["path"],o)
li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)
cp=Path("scripts/check-desktop-pr20-ios-architecture.py"); s=cp.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in s; cp.write_text(s.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))
sp=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); s=sp.read_text(); bt=chr(96); old=f"- pinned source commit for this baseline: {bt}{OLD}{bt}"; assert old in s; s=s.replace(old,f"- pinned source commit for this baseline: {bt}{NEW}{bt}",1); assert "### 1.10 Exact-HEAD rebaseline" not in s
sec="""### 1.10 Exact-HEAD rebaseline: 2026-10-03 / ed06d2c96471d5e80b66cd3c4b09116e968a0e56

Desktop PR #20 advanced one evidence-only commit from 61f8518a5e0b4bead224ec3c081da64523316908. The selected frontend/** + source/** inventory remains exactly 7,926 blobs; the only selected source change is source/host/tests/turn_telemetry_production_wiring_contract.rs. The other change is Desktop's architecture manifest, which now marks the broader TurnRuntime responsibility implemented and explicitly documents that it is absorbed by existing canonical Host/Runner owners instead of a parallel TurnRuntime owner.

The focused contract tightens one semantic point for iOS: closing-send delivery and terminal delivery share the same canonical delivery predicate, including successful reaction delivery as satisfying delivery debt. The current iOS NativeEngine already owns real send_message delivery and bounded reply nudges, but has not yet implemented the 61f closing-send/ordinary-empty-delivery slice or proved one shared delivery predicate. This changed evidence row therefore remains mapped. Unchanged automation rows keep their implemented status, and the next production change must extend the existing NativeEngine/Host composition rather than add renderer or duplicate runtime ownership.

"""
assert "## 2. Product goal" in s; sp.write_text(s.replace("## 2. Product goal",sec+"## 2. Product goal",1))
# full integrity
mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text()); li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text()); mr={}; lr={}
for g in mi["groups"]:
    o=json.loads(Path(g["path"]).read_text()); assert o["sourceCommit"]==NEW; mr.update({x["path"]:x for x in o["files"]})
for ch in li["chunks"]:
    o=json.loads(Path(ch["path"]).read_text()); assert o["sourceCommit"]==NEW; lr.update({x["desktop_path"]:x for x in o["rows"]})
assert len(mr)==7926 and len(lr)==7926 and mr[P]["blobSha"]==SHA and mr[P]["size"]==SIZE and lr[P]["desktop_blob_sha"]==SHA and lr[P]["implementation_status"]=="mapped"
print("rebaseline-ed06d2c-static-integrity: ok")
