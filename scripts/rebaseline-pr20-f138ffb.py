#!/usr/bin/env python3
import json,re
from pathlib import Path
OLD="39e1eeaee2d861b18a5db5864dac4f7fc049530b"
NEW="f138ffbcff2f6e541899a3f17dc95d25b06b1bcd"
CHANGED={
"source/host/src/extensions/mcp/production_box_state.rs":("f0b771f445446c033f7dbcaef9e6bf77b141a19f",5894),
"source/host/src/ports/mcp_state_executor.rs":("ee2e306419d868859146959fe2a51c67f9ab69dc",9399),
"source/host/tests/mcp_state_executor_contract.rs":("66c3e94de2b6ac9252746a219855e544a5556b4b",3076),
}
DETAIL={
"source/host/src/extensions/mcp/production_box_state.rs":(
"Shipping Box MCP state adapter delegates canonical agent.v1 state argument/result protobuf ownership to the Host MCP state executor port and only projects decoded server status into Box state.",
"One canonical MCP state wire schema feeds Box status; the Box extension cannot drift into a second protobuf/tool-schema implementation.",
"ios-adapted","source/packages/mahayana-rs/mahayana-host/src/lib.rs","Rust",
"Keep iOS Box/native MCP projection behind the canonical Host MCP state port; no Swift/UI-owned duplicate wire schema."
),
"source/host/src/ports/mcp_state_executor.rs":(
"Canonical Host MCP state executor owns agent.v1 McpStateExecArgs/McpStateExecResult protobuf encoding/decoding, tool schema projection, provider grouping, state execution, and error/rejected normalization.",
"MCP discovery/state consumers receive one schema-accurate provider/tool projection with stable field numbers and normalized failures.",
"ios-adapted","source/packages/mahayana-rs/mahayana-host/src/lib.rs","Rust",
"Port canonical MCP state execution/wire ownership into the iOS-owned Rust Host and reuse it from all native state projections."
),
"source/host/tests/mcp_state_executor_contract.rs":(
"Focused behavior contract proves MCP state provider grouping/tool projection and canonical agent.v1 wire round-trip preserve the exact semantic state.",
"CI rejects duplicate or lossy MCP state wire implementations and provider/tool projection drift.",
"ios-adapted","source/packages/mahayana-rs/mahayana-host/src/lib.rs","Rust",
"Add behavior-level Rust contracts around the iOS Host MCP state owner; do not substitute grep/string assertions."
),
}
NOTE=" Revalidated at Desktop PR #20 f138ffbcff2f6e541899a3f17dc95d25b06b1bcd: canonical agent.v1 MCP state protobuf ownership moved into mcp_state_executor; ProductionBoxMcpStateLoader now consumes that port instead of maintaining a duplicate wire schema. iOS row is mapped only pending shipping-owner audit and exact-head behavior evidence."
def dump(p,v): Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+"\n")
mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==OLD and mi["fileCount"]==7927
assert li["source"]["commit"]==OLD and li["rowCount"]==7927
for g in mi["groups"]:
 p=Path(g["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD; v["sourceCommit"]=NEW
 if g["name"]=="source-host":
  for row in v["files"]:
   if row["path"] in CHANGED: row["blobSha"],row["size"]=CHANGED[row["path"]]
 dump(p,v)
for c in li["chunks"]:
 p=Path(c["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD; v["sourceCommit"]=NEW
 if c["name"]=="source-host":
  touched=0
  for row in v["rows"]:
   if row["desktop_path"] in CHANGED:
    row["desktop_blob_sha"]=CHANGED[row["desktop_path"]][0]
    resp,effect,disp,target,lang,delta=DETAIL[row["desktop_path"]]
    row["desktop_responsibility"]=resp; row["desktop_visible_effect"]=effect
    row["ios_disposition"]=disp; row["ios_target_path"]=target; row["ios_language"]=lang; row["ios_platform_delta"]=delta
    row["implementation_status"]="mapped"; row["notes"]=(row.get("notes") or "")+NOTE
    touched+=1
  assert touched==3
 dump(p,v)
mi["authority"]["commit"]=NEW; dump("manifests/desktop-pr20-reference-index.json",mi)
li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)
p=Path("scripts/check-desktop-pr20-ios-architecture.py"); t=p.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in t; p.write_text(t.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))
p=Path("MIGRATION_SOURCE.md"); t=p.read_text(); t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1; p.write_text(t)
p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); t=p.read_text(); old=f"- pinned source commit for this baseline: `{OLD}`"; assert old in t; t=t.replace(old,f"- pinned source commit for this baseline: `{NEW}`",1)
assert "### 1.29 Exact-HEAD rebaseline" not in t
section="""### 1.29 Exact-HEAD rebaseline: 2026-10-03 / `f138ffbcff2f6e541899a3f17dc95d25b06b1bcd`

Desktop PR #20 advanced two production commits from `39e1eeaee2d861b18a5db5864dac4f7fc049530b` to `f138ffbcff2f6e541899a3f17dc95d25b06b1bcd`. The selected inventory remains exactly **7,927** blobs. Three `source-host` blobs changed: `production_box_state.rs`, `mcp_state_executor.rs`, and its focused contract.

The normative change removes a duplicate MCP protobuf owner. `mcp_state_executor` now owns the canonical `agent.v1` MCP state argument/result wire contract, exact field/schema projection, provider grouping, tool definitions, and error/rejected normalization. `ProductionBoxMcpStateLoader` is an adapter over that port and may not maintain a second protobuf/tool schema. The focused contract proves semantic state survives the canonical wire round trip.

These rows were previously unreviewed. They are now reviewed and `mapped` only; no Desktop implementation status or old iOS evidence is inherited. iOS must audit its shipping MCP state owner and either reuse one Rust Host port or close any parallel schema before promotion.

"""
marker="## 2. Product goal"; assert marker in t; p.write_text(t.replace(marker,section+marker,1))
