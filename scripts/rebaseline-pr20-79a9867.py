#!/usr/bin/env python3
import json
from pathlib import Path
OLD="ed06d2c96471d5e80b66cd3c4b09116e968a0e56"
NEW="79a9867ac6cbfecc5af9fcc9ac81225890c20245"
CHANGED={
"source/host/app/src/main.rs":("27cd42f43aee54877ce3f415482cd7f0480c9000",526035),
"source/host/src/extensions/transcript/production_runtime.rs":("43d3b141c0734a5487c9c0e0a9146f4650085294",60814),
"source/host/src/extensions/transcript/transcript_manager.rs":("5240e9a3e7f0ab5d7f74b41e6786654b008ee882",33521),
"source/host/src/gateway_protocol.rs":("6fd73d16ade784bb22b09dd1a29ce1471c9b1982",5141),
"source/host/tests/host_upgrade_production_contract.rs":("79d075b6dcc372eeee8e7fab9b4aaecbb701bc4e",4802),
}
def dump(p,o): Path(p).write_text(json.dumps(o,ensure_ascii=False,indent=2)+"\n")
mi= json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text()); assert mi["authority"]["commit"]==OLD and mi["fileCount"]==7926
for g in mi["groups"]:
  p=Path(g["path"]); o=json.loads(p.read_text()); assert o["sourceCommit"]==OLD; o["sourceCommit"]=NEW
  if g["name"]=="source-host":
    rows={r["path"]:r for r in o["files"]}
    for path,(sha,size) in CHANGED.items(): rows[path]["blobSha"]=sha; rows[path]["size"]=size
  dump(p,o)
mi["authority"]["commit"]=NEW; mi["authority"]["generatedAt"]="2026-10-03"; dump("manifests/desktop-pr20-reference-index.json",mi)
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text()); assert li["source"]["commit"]==OLD
for ch in li["chunks"]:
  p=Path(ch["path"]); o=json.loads(p.read_text()); assert o["sourceCommit"]==OLD; o["sourceCommit"]=NEW
  if ch["name"]=="source-host":
    rows={r["desktop_path"]:r for r in o["rows"]}
    for path,(sha,_) in CHANGED.items():
      r=rows[path]; r["desktop_blob_sha"]=sha; r["implementation_status"]="mapped"
      r["test_evidence"]="Desktop PR #20 79a9867 changes this exact blob for recreate-resume carry. Current iOS exact-head implementation has not yet proved durable pending-wake carry/rearm plus interrupted-turn resume; same-head focused and Actions evidence is required."
    rows["source/host/app/src/main.rs"]["desktop_responsibility"]="Shipping Host lifecycle/gateway composition now carries durable pending wakes across recreate, restores/rearms eligible CloudAgent/Shell work, restores durable interrupted turns, and still owns the previously implemented turn-delivery and automation settlement effects."
    rows["source/host/app/src/main.rs"]["desktop_visible_effect"]="After host/app recreation, durable background work and interrupted Agent turns resume without being dropped or duplicated; existing terminal delivery and automation effects remain ordered under the same Host composition."
    rows["source/host/src/extensions/transcript/production_runtime.rs"]["desktop_responsibility"]="Expose the durable subset of pending wakes that may cross recreate, fail-closed when recreate carry is disabled, restricted to CloudAgent and Shell kinds."
    rows["source/host/src/extensions/transcript/production_runtime.rs"]["desktop_visible_effect"]="Only eligible durable wakes are serialized into recreate status; unrelated or disabled wake types are not carried."
    rows["source/host/src/extensions/transcript/transcript_manager.rs"]["desktop_responsibility"]="Canonical lifecycle owner restores carried pending-wake markers after recreate: coerce/validate, filter eligible kinds, deduplicate against durable store, mark Shell interruption, persist through the configured pending-wake owner, and rearm with recreate provenance."
    rows["source/host/src/extensions/transcript/transcript_manager.rs"]["desktop_visible_effect"]="Recreated sessions resume each eligible wake at most once through canonical persistence/rearm ownership rather than renderer replay; existing automation projection remains a sub-responsibility."
    rows["source/host/src/gateway_protocol.rs"]["desktop_responsibility"]="Expose the typed resumeAfterRecreate lifecycle command in the authoritative Host gateway protocol."
    rows["source/host/src/gateway_protocol.rs"]["desktop_visible_effect"]="The lifecycle caller can hand carried resume identities and pending wakes back to the canonical Host after recreation."
    rows["source/host/tests/host_upgrade_production_contract.rs"]["desktop_responsibility"]="Focused shipping contract proving recreate status exports pending wakes and resumeAfterRecreate restores pending wakes before resuming durable interrupted turns."
    rows["source/host/tests/host_upgrade_production_contract.rs"]["desktop_visible_effect"]="Regression evidence prevents upgrade/recreate from silently dropping pending wake work or bypassing the canonical Host resume path."
  dump(p,o)
