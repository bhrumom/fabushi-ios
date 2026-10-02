#!/usr/bin/env python3
import json,re
from pathlib import Path
OLD="29b10d13f1158c6b070ccabc1cf655317adcf184"
NEW="1e79bdad87022dcb394b9d4ecaef9508baf7497d"
P="source/host/tests/host_runner_composition_production_wiring_contract.rs"
SHA="b9357bf42ba11335a3546b450a7fe9145cfa6201"; SIZE=10716
NOTE=" Revalidated at Desktop PR #20 1e79bdad87022dcb394b9d4ecaef9508baf7497d: focused production ownership contract now explicitly binds group-member identity into HostRunnerComposition state-surface composition and enforces shutdown ordering RunnerRegistry cancel before composition-owned surface disposal. Shipping source is unchanged; iOS remains mapped until native production behavior and exact-head evidence prove both responsibilities."

def dump(p,v): Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+"\n")
mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==OLD and mi["fileCount"]==7927
assert li["source"]["commit"]==OLD and li["rowCount"]==7927
for g in mi["groups"]:
    p=Path(g["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD
    v["sourceCommit"]=NEW
    if g["name"]=="source-host":
        row=next(x for x in v["files"] if x["path"]==P)
        row["blobSha"]=SHA; row["size"]=SIZE
    dump(p,v)
for c in li["chunks"]:
    p=Path(c["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD
    v["sourceCommit"]=NEW
    if c["name"]=="source-host":
        row=next(x for x in v["rows"] if x["desktop_path"]==P)
        row["desktop_blob_sha"]=SHA
        row["implementation_status"]="mapped"
        row["notes"]=(row.get("notes") or "")+NOTE
    dump(p,v)
mi["authority"]["commit"]=NEW; dump("manifests/desktop-pr20-reference-index.json",mi)
li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)
p=Path("scripts/check-desktop-pr20-ios-architecture.py"); t=p.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in t; p.write_text(t.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))
p=Path("MIGRATION_SOURCE.md"); t=p.read_text(); t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1; p.write_text(t)
p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); t=p.read_text(); old=f"- pinned source commit for this baseline: `{OLD}`"; assert old in t; t=t.replace(old,f"- pinned source commit for this baseline: `{NEW}`",1)
assert "### 1.27 Exact-HEAD rebaseline" not in t
section="""### 1.27 Exact-HEAD rebaseline: 2026-10-03 / `1e79bdad87022dcb394b9d4ecaef9508baf7497d`

Desktop PR #20 advanced one contract-only commit from `29b10d13f1158c6b070ccabc1cf655317adcf184` to `1e79bdad87022dcb394b9d4ecaef9508baf7497d`. The selected inventory remains exactly **7,927** blobs and only `source/host/tests/host_runner_composition_production_wiring_contract.rs` changed.

The strengthened contract makes two current responsibilities explicit without changing shipping Desktop source. First, `is_group_member_turn` must be supplied to the canonical `HostRunnerComposition.compose_turn_state_surfaces` path so group-member turns retain generated-Agent execution while omitting private Agent state. Second, shutdown ownership is ordered: the canonical Runner registry interrupts active turns first, then `HostRunnerComposition` disposes only the permission/projection surfaces it owns; composition must not duplicate Runner cancellation ownership.

The affected iOS row remains `mapped`. Existing single-NativeEngine ownership evidence is insufficient until the native mobile shipping path proves group-aware private-state omission and Rust Host-owned shutdown settlement with the same separation of responsibilities.

"""
marker="## 2. Product goal"; assert marker in t; p.write_text(t.replace(marker,section+marker,1))
