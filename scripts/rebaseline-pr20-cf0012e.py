#!/usr/bin/env python3
import json,re
from pathlib import Path

OLD="9f22a1974f02683f4ad27a2fe856987b7dd1d20f"
NEW="cf0012e6bb5ddcd1669c747994af68a5055bf05d"
CHANGED={
"source/host/app/src/main.rs":("5a41e5a5515cfc241b50289fdbb3234243b5c24b",523062),
"source/host/src/host_runner_composition.rs":("b87a9df8b50318739701effd044b4a2f9a0f3b17",16169),
"source/host/src/runner/generated_agent_turn_stream.rs":("743136dd1bc4388ec78be44ed01329a51e2977b6",8938),
"source/host/src/runner/production_turn_agent_owner.rs":("4ee30b2ee740a0d812563d152da85080c75e766f",9456),
"source/host/tests/host_runner_composition_production_wiring_contract.rs":("03e513eb4dbbc6e0d02f91b37a59767a828617f1",9611),
}
NOTE=" Revalidated at Desktop PR #20 cf0012e6bb5ddcd1669c747994af68a5055bf05d: upstream now makes group-member turns retain the generated-Agent lifecycle while omitting private checkpoint/state/image persistence. Current iOS NativeRunnerComposition has one canonical NativeEngine owner but no equivalent group-member composition boundary, so this affected row is deliberately reset to mapped pending shipping implementation and same-head evidence."

def dump(path,value):
    Path(path).write_text(json.dumps(value,ensure_ascii=False,indent=2)+"\n")

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
        assert len(v["files"])==957
    dump(p,v)

for c in li["chunks"]:
    p=Path(c["path"]); v=json.loads(p.read_text()); assert v["sourceCommit"]==OLD
    v["sourceCommit"]=NEW
    if c["name"]=="source-host":
        touched=0
        for row in v["rows"]:
            if row["desktop_path"] in CHANGED:
                row["desktop_blob_sha"]=CHANGED[row["desktop_path"]][0]
                row["implementation_status"]="mapped"
                row["notes"]=(row.get("notes") or "")+NOTE
                touched+=1
        assert touched==5 and len(v["rows"])==957
    dump(p,v)

mi["authority"]["commit"]=NEW; dump("manifests/desktop-pr20-reference-index.json",mi)
li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)

p=Path("scripts/check-desktop-pr20-ios-architecture.py")
t=p.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in t
p.write_text(t.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))

p=Path("MIGRATION_SOURCE.md")
t=p.read_text(); t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1
p.write_text(t)

p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md")
t=p.read_text(); old=f"- pinned source commit for this baseline: `{OLD}`"; assert old in t
t=t.replace(old,f"- pinned source commit for this baseline: `{NEW}`",1)
assert "### 1.25 Exact-HEAD rebaseline" not in t
section="""### 1.25 Exact-HEAD rebaseline: 2026-10-03 / `cf0012e6bb5ddcd1669c747994af68a5055bf05d`

Desktop PR #20 advanced two production commits from `9f22a1974f02683f4ad27a2fe856987b7dd1d20f` to `cf0012e6bb5ddcd1669c747994af68a5055bf05d`. The selected inventory remains exactly **7,927** blobs. Five `source-host` blobs changed: shipping `main.rs`, `host_runner_composition.rs`, `generated_agent_turn_stream.rs`, `production_turn_agent_owner.rs`, and the focused production wiring contract.

The new responsibility is behavioral, not merely structural. A group-member turn must still execute through the canonical generated-Agent lifecycle and terminal owner, while private per-Agent state is deliberately absent: no private checkpoint sink, no private turn-state surface, and no private browser/computer image-persistence callback. `HostRunnerComposition` is the sole composition owner that decides those omissions before the Runner is constructed. The shipping Host may supply group-member identity and request-specific hooks but may not create a parallel raw-provider path or private-state fallback.

The current iOS `NativeRunnerComposition` proves a single shared `NativeEngine` owner for Runtime and NativeAgent, but it has no group-member composition input and therefore cannot yet prove the required generated-lifecycle-without-private-state behavior. All five affected ledger rows are intentionally reset to `mapped`; prior `implemented` evidence remains historical and cannot satisfy this upstream identity. The iOS closure must be a native Host/Runner composition rule, not SwiftUI/Coordinator state and not a test-only facade. Same-iOS-HEAD GitHub Actions evidence is required before promotion.

"""
marker="## 2. Product goal"
assert marker in t
t=t.replace(marker,section+marker,1)
p.write_text(t)
