#!/usr/bin/env python3
import json,re
from pathlib import Path

OLD="2d7320aacff322010238a2fca5431adce5c108a3"
NEW="4186cea169a71a0ebe38849f844dc153de204078"
PATH="source/host/tests/runner_communicate_listener_contract.rs"
BLOB="33f2a98dbdde90f09fd79d8204c27213ff461a8c"
SIZE=10116

def dump(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2)+"\n")

mi=json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
li=json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert mi["authority"]["commit"]==OLD
assert li["source"]["commit"]==OLD
assert mi["fileCount"]==7927 and li["rowCount"]==7927

for group in mi["groups"]:
    p=Path(group["path"]); data=json.loads(p.read_text())
    assert data["sourceCommit"]==OLD
    data["sourceCommit"]=NEW
    if group["name"]=="source-host":
        found=0
        for row in data["files"]:
            if row["path"]==PATH:
                row["blobSha"]=BLOB
                row["size"]=SIZE
                found+=1
        assert found==1
    dump(p,data)

for chunk in li["chunks"]:
    p=Path(chunk["path"]); data=json.loads(p.read_text())
    assert data["sourceCommit"]==OLD
    data["sourceCommit"]=NEW
    if chunk["name"]=="source-host":
        found=0
        for row in data["rows"]:
            if row["desktop_path"]==PATH:
                row["desktop_blob_sha"]=BLOB
                row["desktop_responsibility"]="Focused production contract proving routine post-write listener-connect cards and automatic connection watching are installed through the canonical HostRunnerComposition hook rather than a parallel shipping owner."
                row["desktop_visible_effect"]="After a routine writes to an integration that is not connected, the user sees the required connect card/instruction and the Host watches connection state so the routine can resume automatically without moving lifecycle truth into UI code."
                row["ios_disposition"]="ios-adapted"
                row["ios_target_path"]="source/packages/mahayana-rs/mahayana-feature-host/src/implementation.rs"
                row["ios_language"]="Rust"
                row["ios_platform_delta"]="Reuse the iOS FeatureHostController as the canonical automation/listener owner. Add the iOS-native post-write listener-connect and resume-watch behavior there or in one subordinate Rust Host service; SwiftUI/Coordinator may project cards and connection state but must not own watcher or routine-resume truth."
                row["implementation_status"]="mapped"
                row["production_evidence"]=""
                row["test_evidence"]=""
                row["notes"]=(row.get("notes") or "")+" Revalidated at Desktop PR #20 4186cea169a71a0ebe38849f844dc153de204078: routine post-write listener connection handling is now explicitly bound through HostRunnerComposition. Current iOS FeatureHostController owns automations and listener summaries, but no equivalent shipping post-write connect-card plus connection-watcher resume path is yet proven, so this row remains mapped."
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
assert "### 1.37 Exact-HEAD rebaseline" not in text
section="""### 1.37 Exact-HEAD rebaseline: 2026-10-03 / `4186cea169a71a0ebe38849f844dc153de204078`

Desktop PR #20 advanced one commit from `2d7320aacff322010238a2fca5431adce5c108a3` to `4186cea169a71a0ebe38849f844dc153de204078`. The selected inventory remains exactly **7,927** blobs. The only selected-source blob change is `source/host/tests/runner_communicate_listener_contract.rs`.

The strengthened contract binds the routine post-write integration path to the canonical `HostRunnerComposition`: after a routine writes to a target whose listener platform is not connected, shipping Host surfaces the frozen connect card/instruction and arms the lifecycle connection watcher, while the turn still consumes the same production composition hook. This is an ownership/lifecycle requirement, not merely a UI-string contract.

For iOS this is `ios-adapted`. `FeatureHostController` already owns native automations and listener summaries, but the current shipping path does not yet prove the Desktop product effect of post-write listener connect guidance plus Host-owned connection watching and automatic routine resume. The changed row is therefore reviewed to `mapped` only. The eventual iOS implementation must keep watcher/resume truth in the Rust Host/runtime owner and let SwiftUI/Coordinator project state rather than create a parallel listener lifecycle.

"""
marker="## 2. Product goal"
assert marker in text
p.write_text(text.replace(marker,section+marker,1))
