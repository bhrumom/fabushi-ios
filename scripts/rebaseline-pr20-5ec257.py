#!/usr/bin/env python3
import json, re
from pathlib import Path
OLD="cb2267d52ad816287ad97a357e6e7d4135e79083"
NEW="5ec257a7920478b56a88bdf24b85eb845aacfb46"
CHANGED={
"source/host/app/src/main.rs":("0b48f2c2955e00654db2b2e58d2d068dee5b922b",526370),
"source/host/src/extensions/transcript/pending_wake_rearm.rs":("7520306135c9210bde37f59cdee6a5584c516410",13147),
"source/host/src/extensions/transcript/transcript_manager.rs":("36bae295949a50d79b2bf6bc2fe3d12209acc65b",32847),
"source/host/tests/host_upgrade_production_contract.rs":("e628a80521719a9157cfc7c8a63794101c4c5aa2",5409),
"source/host/tests/pending_wake_rearm_contract.rs":("05f6a1e21882f6a5eab4037d609613cc6bd30402",10957),
}
def dump(p,o): Path(p).write_text(json.dumps(o,ensure_ascii=False,indent=2)+"\n")
mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text()); assert mi["authority"]["commit"]==OLD and mi["fileCount"]==7926
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

  r=rows["source/host/app/src/main.rs"]
  r["desktop_responsibility"]="Shipping Host composes recreate recovery through TranscriptManager while the canonical pending-wake owner validates carried wake identity and eligibility before persistence or replay; existing upgrade quiesce, turn-delivery recovery, and automation settlement remain ordered sub-responsibilities."
  r["desktop_visible_effect"]="Host recreation cannot blindly replay stale/background work: restore follows one canonical owner and preserves quiesce/resume ordering."
  r["notes"] += " Revalidated against Desktop PR #20 5ec257a7920478b56a88bdf24b85eb845aacfb46. The cb2267d->7582495 selected-source delta centralizes recreate carry validation/replay in PendingWakeRearm; the final 5ec257a commit changes only Desktop parity evidence and does not alter selected source blobs. iOS remains mapped pending real durable lifecycle/wake recovery and exact-head evidence."

  r=rows["source/host/src/extensions/transcript/pending_wake_rearm.rs"]
  r.update({
   "desktop_responsibility":"Canonical durable pending-wake recreate owner validates carried wake identity and eligibility before persistence/replay: carry-disabled or not-ready restores stop, locally owned identities dedupe, gone Agents/group sessions/Subagents are suppressed, CloudAgent work is rearmed with recreate provenance, and Shell work becomes an interrupted notice instead of being blindly rerun.",
   "desktop_owner":"host",
   "desktop_visible_effect":"After Host recreation, eligible cloud work resumes at most once while stale/local/group work is suppressed and interrupted shell work is surfaced without re-executing the shell.",
   "ios_disposition":"ios-adapted",
   "ios_target_path":"source/packages/mahayana-rs/mahayana-feature-host/src/implementation.rs",
   "ios_language":"Rust",
   "ios_platform_delta":"Adapt recreate wake carry to native app/scene and Host-generation recovery. SwiftUI/Coordinator may signal lifecycle; durable eligibility, identity dedupe and replay policy stay in the canonical Rust Host/runtime owner.",
   "production_evidence":"",
   "test_evidence":"",
   "notes":"Reviewed against Desktop PR #20 5ec257a7920478b56a88bdf24b85eb845aacfb46. Current iOS lacks an equivalent durable recreate-wake carry owner, so this is mapping only; no implementation/verification is claimed."
  })

  r=rows["source/host/src/extensions/transcript/transcript_manager.rs"]
  r["desktop_responsibility"]="Canonical lifecycle facade orders runner/transcript upgrade quiesce and delegates recreate-carried wake validation/restoration to PendingWakeRearm; runner quiesce is cleared only during resume-after-recreate, while automation projection and handoff remain manager responsibilities."
  r["desktop_visible_effect"]="Recreated sessions restore only owner-approved durable work before normal resume, without renderer replay or a second manager-local wake policy."
  r["notes"] += " Revalidated against Desktop PR #20 5ec257a7920478b56a88bdf24b85eb845aacfb46. Recreate carry filtering moved from manager-local logic into PendingWakeRearm; iOS must preserve the facade-versus-owner split."

  r=rows["source/host/tests/host_upgrade_production_contract.rs"]
  r.update({
   "desktop_responsibility":"Focused shipping contract proves resumeAfterRecreate routes carried pending wakes through TranscriptManager into canonical PendingWakeRearm before durable interrupted-turn resume.",
   "desktop_owner":"host",
   "desktop_visible_effect":"Regression evidence fails if recreate bypasses the canonical wake owner or resumes interrupted turns before safe wake restoration.",
   "ios_disposition":"ios-adapted",
   "ios_target_path":"mobile/ios/FabushiTests/IOSLifecycleParityTests.swift",
   "ios_language":"Swift",
   "ios_platform_delta":"Prove equivalent native lifecycle/recreation ordering around the iOS Coordinator/Host generation boundary, not Electron gateway syntax.",
   "production_evidence":"",
   "test_evidence":"",
   "notes":"Reviewed against Desktop PR #20 5ec257a7920478b56a88bdf24b85eb845aacfb46. Mapped to the existing iOS lifecycle test surface; required production behavior is not implemented yet."
  })

  r=rows["source/host/tests/pending_wake_rearm_contract.rs"]
  r.update({
   "desktop_responsibility":"Focused owner contract proves recreate carry filtering, local-identity dedupe, gone/group/Subagent suppression, CloudAgent rearm, and Shell interrupted-notice behavior in PendingWakeRearm.",
   "desktop_owner":"host",
   "desktop_visible_effect":"Regression evidence prevents stale/unsafe wake replay and prevents interrupted shell work from being blindly re-executed after Host recreation.",
   "ios_disposition":"ios-adapted",
   "ios_target_path":"mobile/ios/FabushiTests/IOSLifecycleParityTests.swift",
   "ios_language":"Swift",
   "ios_platform_delta":"Prove the same product effect over native lifecycle recovery and the canonical durable work owner.",
   "production_evidence":"",
   "test_evidence":"",
   "notes":"Reviewed against Desktop PR #20 5ec257a7920478b56a88bdf24b85eb845aacfb46. Mapping only; focused iOS recovery evidence follows real production ownership."
  })
 dump(p,o)
