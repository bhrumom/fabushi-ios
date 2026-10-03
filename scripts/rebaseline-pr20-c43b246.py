#!/usr/bin/env python3
import json,re
from pathlib import Path
OLD="0e94c970c63eaadea8b1ea605a807a487a0519e2"
NEW="c43b246c8cd4b85359acba7850dd64d5a2fececc"
CHANGED={
"source/host/src/runner/turn_agent_composition.rs":("abb81bd076d24d784af0d4eb140fec9e37e33ed4",20218),
"source/host/tests/runner_production_bridge_contract.rs":("73b5cc168d29edad000546403268c18197399495",10650),
}
MCP="source/host/src/ports/mcp_state_executor.rs"
NOTE=" Revalidated at Desktop PR #20 c43b246c8cd4b85359acba7850dd64d5a2fececc: canonical MCP state execution is now bound into each shipping TurnAgentComposition from that turn's existing RoutedToolBridge; Desktop itself reset this responsibility to existing-needs-parity pending exact-head gates. iOS must not inherit prior implemented status and must prove its per-turn/runtime consumer uses the same canonical MCP state owner without a second discovery registry."

def dump(p,v): Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+"\n")
mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==OLD and mi["fileCount"]==7927
assert li["source"]["commit"]==OLD and li["rowCount"]==7927

for g in mi["groups"]:
 p=Path(g["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD
 v["sourceCommit"]=NEW
 if g["name"]=="source-host":
  for row in v["files"]:
   if row["path"] in CHANGED:
    row["blobSha"],row["size"]=CHANGED[row["path"]]
 dump(p,v)

for c in li["chunks"]:
 p=Path(c["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD
 v["sourceCommit"]=NEW
 if c["name"]=="source-host":
  for row in v["rows"]:
   if row["desktop_path"] in CHANGED:
    row["desktop_blob_sha"]=CHANGED[row["desktop_path"]][0]
    row["implementation_status"]="mapped"
    row["notes"]=(row.get("notes") or "")+NOTE
    if row["desktop_path"].endswith("turn_agent_composition.rs"):
     row["desktop_responsibility"]="Canonical per-turn Runner composition owns provider checkpoint/recovery surfaces and now executes canonical MCP state from the exact RoutedToolBridge already owned by that turn, without creating a second MCP discovery owner."
     row["desktop_visible_effect"]="Each generated turn sees one provider/tool state projection with stable provider grouping and full tool schema, while checkpoint/recovery state remains scoped to the current run."
     row["ios_target_path"]="source/packages/mahayana-rs/mahayana-native-agent/src/lib.rs"
     row["ios_platform_delta"]="Use the iOS-owned NativeAgent/Runtime turn path as the canonical native MCP state owner and feed all per-turn/native state consumers from it; do not add a parallel Swift or Runner discovery registry."
    else:
     row["desktop_responsibility"]="Focused production bridge contract executes the shipping TurnAgentComposition MCP-state path from its existing RoutedToolBridge and proves first-seen provider grouping plus exact tool metadata/schema survive the canonical projection."
     row["desktop_visible_effect"]="CI rejects a test-only MCP state helper or a second discovery owner that is not reachable through the production turn composition."
     row["ios_disposition"]="ios-adapted"
     row["ios_target_path"]="source/packages/mahayana-rs/mahayana-native-agent/src/lib.rs"
     row["ios_language"]="Rust"
     row["ios_platform_delta"]="Exercise the production NativeAgent/Runtime MCP state owner and its real consumer boundary; helper-only projection tests are insufficient."
   elif row["desktop_path"]==MCP:
    row["implementation_status"]="mapped"
    row["notes"]=(row.get("notes") or "")+NOTE
 dump(p,v)

mi["authority"]["commit"]=NEW; dump("manifests/desktop-pr20-reference-index.json",mi)
li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)

p=Path("scripts/check-desktop-pr20-ios-architecture.py"); t=p.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in t; p.write_text(t.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))
p=Path("MIGRATION_SOURCE.md"); t=p.read_text(); t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1; p.write_text(t)
p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); t=p.read_text(); old=f"- pinned source commit for this baseline: `{OLD}`"; assert old in t; t=t.replace(old,f"- pinned source commit for this baseline: `{NEW}`",1)
assert "### 1.34 Exact-HEAD rebaseline" not in t
section="""### 1.34 Exact-HEAD rebaseline: 2026-10-03 / `c43b246c8cd4b85359acba7850dd64d5a2fececc`

Desktop PR #20 advanced one production commit from `0e94c970c63eaadea8b1ea605a807a487a0519e2` to `c43b246c8cd4b85359acba7850dd64d5a2fececc`. The selected inventory remains exactly **7,927** blobs. Two `source-host` blobs changed: `runner/turn_agent_composition.rs` and `tests/runner_production_bridge_contract.rs`.

The new responsibility closes a production-boundary gap rather than changing the MCP state schema itself. `TurnAgentComposition::execute_mcp_state()` now adapts the exact `RoutedToolBridge` already owned by that generated turn into the canonical `mcp_state_executor`. This preserves first-seen provider grouping and exact tool metadata/schema without constructing a second MCP discovery owner. The focused production-bridge contract executes that shipping composition path. Desktop deliberately reset the manifest responsibility from `implemented` to `existing-needs-parity` until this new wiring receives its own exact-head Host/Runner and Electron evidence.

Accordingly, iOS does not inherit either the prior Desktop status or the prior iOS `implemented` status on the changed turn-composition row. The iOS native equivalent is the existing `RuntimeCommand::McpServers -> NativeAgentBackend::list_mcp_servers` path backed by the generation-safe `NativeMcpServerStateStore`; all native/per-turn consumers must use that one owner. Exact-head behavior evidence must prove this production consumer boundary, including loading/connected/error status, status detail, tool schema, stale-generation rejection, reset fencing, and absence of a parallel Swift/Runner discovery registry.

"""
marker="## 2. Product goal"; assert marker in t; p.write_text(t.replace(marker,section+marker,1))
