#!/usr/bin/env python3
import json
import re
from pathlib import Path

OLD = "9e0b1701d405ebd0b2707620c01781103562b39b"
NEW = "9467112079551dc9ff64d40ba2c0bed0f62a114a"
CHANGED = {
    "source/host/tests/auto_review_expire_sweep_production_wiring_contract.rs": ("f2f214b43e300b6a1456f3578e9871342487d826", 2249),
    "source/host/tests/host_production_extensions_contract.rs": ("cfdd72dfc5b4e2960c2da5a443826937f922512b", 21221),
}
RESP = {
    "source/host/tests/auto_review_expire_sweep_production_wiring_contract.rs": "Focused shipping contract proves startup AutoReview expire-sweep failure reporting is installed by the centralized ProductionHostExtensions owner, consumed by shipping Host, and emitted only through the unique Host structured-log owner rather than Coordinator or Electron parallel telemetry owners.",
    "source/host/tests/host_production_extensions_contract.rs": "Focused composition contract now additionally requires the shipping production registry to cover all 35 frozen Host extension slots exactly once with no no-op placeholder, while retaining unique centralized lifecycle ownership for Transcript, AutoReview, Session, CrossUserSharing, Notifications, TurnExecution, MCP, Automations and other frozen owners.",
}
EFFECT = {
    "source/host/tests/auto_review_expire_sweep_production_wiring_contract.rs": "AutoReview startup cleanup failures have one production composition owner and one structured-log owner; duplicate lifecycle or telemetry owners cannot silently report or miss stale approval cleanup failures.",
    "source/host/tests/host_production_extensions_contract.rs": "Every frozen Host extension slot is represented exactly once by a real shipping production owner, preventing missing/no-op slots and duplicate lifecycle state across Host composition.",
}

def dump(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")

mi = json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
assert mi["authority"]["commit"] == OLD and mi["fileCount"] == 7926
for g in mi["groups"]:
    p=Path(g["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"] == OLD; v["sourceCommit"]=NEW
    if g["name"]=="source-host":
        rows={x["path"]:x for x in v["files"]}
        for path,(sha,size) in CHANGED.items():
            rows[path]["blobSha"]=sha; rows[path]["size"]=size
    dump(p,v)
mi["authority"]["commit"]=NEW
dump("manifests/desktop-pr20-reference-index.json",mi)

li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert li["source"]["commit"] == OLD and li["rowCount"] == 7926
for c in li["chunks"]:
    p=Path(c["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"] == OLD; v["sourceCommit"]=NEW
    if c["name"]=="source-host":
        rows={x["desktop_path"]:x for x in v["rows"]}
        for path,(sha,_) in CHANGED.items():
            row=rows[path]
            row["desktop_blob_sha"]=sha
            row["desktop_responsibility"]=RESP[path]
            row["desktop_visible_effect"]=EFFECT[path]
            row["implementation_status"]="mapped"
            row["production_evidence"]=""
            row["test_evidence"]=""
            row["notes"]=((row.get("notes") or "").rstrip()+" Revalidated against Desktop PR #20 "+NEW+". The 9e0b170->9467112 contract change invalidates older current-head status/evidence for this exact row; it remains mapped until iOS shipping ownership and same-head acceptance prove the tightened responsibility.").strip()
    dump(p,v)
li["source"]["commit"]=NEW
dump("docs/parity/desktop-pr20-index.json",li)

checker=Path("scripts/check-desktop-pr20-ios-architecture.py")
t=checker.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in t
checker.write_text(t.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))

m=Path("MIGRATION_SOURCE.md"); t=m.read_text()
t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1
m.write_text(t)

s=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); t=s.read_text()
old=f"- pinned source commit for this baseline: `{OLD}`".replace("\\","")
assert old in t
t=t.replace(old,f"- pinned source commit for this baseline: `{NEW}`".replace("\\",""),1)
section="""### 1.16 Exact-HEAD rebaseline: 2026-10-03 / 9467112079551dc9ff64d40ba2c0bed0f62a114a

Desktop PR #20 advanced two commits from `9e0b1701d405ebd0b2707620c01781103562b39b` to `9467112079551dc9ff64d40ba2c0bed0f62a114a`. The selected `frontend/** + source/**` inventory remains exactly 7,926 paths; only two existing Host focused-contract files changed. No production source owner moved again, but the acceptance contract tightened, so both affected ledger rows are rebound to the current blob identity and reset to `mapped` rather than inheriting the preceding current-head judgment.

The first contract now proves that AutoReview startup stale-approval sweeping is composed through `ProductionHostExtensions.start_auto_review`, with the expire-sweep failure sink installed before the startup sweep and failures reported only through the Host structured-log owner. Shipping Host must consume this centralized AutoReview owner and must not construct a second extension; Coordinator and Electron telemetry remain non-owners.

The second contract strengthens the centralized production composition invariant: `CURRENT_SHIPPING_PRODUCTION_EXTENSION_IDS` must cover the exact 35 frozen Host extension slots exactly once, and no `NoopProductionExtension`/no-op placeholder may satisfy a frozen slot. The already-audited iOS architecture still has one Coordinator->Host boundary and a single Rust `FeatureHostController` rather than SwiftUI parallel Host owners, but this evidence-only upstream tightening does not promote iOS parity. The two changed rows remain mapped pending native shipping-path proof and same-iOS-HEAD acceptance.

"""
assert "## 2. Product goal" in t
s.write_text(t.replace("## 2. Product goal",section+"## 2. Product goal",1))

# integrity
mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==NEW and mi["fileCount"]==7926
assert li["source"]["commit"]==NEW and li["rowCount"]==7926
mr={}; lr={}
for g in mi["groups"]:
    v=json.loads(Path(g["path"]).read_text()); assert v["sourceCommit"]==NEW
    mr.update({x["path"]:x for x in v["files"]})
for c in li["chunks"]:
    v=json.loads(Path(c["path"]).read_text()); assert v["sourceCommit"]==NEW
    lr.update({x["desktop_path"]:x for x in v["rows"]})
assert len(mr)==7926 and len(lr)==7926
for path,(sha,size) in CHANGED.items():
    assert mr[path]["blobSha"]==sha and mr[path]["size"]==size
    assert lr[path]["desktop_blob_sha"]==sha
    assert lr[path]["implementation_status"]=="mapped"
    assert lr[path]["desktop_visible_effect"]!="pending-review"
print("rebaseline-9467112-static-integrity: ok")
