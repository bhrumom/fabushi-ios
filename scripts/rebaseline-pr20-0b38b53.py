#!/usr/bin/env python3
import json,re
from pathlib import Path

OLD="c43b246c8cd4b85359acba7850dd64d5a2fececc"
NEW="0b38b53a1a6b7cfe9957cf26732799cd657470a4"
PATH="source/host/tests/generated_subagent_production_cutover_contract.rs"
BLOB="68e50bb055ddd4356da85644a00bf8ae0bdf59e6"

def dump(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2)+"\n")

mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==OLD
assert li["source"]["commit"]==OLD
assert mi["fileCount"]==7927 and li["rowCount"]==7927

for group in mi["groups"]:
    p=Path(group["path"])
    data=json.loads(p.read_text())
    assert data["sourceCommit"]==OLD
    data["sourceCommit"]=NEW
    if group["name"]=="source-host":
        found=0
        for row in data["files"]:
            if row["path"]==PATH:
                row["blobSha"]=BLOB
                found+=1
        assert found==1
    dump(p,data)

for chunk in li["chunks"]:
    p=Path(chunk["path"])
    data=json.loads(p.read_text())
    assert data["sourceCommit"]==OLD
    data["sourceCommit"]=NEW
    if chunk["name"]=="source-host":
        found=0
        for row in data["rows"]:
            if row["desktop_path"]==PATH:
                row["desktop_blob_sha"]=BLOB
                row["desktop_responsibility"]="Focused production cutover contract proving generated subagent Task dispatch carries the real tool-call identity through review before launch, binds review and sink through canonical HostRunnerComposition/TurnToolset, creates the child Runner/session under the shipping Host owner, and projects live child lifecycle to the parent without recursively installing Task in child sessions."
                row["desktop_visible_effect"]="A generated subagent cannot launch before its exact Task call passes the shared review boundary; accepted launches have one child Runner/lifecycle owner and appear/disappear on the parent projection with the original tool-call identity."
                row["ios_disposition"]="ios-adapted"
                row["ios_target_path"]="source/packages/mahayana-rs/mahayana-native-engine/src/lib.rs"
                row["ios_language"]="Rust"
                row["ios_platform_delta"]="Use the iOS-owned NativeEngine/SubagentScheduler and its real function-call identity/approval boundary; preserve child lifecycle and parent projection semantics without copying Desktop process mechanics or adding a Swift-side launch owner."
                row["implementation_status"]="mapped"
                row["production_evidence"]=""
                row["test_evidence"]=""
                row["notes"]=(row.get("notes") or "")+" Revalidated at Desktop PR #20 0b38b53a1a6b7cfe9957cf26732799cd657470a4: the contract now requires real Task tool_call_id review fencing plus canonical HostRunnerComposition/TurnToolset launch ownership and live parent projection. Current iOS NativeEngine already authorizes subagent_run before dispatch, but this row remains mapped until exact child lifecycle/parent projection and shared review-owner behavior are proven on the shipping path."
                found+=1
        assert found==1
    dump(p,data)

mi["authority"]["commit"]=NEW
li["source"]["commit"]=NEW
dump("manifests/desktop-pr20-reference-index.json",mi)
dump("docs/parity/desktop-pr20-index.json",li)

p=Path("scripts/check-desktop-pr20-ios-architecture.py")
text=p.read_text()
old=f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'
assert old in text
p.write_text(text.replace(old,f'EXPECTED_DESKTOP_COMMIT = "{NEW}"',1))

p=Path("MIGRATION_SOURCE.md")
text=p.read_text()
text,n=re.subn(r"(?m)^- Pinned source commit: [0-9a-f]{40}$",f"- Pinned source commit: {NEW}",text,count=1)
assert n==1
p.write_text(text)

p=Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md")
text=p.read_text()
needle=f"- pinned source commit for this baseline: `{OLD}`"
assert needle in text
text=text.replace(needle,f"- pinned source commit for this baseline: `{NEW}`",1)
assert "### 1.35 Exact-HEAD rebaseline" not in text
section="""### 1.35 Exact-HEAD rebaseline: 2026-10-03 / `0b38b53a1a6b7cfe9957cf26732799cd657470a4`

Desktop PR #20 advanced two commits from `c43b246c8cd4b85359acba7850dd64d5a2fececc` to `0b38b53a1a6b7cfe9957cf26732799cd657470a4`. The selected inventory remains exactly **7,927** blobs. The only selected-source blob change is `source/host/tests/generated_subagent_production_cutover_contract.rs`.

The changed contract now proves more than child-session existence. Shipping Task launch must carry the real tool-call identity into Subagent review, a denied review must fence dispatch before the sink runs, and accepted review/sink dependencies must enter generated turns through canonical `HostRunnerComposition` / `TurnToolset`. The shipping Host remains the child Runner/session and live-parent projection owner, and child sessions do not recursively install Task.

For iOS this is `ios-adapted`. The existing `NativeEngine` already owns `subagent_run`, receives the actual model function-call id, and passes every tool through its Rust approval boundary before executing the SubagentScheduler. That overlap is not enough to inherit implementation status for the expanded Desktop responsibility. The row is reviewed to `mapped` until the iOS shipping path proves one child lifecycle owner, parent live projection, no recursive launch owner, and the same real-call identity review fence without a Swift/Coordinator parallel owner.

"""
marker="## 2. Product goal"
assert marker in text
p.write_text(text.replace(marker,section+marker,1))