li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)
cp=Path("scripts/check-desktop-pr20-ios-architecture.py"); s=cp.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in s; cp.write_text(s.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))
sp=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); s=sp.read_text(); bt=chr(96); old=f"- pinned source commit for this baseline: {bt}{OLD}{bt}"; assert old in s; s=s.replace(old,f"- pinned source commit for this baseline: {bt}{NEW}{bt}",1); assert "### 1.12 Exact-HEAD rebaseline" not in s
sec="""### 1.12 Exact-HEAD rebaseline: 2026-10-03 / 79a9867ac6cbfecc5af9fcc9ac81225890c20245

Desktop PR #20 adds one shipping lifecycle slice across five source/host files while the selected inventory remains exactly 7,926 blobs. The new resumeAfterRecreate path carries canonical upgrade-resume Agent identities plus durable pending wakes, restores the manager lifecycle state, restores eligible pending wakes, then resumes interrupted upgrade turns. Recreate status exports the same pending-wake carry.

Only CloudAgent and Shell pending-wake kinds may cross recreate, and carry can be disabled. Restore is canonical-Host owned: values are coerced/validated, ineligible kinds ignored, existing durable identities deduplicated, Shell markers flagged interrupted-by-recreate, newly persisted through the pending-wake runtime owner, then rearmed with recreate provenance. No renderer replay owns this state.

Current iOS source has no resumeAfterRecreate/pending-wake carry equivalent by name and must be audited by responsibility rather than copied gateway syntax. The immediately preceding NativeEngine closing-send/empty-delivery implementation remains real production work, but main.rs is mapped again because its upstream responsibility expanded. TranscriptManager's automation projection also remains a valid implemented sub-responsibility while its changed row returns to mapped for the new recreate carry gap. The iOS implementation must locate or add one durable lifecycle/wake owner below SwiftUI, preserve identity/idempotency across scene/app recreation, and resume interrupted work only after durable wake state has been restored.

"""
assert "## 2. Product goal" in s; sp.write_text(s.replace("## 2. Product goal",sec+"## 2. Product goal",1))
# verify all chunks and changed identities
mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text()); li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text()); mr={}; lr={}
for g in mi["groups"]:
  o=json.loads(Path(g["path"]).read_text()); assert o["sourceCommit"]==NEW; mr.update({r["path"]:r for r in o["files"]})
for ch in li["chunks"]:
  o=json.loads(Path(ch["path"]).read_text()); assert o["sourceCommit"]==NEW; lr.update({r["desktop_path"]:r for r in o["rows"]})
assert len(mr)==7926 and len(lr)==7926
for path,(sha,size) in CHANGED.items():
  assert mr[path]["blobSha"]==sha and mr[path]["size"]==size and lr[path]["desktop_blob_sha"]==sha and lr[path]["implementation_status"]=="mapped"
print("rebaseline-79a9867-static-integrity: ok")
