#!/usr/bin/env python3
import json
from pathlib import Path
OLD="79a9867ac6cbfecc5af9fcc9ac81225890c20245"
NEW="cb2267d52ad816287ad97a357e6e7d4135e79083"
CHANGED={
"source/host/app/src/main.rs":("aa3aa450897f21c801fd4a40be8415ce321d9da0",526122),
"source/host/src/extensions/transcript/runner_registry.rs":("431bb56a3f6447b0b9355eaa452fb2d019cd2e63",12128),
"source/host/src/extensions/transcript/transcript_manager.rs":("8a88ea60451d703f9534270c22e27d3aaec55f80",33640),
"source/host/src/runner/generated_agent_turn_stream.rs":("6d9003d34b1f07ec8ec45ddd5ff3eaa040bb6ee4",8088),
"source/host/src/runner/production_turn_agent_owner.rs":("d0246e203a83ec68c46c6b24ef798c1d86e2e3b2",9692),
"source/host/src/runner/turn_run_shell.rs":("0961697139e3829a32b8b50d291f4e42ddf5bd9d",9888),
"source/host/tests/production_turn_agent_owner_contract.rs":("8c01db817c6cd16125c25efa7eace047fb548c68",9148),
"source/host/tests/transcript_manager_contract.rs":("915db46e1b39788b6b09c10623690d5fec7a4a19",29143),
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
      r["test_evidence"]="Desktop PR #20 cb2267d changes this exact blob for shipping upgrade quiesce. Current iOS has not yet proved ordered quiesce→durable checkpoint→Host recreation→resume on this upstream identity; exact-head focused and Actions evidence is required."
    rows["source/host/app/src/main.rs"]["desktop_responsibility"]="Shipping Host composition passes the canonical runner-registry upgrade-quiesce signal into active routed Agent owners, in addition to recreate pending-wake carry, turn-delivery recovery, and automation settlement."
    rows["source/host/src/extensions/transcript/runner_registry.rs"]["desktop_responsibility"]="Canonical shipping runner registry owns a shared upgrade-quiescing signal, cancels active routed/group tasks when forced upgrade begins, exposes the signal to production turn owners, and clears it only after recreate resume."
    rows["source/host/src/extensions/transcript/runner_registry.rs"]["desktop_visible_effect"]="Forced Host upgrade stops new/active shipping turn work before recreation and prevents old runners from continuing concurrently with the replacement generation."
    rows["source/host/src/extensions/transcript/transcript_manager.rs"]["desktop_responsibility"]="Canonical lifecycle facade orders runner quiesce with transcript-runtime quiesce and clears runner quiesce only during resume-after-recreate; existing pending-wake restore and automation projection remain sub-responsibilities."
    rows["source/host/src/runner/generated_agent_turn_stream.rs"]["desktop_responsibility"]="Generated-Agent persistence observes the shared upgrade-quiesce signal and records that the active turn quiesced, while retaining canonical checkpoint/cancellation ownership."
    rows["source/host/src/runner/generated_agent_turn_stream.rs"]["desktop_visible_effect"]="Generated-Agent execution stops at the same forced-upgrade boundary as direct turns and leaves a terminal quiesce fact that recreate recovery can distinguish from ordinary cancellation."
    rows["source/host/src/runner/production_turn_agent_owner.rs"]["desktop_responsibility"]="Shipping turn owner propagates upgrade-quiesce state into both generated and direct turn execution and marks terminal settlement as quiesced when cancellation/quiesce raced the run."
    rows["source/host/src/runner/turn_run_shell.rs"]["desktop_responsibility"]="Canonical per-turn shell records quiesced_for_upgrade on the current owner token before terminal outcome settlement."
    rows["source/host/tests/production_turn_agent_owner_contract.rs"]["desktop_responsibility"]="Focused production contract proves a shipping Agent turn cancelled by forced upgrade settles as Cancelled with quiesced_for_upgrade=true."
    rows["source/host/tests/production_turn_agent_owner_contract.rs"]["desktop_visible_effect"]="Regression evidence fails if forced-upgrade cancellation loses its quiesce identity or settles indistinguishably from an ordinary user/provider cancellation."
    rows["source/host/tests/transcript_manager_contract.rs"]["desktop_responsibility"]="Focused manager contract proves the shipping runner registry enters upgrade quiesce with the manager and is cleared only by resume-after-recreate."
  dump(p,o)
li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)

cp=Path("scripts/check-desktop-pr20-ios-architecture.py"); s=cp.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in s; cp.write_text(s.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))
sp=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); s=sp.read_text(); bt=chr(96); old=f"- pinned source commit for this baseline: {bt}{OLD}{bt}"; assert old in s; s=s.replace(old,f"- pinned source commit for this baseline: {bt}{NEW}{bt}",1); assert "### 1.13 Exact-HEAD rebaseline" not in s
sec="""### 1.13 Exact-HEAD rebaseline: 2026-10-03 / cb2267d52ad816287ad97a357e6e7d4135e79083

Desktop PR #20 adds the shipping quiesce half of the recreate lifecycle across eight source/host files while the selected inventory remains exactly 7,926 blobs. The runner registry now owns one shared upgrade-quiescing signal. Forced upgrade sets the signal and cancels active routed/group tasks; the signal is injected into production turn owners and generated-Agent persistence so a turn that is cancelled while upgrade quiesce is active settles with quiesced_for_upgrade=true. The manager clears this runner quiesce only during resume-after-recreate.

This extends, rather than replaces, the 79a recreate carry contract. Correct ordering is now: request quiesce, stop/settle active shipping runners with durable identity, carry pending durable work, recreate Host, restore/rearm carried work, then clear quiesce/resume. iOS cannot satisfy this by merely refreshing UI state or by restarting a Host generation with no work identity.

The current iOS NativeEngine already has persisted NativeSession state containing active_prompt and operation attempts plus resume_operation, but ordinary run() persists only after execution returns. Therefore an active process recreation can still lose the exact work identity, and there is no canonical shared upgrade-quiesce fence across the current Coordinator/Host generation boundary. All eight changed rows remain mapped. The iOS adaptation must first durably checkpoint the active prompt/operation before inference, then wire one generation-safe quiesce/resume path through existing Host/Coordinator owners; SwiftUI remains a lifecycle trigger only, never the source of runnable work truth.

"""
assert "## 2. Product goal" in s; sp.write_text(s.replace("## 2. Product goal",sec+"## 2. Product goal",1))

mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text()); li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text()); mr={}; lr={}
for g in mi["groups"]:
  o=json.loads(Path(g["path"]).read_text()); assert o["sourceCommit"]==NEW; mr.update({r["path"]:r for r in o["files"]})
for ch in li["chunks"]:
  o=json.loads(Path(ch["path"]).read_text()); assert o["sourceCommit"]==NEW; lr.update({r["desktop_path"]:r for r in o["rows"]})
assert len(mr)==7926 and len(lr)==7926
for path,(sha,size) in CHANGED.items():
  assert mr[path]["blobSha"]==sha and mr[path]["size"]==size and lr[path]["desktop_blob_sha"]==sha and lr[path]["implementation_status"]=="mapped"
print("rebaseline-cb2267d-static-integrity: ok")
