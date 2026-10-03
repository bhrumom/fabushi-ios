#!/usr/bin/env python3
import json,re
from pathlib import Path
OLD="f138ffbcff2f6e541899a3f17dc95d25b06b1bcd"
NEW="ea29726d33da17bae8fbe5e1c145ba3c828081ee"
CHANGED={
"source/host/src/extensions/mcp/box_mcp_exec.rs":("d691fc1a059588d33f3ceaccff5e35303c184008",3948),
"source/host/src/extensions/mcp/production_box_state.rs":("ed10c6b76df61a0f3fdf5aa1f60844ace5f172b2",6158),
"source/host/src/ports/mcp_state_executor.rs":("a10ca73079bfbb8bee93f8b82211285ded01c4c1",9539),
}
NOTE=" Revalidated at Desktop PR #20 ea29726d33da17bae8fbe5e1c145ba3c828081ee: canonical MCP state now round-trips server error_message/status detail and Box projections preserve non-empty status_detail. iOS remains mapped until its Rust Host has one canonical MCP state wire owner and behavior evidence."
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
    if row["desktop_path"].endswith("box_mcp_exec.rs"):
     row["desktop_responsibility"]="Shipping Host Box MCP execution adapter maps canonical MCP state servers/tools into Box-visible server state without re-owning the wire schema, including status and non-empty status detail."
     row["desktop_visible_effect"]="Remote/Box MCP state shows the canonical server/tool projection and preserves actionable server status detail."
     row["ios_disposition"]="ios-adapted"
     row["ios_target_path"]="source/packages/mahayana-rs/mahayana-host/src/lib.rs"
     row["ios_language"]="Rust"
     row["ios_platform_delta"]="Use the iOS-owned Rust Host/remote Runner adapter to project canonical MCP state into native/remote capability state; do not duplicate protobuf ownership in Swift."
    row["implementation_status"]="mapped"
    row["notes"]=(row.get("notes") or "")+NOTE
    touched+=1
  assert touched==3
 dump(p,v)
mi["authority"]["commit"]=NEW; dump("manifests/desktop-pr20-reference-index.json",mi)
li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)
p=Path("scripts/check-desktop-pr20-ios-architecture.py"); t=p.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in t; p.write_text(t.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))
p=Path("MIGRATION_SOURCE.md"); t=p.read_text(); t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1; p.write_text(t)
p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); t=p.read_text(); old=f"- pinned source commit for this baseline: `{OLD}`"; assert old in t; t=t.replace(old,f"- pinned source commit for this baseline: `{NEW}`",1)
assert "### 1.30 Exact-HEAD rebaseline" not in t
section="""### 1.30 Exact-HEAD rebaseline: 2026-10-03 / `ea29726d33da17bae8fbe5e1c145ba3c828081ee`

Desktop PR #20 advanced two production fixes from `f138ffbcff2f6e541899a3f17dc95d25b06b1bcd` to `ea29726d33da17bae8fbe5e1c145ba3c828081ee`. The selected inventory remains exactly **7,927** blobs. Three `source-host` blobs changed: `box_mcp_exec.rs`, `production_box_state.rs`, and `mcp_state_executor.rs`.

The canonical MCP state contract now preserves server `error_message` through encode/decode and both Box adapters project a non-empty value as `status_detail`. This is part of the same single-owner rule introduced at `f138ffbc…`: the Host MCP state executor owns the `agent.v1` state wire schema; Box execution/state layers consume the canonical result and may only adapt the visible projection.

The previously unreviewed `box_mcp_exec.rs` row is now reviewed and `mapped`. All three affected iOS rows remain `mapped`; no Desktop implementation status or historical iOS evidence is inherited.

"""
marker="## 2. Product goal"; assert marker in t; p.write_text(t.replace(marker,section+marker,1))