li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)

cp=Path("scripts/check-desktop-pr20-ios-architecture.py"); s=cp.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in s; cp.write_text(s.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))
sp=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); s=sp.read_text(); old=f"- pinned source commit for this baseline: `{OLD}`"; assert old in s; s=s.replace(old,f"- pinned source commit for this baseline: `{NEW}`",1); assert "### 1.14 Exact-HEAD rebaseline" not in s
sec="""### 1.14 Exact-HEAD rebaseline: 2026-10-03 / 5ec257a7920478b56a88bdf24b85eb845aacfb46

Desktop PR #20 advanced four commits from `cb2267d52ad816287ad97a357e6e7d4135e79083` to `5ec257a7920478b56a88bdf24b85eb845aacfb46`. The selected `frontend/** + source/**` inventory remains exactly 7,926 paths. Through `75824953`, only five existing Host files change; the final `5ec257a` commit changes only `projects/grok-fabu-parity/architecture-manifest.json`, so it adds upstream Desktop evidence but no new selected source blob. All manifest/ledger sourceCommit authorities, indexes and the strict checker are nevertheless rebound to the current exact HEAD.

The selected-source responsibility is recreate-carry safety ownership. `TranscriptManager` is the lifecycle facade but delegates carried values to canonical `PendingWakeRearm.restore_recreate_carried_pending_wakes`. That owner fails closed when carry is disabled or runtime execution is unavailable, deduplicates identities already durable on the replacement Host, suppresses gone Agents, group sessions and Subagent wakes, and treats session lookup failure as a failed restore rather than guessing. Only CloudAgent and Shell wakes cross recreate. CloudAgent work is rearmed with recreate provenance; Shell wakes are marked `interrupted_by_recreate` and produce an interruption notice instead of blindly re-running shell work. The shipping upgrade contract follows this owner.

The `5ec257a` parity-manifest-only commit records Desktop's own upgrade/recreate/resume row as implemented and expands its production/test evidence across TranscriptManager, Runner quiesce, pending-wake restore, Gateway and source-specific resume. iOS does not inherit that status: it remains independently gated by native production composition and exact-iOS-HEAD evidence.

Current iOS still lacks this complete recreate-carry owner and the preceding active-operation durability guarantee. NativeEngine has `active_prompt`/operation-attempt state and `resume_operation`, but ordinary execution persists the session only after the run returns. `feature.sessionActivity` reaches canonical Rust `FeatureHostController`, yet currently records focus/scene activity rather than a generation-safe quiesce/resume state machine. Therefore all five changed selected-source rows remain only `mapped`. First closure is to durably checkpoint exact active prompt/operation identity before inference, then wire native Host/Coordinator quiesce/recreate recovery with durable identity and the same safe wake filters, including no blind Shell replay.

"""
assert "## 2. Product goal" in s; sp.write_text(s.replace("## 2. Product goal",sec+"## 2. Product goal",1))

mp=Path("MIGRATION_SOURCE.md"); s=mp.read_text(); s,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",s,count=1); assert n==1; mp.write_text(s)

mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text()); li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text()); mr={}; lr={}
for g in mi["groups"]:
 o=json.loads(Path(g["path"]).read_text()); assert o["sourceCommit"]==NEW; mr.update({r["path"]:r for r in o["files"]})
for ch in li["chunks"]:
 o=json.loads(Path(ch["path"]).read_text()); assert o["sourceCommit"]==NEW; lr.update({r["desktop_path"]:r for r in o["rows"]})
assert len(mr)==7926 and len(lr)==7926
for path,(sha,size) in CHANGED.items():
 assert mr[path]["blobSha"]==sha and mr[path]["size"]==size and lr[path]["desktop_blob_sha"]==sha and lr[path]["implementation_status"]=="mapped"
print("rebaseline-5ec257-static-integrity: ok")
