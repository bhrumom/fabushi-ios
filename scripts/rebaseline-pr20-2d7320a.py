#!/usr/bin/env python3
import json,re
from pathlib import Path

OLD="0b38b53a1a6b7cfe9957cf26732799cd657470a4"
NEW="2d7320aacff322010238a2fca5431adce5c108a3"
PATH="source/host/tests/journal_outcome_production_wiring_contract.rs"
BLOB="7d4700e748b15362718071204800ffcc92edf470"
SIZE=1417

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
                row["desktop_responsibility"]="Focused production wiring contract proving transcript/checkpoint journal outcomes are created by the shipping Runner checkpoint composition, reported through the unique Host telemetry owner, and not re-owned by Coordinator or renderer telemetry."
                row["desktop_visible_effect"]="Checkpoint/transcript persistence failures and outcomes keep one shipping owner and one telemetry projection, so runtime recovery evidence cannot drift across parallel composition or UI/Coordinator telemetry paths."
                row["ios_disposition"]="ios-adapted"
                row["ios_target_path"]="source/packages/mahayana-rs/mahayana-native-engine/src/lib.rs"
                row["ios_language"]="Rust"
                row["ios_platform_delta"]="Use the iOS-owned NativeEngine/session persistence and Rust telemetry owners as the native replacement for Desktop transcript-journal checkpoint composition. Preserve one composition/reporting owner; SwiftUI and Coordinator may only project outcomes and must not rebuild persistence truth."
                row["implementation_status"]="mapped"
                row["production_evidence"]=""
                row["test_evidence"]=""
                row["notes"]=(row.get("notes") or "")+" Revalidated at Desktop PR #20 2d7320aacff322010238a2fca5431adce5c108a3: journal outcome production wiring moved behind canonical HostRunnerComposition.compose_production_checkpoint_sink while HostTelemetryService remains the unique structured-log owner and Coordinator/Electron remain non-owners. iOS has durable NativeEngine session/checkpoint state and Rust telemetry primitives, but this row remains mapped until the shipping persistence outcome path and unique telemetry ownership are proven without a Swift/Coordinator parallel owner."
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
assert "### 1.36 Exact-HEAD rebaseline" not in text
section="""### 1.36 Exact-HEAD rebaseline: 2026-10-03 / `2d7320aacff322010238a2fca5431adce5c108a3`

Desktop PR #20 advanced one commit from `0b38b53a1a6b7cfe9957cf26732799cd657470a4` to `2d7320aacff322010238a2fca5431adce5c108a3`. The selected inventory remains exactly **7,927** blobs. The only selected-source blob change is `source/host/tests/journal_outcome_production_wiring_contract.rs`.

The changed contract makes checkpoint/transcript journal composition ownership explicit: shipping `app/main.rs` must delegate production checkpoint-sink construction to `HostRunnerComposition::compose_production_checkpoint_sink`; that composition owns the one-time connection to `ProductionTranscriptMirrorProvider::with_reporter`, while journal outcomes continue through the unique Host telemetry owner. Coordinator and renderer/Electron telemetry remain non-owners.

For iOS this is `ios-adapted`, not mechanism-equivalent. NativeEngine/session persistence and Rust telemetry are the platform-owned replacement for Desktop transcript-journal storage and Host structured logging, but the product responsibility still applies: one shipping runtime composition must own persistence outcome truth, one Rust telemetry owner must report it, and SwiftUI/Coordinator may only project that state. The changed ledger row is reviewed from `unreviewed` to `mapped`; existing durable session/checkpoint primitives are not enough to claim implementation until their production outcome/reporting path and unique ownership are demonstrated.

"""
marker="## 2. Product goal"
assert marker in text
p.write_text(text.replace(marker,section+marker,1))
