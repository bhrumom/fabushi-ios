#!/usr/bin/env python3
import json,re
from pathlib import Path
OLD="1e79bdad87022dcb394b9d4ecaef9508baf7497d"
NEW="39e1eeaee2d861b18a5db5864dac4f7fc049530b"
NOTE=" Revalidated at Desktop PR #20 39e1eeaee2d861b18a5db5864dac4f7fc049530b: upstream architecture manifest now marks HostRunnerComposition implemented and explicitly enumerates state/checkpoint/memory/image/local-permission omission for group members plus RunnerRegistry-before-dispose shutdown ownership. No selected source blob changed; Desktop status is not inherited by iOS, so iOS rows remain mapped until its native shipping path and exact-head CI prove parity."
AFFECTED={
"source/host/app/src/main.rs",
"source/host/src/host_runner_composition.rs",
"source/host/src/runner/generated_agent_turn_stream.rs",
"source/host/src/runner/production_turn_agent_owner.rs",
"source/host/tests/host_runner_composition_local_permission_contract.rs",
"source/host/tests/host_runner_composition_production_wiring_contract.rs",
"source/host/src/extensions/transcript/runner_registry.rs",
}
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
                if row.get("implementation_status") not in ("mapped","implemented","unreviewed"):
                    raise AssertionError((row["desktop_path"],row.get("implementation_status")))
                if row.get("implementation_status")=="implemented":
                    row["implementation_status"]="mapped"
                row["notes"]=(row.get("notes") or "")+NOTE
    dump(p,v)
mi["authority"]["commit"]=NEW; dump("manifests/desktop-pr20-reference-index.json",mi)
li["source"]["commit"]=NEW; dump("docs/parity/desktop-pr20-index.json",li)
p=Path("scripts/check-desktop-pr20-ios-architecture.py"); t=p.read_text(); old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'; assert old in t; p.write_text(t.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))
p=Path("MIGRATION_SOURCE.md"); t=p.read_text(); t,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",t,count=1); assert n==1; p.write_text(t)
p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md"); t=p.read_text(); old=f"- pinned source commit for this baseline: `{OLD}`"; assert old in t; t=t.replace(old,f"- pinned source commit for this baseline: `{NEW}`",1)
assert "### 1.28 Exact-HEAD rebaseline" not in t
section="""### 1.28 Exact-HEAD rebaseline: 2026-10-03 / `39e1eeaee2d861b18a5db5864dac4f7fc049530b`

Desktop PR #20 advanced one architecture-manifest-only commit from `1e79bdad87022dcb394b9d4ecaef9508baf7497d` to `39e1eeaee2d861b18a5db5864dac4f7fc049530b`. The selected `frontend/** + source/**` inventory remains exactly **7,927** blobs and every selected blob SHA is unchanged.

The Desktop manifest now declares HostRunnerComposition implemented after shipping-owner audit. Its normative responsibility set is explicit: one Host owner composes per-turn state/checkpoint surfaces, Runner construction and ordered decoration; group-member turns keep the generated-Agent lifecycle while omitting private state/checkpoint/memory/image/local-permission surfaces; TranscriptRunnerRegistry remains the active-run cancellation owner; HostRunnerComposition disposes only its own permission subscriptions after Runner cancellation.

That Desktop status is evidence about Desktop only. iOS does not inherit `implemented` or `verified`. The affected iOS rows remain `mapped` until the native mobile shipping path proves the same product effects and the exact iOS HEAD passes its own required CI/acceptance gates.

"""
marker="## 2. Product goal"; assert marker in t; p.write_text(t.replace(marker,section+marker,1))
