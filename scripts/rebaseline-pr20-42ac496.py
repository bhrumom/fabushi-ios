#!/usr/bin/env python3
import json,re
from pathlib import Path
OLD="ea29726d33da17bae8fbe5e1c145ba3c828081ee"
NEW="42ac4967196e33e991e6c4d9e794a7c221ed0c63"
AFFECTED={
"source/host/src/ports/mcp_state_executor.rs",
"source/host/src/extensions/mcp/production_box_state.rs",
"source/host/src/extensions/mcp/box_mcp_exec.rs",
"source/host/tests/mcp_state_executor_contract.rs",
}
NOTE=" Revalidated at Desktop PR #20 42ac4967196e33e991e6c4d9e794a7c221ed0c63: Desktop architecture manifest now marks the canonical MCP state executor implemented with shipping Box consumers and exact-head production evidence. No selected source blob changed. Desktop status is not inherited by iOS; affected iOS rows remain mapped until one iOS-owned Rust shipping state owner preserves provider/tool/status/status-detail semantics and exact-head CI proves it."
def dump(p,v): Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+"\n")
mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==OLD and mi["fileCount"]==7927
assert li["source"]["commit"]==OLD and li["rowCount"]==7927
for g in mi["groups"]:
 p=Path(g["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD
 v["sourceCommit"]=NEW; dump(p,v)
for c in li["chunks"]:
 p=Path(c["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD
 v["sourceCommit"]=NEW
 if c["name"]=="source-host":
  for row in v["rows"]:
   if row["desktop_path"] in AFFECTED:
    if row.get("implementation_status")=="implemented":
     row["implementation_status"]="mapped"
    row["notes"]=(row.get("notes") or "")+NOTE
 dump(p,v)
mi["authority"]["commit"]=NEW; dump("manifests/desktop-pr20-reference-index.json",mi)
li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)
p=Path("scripts/check-desktop-pr20-ios-architecture.py"); t=p.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in t; p.write_text(t.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))
p=Path("MIGRATION_SOURCE.md"); t=p.read_text(); t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1; p.write_text(t)
p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); t=p.read_text(); old=f"- pinned source commit for this baseline: `{OLD}`"; assert old in t; t=t.replace(old,f"- pinned source commit for this baseline: `{NEW}`",1)
assert "### 1.31 Exact-HEAD rebaseline" not in t
section="""### 1.31 Exact-HEAD rebaseline: 2026-10-03 / `42ac4967196e33e991e6c4d9e794a7c221ed0c63`

Desktop PR #20 advanced one architecture-manifest-only commit from `ea29726d33da17bae8fbe5e1c145ba3c828081ee` to `42ac4967196e33e991e6c4d9e794a7c221ed0c63`. The selected `frontend/** + source/**` inventory remains exactly **7,927** blobs and every selected blob SHA is unchanged.

The Desktop manifest now records the MCP state executor as implemented: one Rust Host owner controls provider grouping, tool metadata/schema, canonical state/result semantics, status and status-detail preservation, and the shipping Box adapters consume that owner rather than maintaining a parallel state decoder.

This changes Desktop acceptance status only. iOS does not inherit `implemented`. Its current production `RuntimeCommand::McpServers -> NativeAgentBackend::list_mcp_servers` path is the native state surface, but it currently projects only server name/plugin/status/runtime and drops the already-owned MCP tool schemas. The iOS closure must therefore enrich that existing Rust owner and keep `FeatureHostController::McpList` as a projection consumer; it must not introduce an unused Desktop-style protobuf layer merely for mechanism symmetry. If a remote Runner/Box wire is later required, serialization must adapt the same canonical iOS state owner.

"""
marker="## 2. Product goal"; assert marker in t; p.write_text(t.replace(marker,section+marker,1))
