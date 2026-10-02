#!/usr/bin/env python3
import json,re
from pathlib import Path
OLD="2126a60a388b9bc44545f11eaa22889861314d39"; NEW="1d9d9b72d2b6cf2a28d641159d68ffcb3c85dbef"
META={
"source/host/app/src/main.rs":("6bae266636427045073663c69779292cfadb1f1f",521990),
"source/host/src/host_runner_composition.rs":("d25a85497bbd61ae7c7568b9a4b3feca09d0a56e",15614),
"source/host/tests/host_runner_composition_production_wiring_contract.rs":("28370427c38a9e447539657eee959a72718c3bfa",7125)}
def dump(p,v): Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+"\n")
mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text()); li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==OLD and mi["fileCount"]==7927; assert li["source"]["commit"]==OLD and li["rowCount"]==7927
for g in mi["groups"]:
 p=Path(g["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD; v["sourceCommit"]=NEW
 if g["name"]=="source-host":
  by={x["path"]:x for x in v["files"]}
  for path,(sha,size) in META.items(): by[path].update(blobSha=sha,size=size)
  assert len(v["files"])==957
 dump(p,v)
for c in li["chunks"]:
 p=Path(c["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD; v["sourceCommit"]=NEW
 if c["name"]=="source-host":
  by={x["desktop_path"]:x for x in v["rows"]}
  vals={
   "source/host/app/src/main.rs":("Shipping Host delegates the complete production Runner object graph plus computer-use preparation/control-lease/turn-settlement lifecycle to HostRunnerComposition; main.rs supplies request-specific inputs but no longer owns a parallel ComputerUseCoordination lifecycle.","Computer-use turns and ordinary turns share one Host-owned composition/lifecycle boundary, preventing leaked control leases or divergent settlement.","source/packages/mahayana-rs/mahayana-feature-host/src/implementation.rs","iOS must keep computer-use/native-control preparation and settlement with the same canonical Host/Runner lifecycle owner; UI/Coordinator can request or project state but cannot own leases."),
   "source/host/src/host_runner_composition.rs":("Canonical Host -> Runner owner for turn assembly, checkpoint/state surfaces, final Runner construction, and computer-use session lifecycle including preparation, control lease, ready/failed state, model/usage settlement, release, and window cleanup.","One Host owner fences computer control and Runner lifecycle from preparation through terminal settlement.","source/packages/mahayana-rs/mahayana-feature-host/src/implementation.rs","Map Desktop computer-use coordination to iOS-native capability/session ownership without introducing SwiftUI or Coordinator lease truth."),
   "source/host/tests/host_runner_composition_production_wiring_contract.rs":("Focused production contract proving HostRunnerComposition owns turn/checkpoint/state/Runner construction and computer-use session lifecycle while shipping main.rs cannot directly acquire/release control leases or own preparation/settlement.","CI rejects parallel Runner or computer-use lifecycle ownership.","mobile/ios/FabushiTests/RunnerParityTests.swift","Prove native iOS Host/Runner lifecycle ownership with behavior contracts; do not substitute Desktop string matching.")
  }
  for path,(resp,effect,target,delta) in vals.items():
   r=by[path]; r.update(desktop_blob_sha=META[path][0],desktop_responsibility=resp,desktop_owner="host",desktop_visible_effect=effect,ios_disposition="ios-adapted",ios_target_path=target,ios_language=("Rust" if target.endswith(".rs") else "Swift"),ios_platform_delta=delta,implementation_status="mapped",production_evidence="",test_evidence="",notes=f"Revalidated against Desktop PR #20 {NEW}; computer-use lifecycle ownership moved under HostRunnerComposition. Current iOS parity is not inherited; shipping-path audit plus same-head evidence required.")
  assert len(v["rows"])==957
 dump(p,v)
mi["authority"]["commit"]=NEW; dump("manifests/desktop-pr20-reference-index.json",mi); li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)
p=Path("scripts/check-desktop-pr20-ios-architecture.py"); t=p.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in t; p.write_text(t.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))
p=Path("MIGRATION_SOURCE.md"); t=p.read_text(); t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1; p.write_text(t)
p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); t=p.read_text(); old=f"- pinned source commit for this baseline: `{OLD}`"; assert old in t; t=t.replace(old,f"- pinned source commit for this baseline: `{NEW}`",1); assert "### 1.21 Exact-HEAD rebaseline" not in t
section="""### 1.21 Exact-HEAD rebaseline: 2026-10-03 / `1d9d9b72d2b6cf2a28d641159d68ffcb3c85dbef`

Desktop PR #20 advanced one production commit from `2126a60a388b9bc44545f11eaa22889861314d39` to `1d9d9b72d2b6cf2a28d641159d68ffcb3c85dbef`; selected inventory remains **7,927** and `source-host` remains 957. The same three Host paths changed.

`HostRunnerComposition` now also owns computer-use session lifecycle: preparation and control-lease acquisition, ready/failed preparation state, ownership checks, model/usage settlement at turn end, lease release, and window cleanup. Shipping `main.rs` delegates these operations and the focused contract forbids direct `ComputerUseCoordination` lifecycle ownership there. This extends the same single composition owner that already owns turn decoration, transcript/checkpoint sinks, state surfaces, and final Runner construction.

On iOS, computer-use or native-control mechanisms may differ, but control/session lifecycle truth must stay with the canonical Host/Runner owner. SwiftUI and Coordinator may transport intent and project state; they cannot own control leases, preparation truth, or terminal cleanup. The three changed rows remain `mapped` until the shipping iOS path and same-head focused/CI evidence prove this ownership.

"""
p.write_text(t.replace("## 2. Product goal",section+"## 2. Product goal",1))
mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text()); li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text()); assert mi["authority"]["commit"]==NEW and mi["fileCount"]==7927; assert li["source"]["commit"]==NEW and li["rowCount"]==7927
for g in mi["groups"]: assert json.loads(Path(g["path"]).read_text())["sourceCommit"]==NEW
for c in li["chunks"]: assert json.loads(Path(c["path"]).read_text())["sourceCommit"]==NEW
print("rebaseline-1d9d9b7-static-integrity: ok")
