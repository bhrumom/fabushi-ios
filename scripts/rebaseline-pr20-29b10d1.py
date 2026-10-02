#!/usr/bin/env python3
import json,re
from pathlib import Path
OLD="cf0012e6bb5ddcd1669c747994af68a5055bf05d"
NEW="29b10d13f1158c6b070ccabc1cf655317adcf184"
CHANGED={
"source/host/app/src/main.rs":("28fd81624b0ca32c492ea4cb748dc21773bce808",523101),
"source/host/src/host_runner_composition.rs":("182c12cbf182f2c7ee84199aae1a7a9e39d9ba6b",16653),
"source/host/tests/host_runner_composition_local_permission_contract.rs":("65341e5c9520f55ddeae6fda9182c25be3b21484",4959),
}
NOTE=" Revalidated at Desktop PR #20 29b10d13f1158c6b070ccabc1cf655317adcf184: Host shutdown now explicitly settles HostRunnerComposition-owned live local-permission subscriptions through dispose() after Runner cancellation. Current iOS has no same-owner shutdown-settlement evidence, so this row remains mapped pending shipping implementation and exact-head CI."
def dump(path,v): Path(path).write_text(json.dumps(v,ensure_ascii=False,indent=2)+"\n")
mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==OLD and mi["fileCount"]==7927
assert li["source"]["commit"]==OLD and li["rowCount"]==7927
for g in mi["groups"]:
    p=Path(g["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD
    v["sourceCommit"]=NEW
    if g["name"]=="source-host":
        for row in v["files"]:
            if row["path"] in CHANGED: row["blobSha"],row["size"]=CHANGED[row["path"]]
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
                if row["desktop_path"].endswith("host_runner_composition_local_permission_contract.rs"):
                    row["desktop_responsibility"]="Focused behavior contract proving HostRunnerComposition owns live local-tool permission projection surfaces and deterministically disposes every subscription at Host shutdown."
                    row["desktop_visible_effect"]="No stale local-permission ask surface survives Host shutdown/restart, and permission projection remains owned by the canonical Host/Runner composition."
                    row["ios_disposition"]="ios-adapted"
                    row["ios_target_path"]="source/packages/mahayana-rs/mahayana-host/src/lib.rs"
                    row["ios_language"]="Rust"
                    row["ios_platform_delta"]="Use iOS Host-owned permission/approval subscription cleanup at lifecycle shutdown; SwiftUI and Coordinator must not retain permission truth."
    dump(p,v)
mi["authority"]["commit"]=NEW; dump("manifests/desktop-pr20-reference-index.json",mi)
li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)
p=Path("scripts/check-desktop-pr20-ios-architecture.py"); t=p.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in t; p.write_text(t.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))
p=Path("MIGRATION_SOURCE.md"); t=p.read_text(); t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1; p.write_text(t)
p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); t=p.read_text(); old=f"- pinned source commit for this baseline: `{OLD}`"; assert old in t; t=t.replace(old,f"- pinned source commit for this baseline: `{NEW}`",1)
assert "### 1.26 Exact-HEAD rebaseline" not in t
section="""### 1.26 Exact-HEAD rebaseline: 2026-10-03 / `29b10d13f1158c6b070ccabc1cf655317adcf184`

Desktop PR #20 advanced two commits from `cf0012e6bb5ddcd1669c747994af68a5055bf05d` to `29b10d13f1158c6b070ccabc1cf655317adcf184`. The selected inventory remains exactly **7,927** blobs. Three `source-host` blobs changed: shipping `main.rs`, `host_runner_composition.rs`, and the local-permission focused contract.

The new lifecycle rule is normative: after canonical Runner cancellation begins, Host shutdown must explicitly dispose the live local-tool permission projection subscriptions owned by `HostRunnerComposition`. This prevents stale permission surfaces from surviving shutdown/restart and keeps ask/projection ownership inside the Host/Runner composition rather than UI state. iOS must provide the same product effect with a native Host-owned shutdown settlement path; SwiftUI and the Coordinator may project permission state but cannot retain or clean up the canonical subscriptions themselves.

No affected row is promoted by rebaseline. The shipping and composition rows remain `mapped`; the previously unreviewed local-permission contract is now reviewed and mapped only. Exact-head production wiring plus focused behavior evidence is required before `implemented` or `verified`.

"""
marker="## 2. Product goal"; assert marker in t; p.write_text(t.replace(marker,section+marker,1))
