#!/usr/bin/env python3
import json
import re
from pathlib import Path

OLD="c96b56c47c6b2a478370839888124d1703aac518"
NEW="854d4bffde64dee2d7f12ba093207381ef369af4"
META={
 "source/host/app/src/main.rs":("736bac8f6400df33c4b60b3321aea44d725da18d",523340),
 "source/host/src/host_runner_composition.rs":("35e0c7727a9c7dac5f9f8f626f027d243b015b8d",12628),
 "source/host/tests/host_runner_composition_production_wiring_contract.rs":("b448acf1341cb4b3fe6b4f436c1bc0d5c1a5bc38",4474),
}

def dump(p,v):
    Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+"\n")

mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==OLD and mi["fileCount"]==7927
assert li["source"]["commit"]==OLD and li["rowCount"]==7927

for g in mi["groups"]:
    p=Path(g["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD
    v["sourceCommit"]=NEW
    if g["name"]=="source-host":
        by={x["path"]:x for x in v["files"]}
        for path,(sha,size) in META.items():
            by[path]["blobSha"]=sha; by[path]["size"]=size
        assert len(v["files"])==957
    dump(p,v)

for c in li["chunks"]:
    p=Path(c["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD
    v["sourceCommit"]=NEW
    if c["name"]=="source-host":
        by={x["desktop_path"]:x for x in v["rows"]}
        def reset(path, resp, effect, target, delta, notes):
            r=by[path]
            r["desktop_blob_sha"]=META[path][0]
            r["desktop_responsibility"]=resp
            r["desktop_owner"]="host"
            r["desktop_visible_effect"]=effect
            r["ios_disposition"]="ios-adapted"
            r["ios_target_path"]=target
            r["ios_language"]="Rust" if target.endswith(".rs") else "Swift"
            r["ios_platform_delta"]=delta
            r["implementation_status"]="mapped"
            r["production_evidence"]=""
            r["test_evidence"]=""
            r["notes"]=notes
        reset("source/host/app/src/main.rs",
          "Shipping Host delegates production Runner turn assembly, transcript/checkpoint composition, and turn state-surface construction to HostRunnerComposition; main.rs resolves concrete request inputs but must not construct parallel checkpoint/state/Runner owners.",
          "Shipping turns use one canonical Host -> Runner assembly path for model/tool behavior, durable transcript checkpointing, memory/agent state, and multitask state.",
          "source/packages/mahayana-rs/mahayana-feature-host/src/implementation.rs",
          "iOS must keep checkpoint/state/Runner composition below SwiftUI/Coordinator in one native Host-owned path; platform storage may differ but ownership and one-time assembly may not.",
          f"Revalidated against Desktop PR #20 {NEW}. The c96b56c ownership move expanded: main.rs now delegates checkpoint/transcript-mirror and turn-state-surface construction as well as turn decorators to HostRunnerComposition. Current iOS parity is not assumed; row remains mapped.")
        reset("source/host/src/host_runner_composition.rs",
          "Canonical Host -> Runner composition owner for production turn decorators, transcript/checkpoint sink construction, and turn state surfaces including memory-backed SandAgentState and optional multitask todo state.",
          "One Host owner determines the exact Runner capability stack and the durable state/checkpoint surfaces observed by every production turn.",
          "source/packages/mahayana-rs/mahayana-feature-host/src/implementation.rs",
          "Use the existing iOS-native Host/Runtime storage and Runner boundary, but centralize construction so Coordinator/UI cannot create a second state/checkpoint/turn assembly path.",
          f"Reviewed at Desktop PR #20 {NEW}. compose_production_checkpoint_sink and compose_turn_state_surfaces join compose_production_turn under HostRunnerComposition. iOS needs real shipping-owner audit and focused contracts before promotion.")
        reset("source/host/tests/host_runner_composition_production_wiring_contract.rs",
          "Focused production contract proving HostRunnerComposition exclusively owns turn decoration order, transcript/checkpoint composition, and turn state-surface wiring while shipping main.rs consumes those entrypoints without parallel construction.",
          "CI fails if shipping Host reintroduces a second Runner/checkpoint/state assembly path.",
          "mobile/ios/FabushiTests/RunnerParityTests.swift",
          "Add native behavior/composition evidence for the single iOS Host/Runner owner; do not copy Desktop source-string assertions as implementation.",
          f"Expanded at Desktop PR #20 {NEW}; mapped only. Existing iOS tests do not yet prove checkpoint/state/Runner composition ownership.")
        assert len(v["rows"])==957
    dump(p,v)

mi["authority"]["commit"]=NEW; dump("manifests/desktop-pr20-reference-index.json",mi)
li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)

p=Path("scripts/check-desktop-pr20-ios-architecture.py"); t=p.read_text()
assert f'EXPECTED_DESKTOP_COMMIT = "{OLD}"' in t
p.write_text(t.replace(f'EXPECTED_DESKTOP_COMMIT = "{OLD}"',f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))

p=Path("MIGRATION_SOURCE.md"); t=p.read_text()
t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1
p.write_text(t)

p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); t=p.read_text()
old=f"- pinned source commit for this baseline: \`{OLD}\`".replace("\\",""); assert old in t
t=t.replace(old,f"- pinned source commit for this baseline: \`{NEW}\`".replace("\\",""),1)
assert "### 1.19 Exact-HEAD rebaseline" not in t
section="""### 1.19 Exact-HEAD rebaseline: 2026-10-03 / `854d4bffde64dee2d7f12ba093207381ef369af4`

Desktop PR #20 advanced two production-source commits from `c96b56c47c6b2a478370839888124d1703aac518` to `854d4bffde64dee2d7f12ba093207381ef369af4` with no selected path additions/removals, so the authoritative selected inventory remains exactly **7,927** blobs and `source-host` remains 957 rows. Three selected Host paths changed: `source/host/app/src/main.rs`, `source/host/src/host_runner_composition.rs`, and `source/host/tests/host_runner_composition_production_wiring_contract.rs`.

The production ownership introduced at `c96b56c` is expanded. `HostRunnerComposition` now owns not only the ordered Runner decorator stack but also production transcript/checkpoint sink construction and turn state-surface construction. It opens the canonical Agent store/blob store, constructs the production transcript mirror and generated-occurrence codec, builds the `ProductionAgentStateCheckpointSink`, and constructs memory-backed Agent state plus optional multitask todo state. Shipping `main.rs` consumes these composition entrypoints and is contractually forbidden from rebuilding the same state/checkpoint/Runner graph in parallel.

The iOS adaptation must preserve this single-owner rule rather than copy Desktop process details. SwiftUI and Mahayana Coordinator may transport lifecycle/request inputs, but canonical production checkpoint/state/Runner composition must remain in one Host/Runtime owner. Current iOS architecture has the correct high-level Coordinator -> Host boundary, yet the newly centralized checkpoint/state/Runner composition has not been proved on the shipping path. All three changed rows remain `mapped` pending focused production evidence and same-iOS-HEAD CI; no previous `implemented`/`verified` result is inherited.

"""
assert "## 2. Product goal" in t
p.write_text(t.replace("## 2. Product goal",section+"## 2. Product goal",1))

mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==NEW and mi["fileCount"]==7927
assert li["source"]["commit"]==NEW and li["rowCount"]==7927
for g in mi["groups"]: assert json.loads(Path(g["path"]).read_text())["sourceCommit"]==NEW
for c in li["chunks"]: assert json.loads(Path(c["path"]).read_text())["sourceCommit"]==NEW
print("rebaseline-854d4bf-static-integrity: ok")
