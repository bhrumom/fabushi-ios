#!/usr/bin/env python3
import json,re
from pathlib import Path
OLD="854d4bffde64dee2d7f12ba093207381ef369af4"; NEW="2126a60a388b9bc44545f11eaa22889861314d39"
META={
"source/host/app/src/main.rs":("80c22469aff95c1cff5b13487080001386418352",523155),
"source/host/src/host_runner_composition.rs":("f3e85fe9b4838fd7bf8be9c52f4c7c438742d3e3",13465),
"source/host/tests/host_runner_composition_production_wiring_contract.rs":("65b967fea8f9a30713082408824b75c82990a4f9",5514)}
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
   "source/host/app/src/main.rs":("Shipping Host delegates production turn decoration, transcript/checkpoint and state-surface construction, and the final ProductionTurnAgentOwner/SandAgentRunner facade construction to HostRunnerComposition; main.rs supplies request-scoped dependencies but does not construct a parallel Runner owner.","Every production turn crosses one Host-owned composition path including checkpoint, quiesce and generated-agent runtime wiring.","source/packages/mahayana-rs/mahayana-feature-host/src/implementation.rs","iOS must keep final Runner facade construction with the same single native Host/Runtime composition owner; SwiftUI/Coordinator remain callers, not owners."),
   "source/host/src/host_runner_composition.rs":("Canonical Host -> Runner production composition owner for turn decorators, transcript/checkpoint sink, state surfaces, and final ProductionTurnAgentOwner/SandAgentRunner construction including upgrade-quiesce and generated-agent runtime.","One owner determines the complete shipping Runner object graph and lifecycle fences for each turn.","source/packages/mahayana-rs/mahayana-feature-host/src/implementation.rs","Adapt to iOS-native runtime boundaries while retaining one Host-owned constructor for the complete production Runner graph."),
   "source/host/tests/host_runner_composition_production_wiring_contract.rs":("Focused production contract proving HostRunnerComposition exclusively owns turn decoration, checkpoint/state surfaces, and final Runner facade construction; shipping main.rs may only consume those entrypoints.","CI rejects any second shipping Runner/checkpoint/state construction path.","mobile/ios/FabushiTests/RunnerParityTests.swift","Prove the equivalent iOS shipping owner through native behavior/composition contracts, not copied Desktop string assertions.")
  }
  for path,(resp,effect,target,delta) in vals.items():
   r=by[path]; r.update(desktop_blob_sha=META[path][0],desktop_responsibility=resp,desktop_owner="host",desktop_visible_effect=effect,ios_disposition="ios-adapted",ios_target_path=target,ios_language=("Rust" if target.endswith(".rs") else "Swift"),ios_platform_delta=delta,implementation_status="mapped",production_evidence="",test_evidence="",notes=f"Revalidated against Desktop PR #20 {NEW}; ownership expanded again and current iOS parity is not inherited. Shipping-path audit plus same-head evidence required.")
  assert len(v["rows"])==957
 dump(p,v)
mi["authority"]["commit"]=NEW; dump("manifests/desktop-pr20-reference-index.json",mi); li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)
p=Path("scripts/check-desktop-pr20-ios-architecture.py"); t=p.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in t; p.write_text(t.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))
p=Path("MIGRATION_SOURCE.md"); t=p.read_text(); t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1; p.write_text(t)
p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); t=p.read_text(); old=f"- pinned source commit for this baseline: `{OLD}`"; assert old in t; t=t.replace(old,f"- pinned source commit for this baseline: `{NEW}`",1); assert "### 1.20 Exact-HEAD rebaseline" not in t
section="""### 1.20 Exact-HEAD rebaseline: 2026-10-03 / `2126a60a388b9bc44545f11eaa22889861314d39`

Desktop PR #20 advanced one production commit from `854d4bffde64dee2d7f12ba093207381ef369af4` to `2126a60a388b9bc44545f11eaa22889861314d39`. The selected inventory remains exactly **7,927** blobs and `source-host` remains 957 rows; only `source/host/app/src/main.rs`, `source/host/src/host_runner_composition.rs`, and `source/host/tests/host_runner_composition_production_wiring_contract.rs` changed.

The single-owner boundary is now complete through Runner facade construction. `HostRunnerComposition.compose_production_runner(...)` constructs `ProductionTurnAgentOwner`, attaches the production checkpoint sink and shared upgrade-quiesce signal, constructs `SandAgentRunner`, and attaches the generated-Agent runtime. Shipping `main.rs` delegates this construction and is contractually forbidden from directly rebuilding `ProductionTurnAgentOwner` or `SandAgentRunner`. This extends the already centralized turn decorators, transcript/checkpoint sink, and turn state surfaces.

The iOS responsibility is the same even though the native mechanism differs: one Host/Runtime owner must construct the complete production Runner graph and lifecycle fences. SwiftUI and Mahayana Coordinator remain request/lifecycle transport layers, not parallel Runner constructors. These three changed rows stay `mapped` until the current iOS shipping path is audited and same-iOS-HEAD focused/CI evidence proves the equivalent ownership.

"""
p.write_text(t.replace("## 2. Product goal",section+"## 2. Product goal",1))
mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text()); li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text()); assert mi["authority"]["commit"]==NEW and mi["fileCount"]==7927; assert li["source"]["commit"]==NEW and li["rowCount"]==7927
for g in mi["groups"]: assert json.loads(Path(g["path"]).read_text())["sourceCommit"]==NEW
for c in li["chunks"]: assert json.loads(Path(c["path"]).read_text())["sourceCommit"]==NEW
print("rebaseline-2126a60-static-integrity: ok")
