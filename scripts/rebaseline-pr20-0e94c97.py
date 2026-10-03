#!/usr/bin/env python3
import json,re
from pathlib import Path
OLD="42ac4967196e33e991e6c4d9e794a7c221ed0c63"
NEW="0e94c970c63eaadea8b1ea605a807a487a0519e2"
P="source/host/tests/auto_review_gate_contract.rs"
SHA="8446bb9af4bef4b6f9d456e4355428c9e05d7fe5"; SIZE=8778
NOTE=" Revalidated at Desktop PR #20 0e94c970c63eaadea8b1ea605a807a487a0519e2: focused Auto Review gate contract now binds routine/Box/Subagent review hooks to canonical HostRunnerComposition.compose_production_turn ownership rather than accepting direct builder-only wiring in app/main.rs. iOS is mapped only pending native shipping-owner audit and exact-head behavior evidence."
def dump(p,v): Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+"\n")
mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==OLD and mi["fileCount"]==7927
assert li["source"]["commit"]==OLD and li["rowCount"]==7927
for g in mi["groups"]:
 p=Path(g["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD; v["sourceCommit"]=NEW
 if g["name"]=="source-host":
  row=next(x for x in v["files"] if x["path"]==P); row["blobSha"]=SHA; row["size"]=SIZE
 dump(p,v)
for c in li["chunks"]:
 p=Path(c["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD; v["sourceCommit"]=NEW
 if c["name"]=="source-host":
  row=next(x for x in v["rows"] if x["desktop_path"]==P)
  row["desktop_blob_sha"]=SHA
  row["desktop_responsibility"]="Focused production ownership contract proving the shared Auto Review gate and routine/Box/Subagent review callbacks enter each generated turn through canonical HostRunnerComposition.compose_production_turn rather than a parallel Host builder path."
  row["desktop_visible_effect"]="All generated turn side effects share one review gate/approval identity surface; canonical Runner composition owns routine, Box shell, external shell, cloud-agent and Subagent review decoration."
  row["ios_disposition"]="ios-adapted"
  row["ios_target_path"]="source/packages/mahayana-rs/mahayana-host/src/lib.rs"
  row["ios_language"]="Rust"
  row["ios_platform_delta"]="Keep Auto Review/approval hooks in the iOS-owned Rust Host/Runner composition; SwiftUI/Coordinator may request or project review state but may not decorate execution independently."
  row["implementation_status"]="mapped"
  row["notes"]=(row.get("notes") or "")+NOTE
 dump(p,v)
mi["authority"]["commit"]=NEW; dump("manifests/desktop-pr20-reference-index.json",mi)
li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)
p=Path("scripts/check-desktop-pr20-ios-architecture.py"); t=p.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in t; p.write_text(t.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))
p=Path("MIGRATION_SOURCE.md"); t=p.read_text(); t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1; p.write_text(t)
p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); t=p.read_text(); old=f"- pinned source commit for this baseline: `{OLD}`"; assert old in t; t=t.replace(old,f"- pinned source commit for this baseline: `{NEW}`",1)
assert "### 1.33 Exact-HEAD rebaseline" not in t
section="""### 1.33 Exact-HEAD rebaseline: 2026-10-03 / `0e94c970c63eaadea8b1ea605a807a487a0519e2`

Desktop PR #20 advanced one focused-contract commit from `42ac4967196e33e991e6c4d9e794a7c221ed0c63` to `0e94c970c63eaadea8b1ea605a807a487a0519e2`. The selected inventory remains exactly **7,927** blobs. Only `source/host/tests/auto_review_gate_contract.rs` changed.

The strengthened contract makes Auto Review ownership explicit: shipping `main.rs` supplies live review dependencies into `worker_host_runner_composition.compose_production_turn(...)`, and `HostRunnerComposition` is the canonical owner that decorates routine Auto Review, Box shell review, and Subagent task review on the generated turn. A second direct Host builder path is not acceptable.

The iOS row was previously unreviewed. It is now reviewed and `mapped` only; no Desktop implementation/evidence is inherited. iOS must audit its Rust Host/Runner review composition and prove that SwiftUI/Coordinator do not own execution review decoration before promotion.

"""
marker="## 2. Product goal"; assert marker in t; p.write_text(t.replace(marker,section+marker,1))
