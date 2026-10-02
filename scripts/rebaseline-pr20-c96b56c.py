#!/usr/bin/env python3
import json
import re
from pathlib import Path

OLD="f6d4c48d113d02ec2e223c4fcbad1e6417549424"
NEW="c96b56c47c6b2a478370839888124d1703aac518"
NEW_META={
  "source/host/app/src/main.rs": ("32ffdcfe6979a41093f455566e1e1ce9f90957f3", 525740),
  "source/host/src/host_runner_composition.rs": ("ba6c0dc01fcb259e8f9036763b2e2886451004a8", 9366),
  "source/host/tests/host_runner_composition_production_wiring_contract.rs": ("f5ff4d26b141d30802a5ea90c1aba70f9cff7520", 2058),
  "source/host/tests/sand_host_production_wiring_contract.rs": ("82146f2a2a15d197ca4a42537cdd796deac2ac3c", 11639),
}

def dump(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")

mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==OLD and mi["fileCount"]==7926
assert li["source"]["commit"]==OLD and li["rowCount"]==7926

for g in mi["groups"]:
    p=Path(g["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD
    v["sourceCommit"]=NEW
    if g["name"]=="source-host":
        by={x["path"]:x for x in v["files"]}
        for path,(sha,size) in NEW_META.items():
            if path in by:
                by[path]["blobSha"]=sha; by[path]["size"]=size
        np="source/host/tests/host_runner_composition_production_wiring_contract.rs"
        if np not in by:
            v["files"].append({"path":np,"blobSha":NEW_META[np][0],"size":NEW_META[np][1]})
        v["files"].sort(key=lambda x:x["path"])
        v["fileCount"]=len(v["files"])
        assert v["fileCount"]==957
    dump(p,v)

def reset(row, **kw):
    row.update(kw)
    row["implementation_status"]="mapped"
    row["production_evidence"]=""
    row["test_evidence"]=""

for c in li["chunks"]:
    p=Path(c["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD
    v["sourceCommit"]=NEW
    if c["name"]=="source-host":
        rows=v["rows"]; by={x["desktop_path"]:x for x in rows}
        reset(by["source/host/app/src/main.rs"],
            desktop_blob_sha=NEW_META["source/host/app/src/main.rs"][0],
            desktop_responsibility="Shipping Host supplies turn-scoped inputs and hooks to the canonical HostRunnerComposition and consumes the returned TurnAgentComposition; main.rs must not directly construct or decorate a parallel production Runner composition.",
            desktop_owner="host",
            desktop_visible_effect="Every shipping turn receives one deterministic Host-owned Runner capability/decorator stack instead of behavior drifting by call site.",
            ios_disposition="ios-adapted",
            ios_target_path="source/packages/mahayana-rs/mahayana-feature-host/src/implementation.rs",
            ios_language="Rust",
            ios_platform_delta="iOS keeps one native Host/Runner composition boundary; SwiftUI and Coordinator may provide requests or platform capabilities but cannot own a second turn-decoration path.",
            notes=f"Revalidated against Desktop PR #20 {NEW}. Desktop now delegates production turn assembly to HostRunnerComposition.compose_production_turn and forbids direct create_production_runner_composition/decorator ownership in shipping main. Current iOS has not yet proved an equivalent single native Runner-composition owner, so this broad row remains mapped pending shipping-path audit and exact-head evidence.")
        reset(by["source/host/src/host_runner_composition.rs"],
            desktop_blob_sha=NEW_META["source/host/src/host_runner_composition.rs"][0],
            desktop_responsibility="Canonical Host -> Runner production composition owner. It constructs the base production Runner composition and applies agent-management, state-writer, routine auto-review, box-shell review, Subagent, routine-post-write, and multitask hooks in one ordered entrypoint.",
            desktop_owner="host",
            desktop_visible_effect="Production turns cannot silently diverge in enabled Runner capabilities or decorator ordering across Host call sites.",
            ios_disposition="ios-adapted",
            ios_target_path="source/packages/mahayana-rs/mahayana-feature-host/src/implementation.rs",
            ios_language="Rust",
            ios_platform_delta="Preserve one native Host/Runner assembly owner rather than copying Desktop process mechanics; platform-specific capability implementations may be injected, but assembly ownership stays below SwiftUI/Coordinator.",
            notes=f"Reviewed at Desktop PR #20 {NEW}. compose_production_turn is now the sole shipping assembly owner. iOS ownership must be audited on the real production path before implemented/verified promotion.")
        reset(by["source/host/tests/sand_host_production_wiring_contract.rs"],
            desktop_blob_sha=NEW_META["source/host/tests/sand_host_production_wiring_contract.rs"][0],
            desktop_responsibility="Focused shipping Host wiring contract covering real production ownership/lifecycle relationships after Runner composition centralization.",
            desktop_owner="host",
            desktop_visible_effect="CI rejects shipping Host regressions that bypass canonical Host/Runner ownership or lifecycle wiring.",
            ios_disposition="ios-adapted",
            ios_target_path="mobile/ios/FabushiTests/RunnerParityTests.swift",
            ios_language="Swift",
            ios_platform_delta="iOS needs behavior-focused production-path assertions for its native Host/Runner owner; Desktop source-string assertions are not copied as fake parity.",
            notes=f"Changed at Desktop PR #20 {NEW}; row reset to mapped. Existing iOS RunnerParityTests cover local-vs-remote execution policy but do not yet prove the new single production composition ownership contract.")
        np="source/host/tests/host_runner_composition_production_wiring_contract.rs"
        if np not in by:
            rows.append({
              "desktop_path":np,
              "desktop_blob_sha":NEW_META[np][0],
              "desktop_responsibility":"Focused contract proving HostRunnerComposition owns production turn decoration order and shipping main.rs has exactly one Runner composition entrypoint with no parallel direct construction/decorators.",
              "desktop_owner":"host",
              "desktop_visible_effect":"A regression that reintroduces a second shipping Runner assembly path fails acceptance instead of silently changing turn capabilities.",
              "ios_disposition":"ios-adapted",
              "ios_target_path":"mobile/ios/FabushiTests/RunnerParityTests.swift",
              "ios_language":"Swift",
              "ios_platform_delta":"Prove the equivalent iOS native shipping owner by behavior/composition tests, not by mirroring Desktop source-string checks.",
              "implementation_status":"mapped",
              "production_evidence":"",
              "test_evidence":"",
              "notes":f"New selected Desktop row at PR #20 {NEW}; mapped after source review, not inherited as implemented/verified."
            })
        rows.sort(key=lambda x:x["desktop_path"])
        v["rowCount"]=len(rows)
        assert v["rowCount"]==957
    dump(p,v)

mi["authority"]["commit"]=NEW
mi["fileCount"]=7927
next(g for g in mi["groups"] if g["name"]=="source-host")["fileCount"]=957
dump("manifests/desktop-pr20-reference-index.json",mi)
li["source"]["commit"]=NEW
li["rowCount"]=7927
next(c for c in li["chunks"] if c["name"]=="source-host")["rowCount"]=957
dump("docs/parity/desktop-pr20-index.json",li)

p=Path("scripts/check-desktop-pr20-ios-architecture.py"); t=p.read_text()
old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in t
t=t.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1)
assert "EXPECTED_FILES = 7926" in t
p.write_text(t.replace("EXPECTED_FILES = 7926","EXPECTED_FILES = 7927",1))

p=Path("MIGRATION_SOURCE.md"); t=p.read_text()
t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1
p.write_text(t)

p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); t=p.read_text()
old=f"- pinned source commit for this baseline: \`{OLD}\`".replace("\\",""); assert old in t
t=t.replace(old,f"- pinned source commit for this baseline: \`{NEW}\`".replace("\\",""),1)
assert "### 1.18 Exact-HEAD rebaseline" not in t
section="""### 1.18 Exact-HEAD rebaseline: 2026-10-03 / `c96b56c47c6b2a478370839888124d1703aac518`

Desktop PR #20 advanced two production-source commits from `f6d4c48d113d02ec2e223c4fcbad1e6417549424` to `c96b56c47c6b2a478370839888124d1703aac518`. The selected `frontend/** + source/**` inventory is now **7,927** blobs rather than 7,926 because `source/host/tests/host_runner_composition_production_wiring_contract.rs` is newly selected. `source-host` therefore grows from 956 to 957 rows. The other changed selected paths are `source/host/app/src/main.rs`, `source/host/src/host_runner_composition.rs`, and `source/host/tests/sand_host_production_wiring_contract.rs`. All manifest/ledger `sourceCommit` authorities, indexes, changed blob identities, `MIGRATION_SOURCE.md`, and the strict checker are rebound to this exact HEAD before further product work.

The normative production change centralizes per-turn Runner assembly in `HostRunnerComposition.compose_production_turn(...)`. Shipping `main.rs` supplies the turn-scoped `ProductionRunnerCompositionInput` and `ProductionTurnCompositionHooks`, but the HostRunnerComposition owner alone calls `create_production_runner_composition` and applies agent-management, state-writer, routine auto-review, box-shell review, Subagent, routine-post-write, and multitask decorations in one deterministic order. A new production-wiring contract explicitly forbids shipping `main.rs` from constructing a second Runner composition or attaching those hooks itself. This is a shipping ownership rule, not merely a test refactor.

For iOS the mechanism may differ, but the responsibility does not: one canonical Host/Runner owner must assemble the production turn capability stack before execution; SwiftUI and the Coordinator may supply requests/platform capabilities but must not own a parallel Runner-decoration path. The current iOS tree already keeps SwiftUI outside canonical Runtime truth and routes production work through Mahayana Coordinator -> Host/Runtime, but current evidence does not yet prove a single native Runner-composition owner equivalent to this new Desktop contract. The four affected rows are therefore `mapped`, never inherited as implemented/verified. The next production audit must either identify one existing shipping owner and add focused behavior evidence, or consolidate any real parallel composition path before promotion.

"""
assert "## 2. Product goal" in t
p.write_text(t.replace("## 2. Product goal",section+"## 2. Product goal",1))

mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==NEW and mi["fileCount"]==7927
assert li["source"]["commit"]==NEW and li["rowCount"]==7927
mc=lc=0
for g in mi["groups"]:
    v=json.loads(Path(g["path"]).read_text()); assert v["sourceCommit"]==NEW
    mc += len(v["files"])
for c in li["chunks"]:
    v=json.loads(Path(c["path"]).read_text()); assert v["sourceCommit"]==NEW
    lc += len(v["rows"])
assert mc==7927 and lc==7927
print("rebaseline-c96b56c-static-integrity: ok")
