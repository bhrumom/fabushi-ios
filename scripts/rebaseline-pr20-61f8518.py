#!/usr/bin/env python3
import json
from pathlib import Path

OLD = "b5f8855805ec1c0be3a821cf35a4cba047ee9d8b"
NEW = "61f8518a5e0b4bead224ec3c081da64523316908"
BT = chr(96)

changed = {
    "source/host/app/src/main.rs": ("3d536f022627910d8202d2a346f31399b319a4fe", 524172),
    "source/host/src/extensions/transcript/turn_runtime.rs": ("44302a0a811ca9f0d68ba41cac4d1ead70f9fdf5", 10962),
    "source/host/src/runner/production_turn_agent_owner.rs": ("855b9060ca52a251fd5a8cb8d2e0aa2a6f704e20", 8542),
    "source/host/src/runner/turn_agent_composition.rs": ("9486a6c721cd655212bc64e56fb9f2c538809da8", 19259),
    "source/host/src/runner/turn_run_shell.rs": ("fedd534dea9a0e94dda75b2f84ae288e36c4799f", 9668),
    "source/host/src/runner/turn_shape.rs": ("0c2f2a423622983e8de38e65ad8e5fed203b46b6", 15908),
    "source/host/tests/runner_delivery_parity_contract.rs": ("c699fa96fa810708249c5e567347fafd67fe9fe1", 13179),
    "source/host/tests/turn_runtime_recovery_contract.rs": ("cb971e7734b261d310d2fe6dccce045be6227e0d", 10431),
}

mi_path = Path("manifests/desktop-pr20-reference-index.json")
mi = json.loads(mi_path.read_text())
if mi["authority"]["commit"] != OLD or mi["fileCount"] != 7926:
    raise SystemExit("unexpected manifest authority/count")
for group in mi["groups"]:
    path = Path(group["path"])
    obj = json.loads(path.read_text())
    if obj["sourceCommit"] != OLD:
        raise SystemExit(f"{path}: unexpected sourceCommit")
    obj["sourceCommit"] = NEW
    if group["name"] == "source-host":
        rows = {r["path"]: r for r in obj["files"]}
        for p, (sha, size) in changed.items():
            rows[p]["blobSha"] = sha
            rows[p]["size"] = size
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n")
mi["authority"]["commit"] = NEW
mi["authority"]["generatedAt"] = "2026-10-03"
mi_path.write_text(json.dumps(mi, ensure_ascii=False, indent=2) + "\n")

li_path = Path("docs/parity/desktop-pr20-index.json")
li = json.loads(li_path.read_text())
if li["source"]["commit"] != OLD:
    raise SystemExit("unexpected ledger authority")
for chunk in li["chunks"]:
    path = Path(chunk["path"])
    obj = json.loads(path.read_text())
    if obj["sourceCommit"] != OLD:
        raise SystemExit(f"{path}: unexpected sourceCommit")
    obj["sourceCommit"] = NEW
    if chunk["name"] == "source-host":
        rows = {r["desktop_path"]: r for r in obj["rows"]}
        for p, (sha, _) in changed.items():
            rows[p]["desktop_blob_sha"] = sha
            rows[p]["implementation_status"] = "mapped"
            rows[p]["test_evidence"] = (
                "Desktop PR #20 61f8518 changes this exact blob. Current iOS has not yet proved "
                "the new closing-send-nudge, durable silent-tool-tail, and ordinary empty-delivery "
                "responsibility on this upstream identity; exact-HEAD focused Actions evidence is required."
            )
        rows["source/host/app/src/main.rs"]["desktop_responsibility"] = (
            "Shipping routed-turn settlement owns the existing success-only automation refresh plus a hidden "
            "closing SendMessage nudge for a successful same-epoch user turn ending on silent tool calls, then "
            "ordinary empty-delivery telemetry when delivery debt remains after recovery."
        )
        rows["source/host/app/src/main.rs"]["desktop_visible_effect"] = (
            "Users are not left with only an opening acknowledgement after tool work, and settled turns that "
            "still deliver neither SendMessage nor reaction are observably reported without changing settlement."
        )
        rows["source/host/app/src/main.rs"]["notes"] += (
            " Rebased to Desktop PR #20 61f8518. The iOS active-Agent automation projection remains a real "
            "implemented sub-responsibility, but this broad row is mapped because closing-send recovery and "
            "ordinary empty-delivery telemetry are new and not yet present in iOS production."
        )
        rows["source/host/src/extensions/transcript/turn_runtime.rs"]["desktop_responsibility"] = (
            "Canonical turn policy for reply/closing hidden nudges, delivery debt, terminal projection, and "
            "construction of ordinary empty-delivery reports only for successful uncancelled non-WaitingUser "
            "same-epoch turns that still owe delivery."
        )
        rows["source/host/src/extensions/transcript/turn_runtime.rs"]["desktop_visible_effect"] = (
            "Recovery prompts preserve original request boundaries and telemetry is suppressed for delivered, "
            "reaction, WaitingUser, cancelled, failed, or superseded turns."
        )
        rows["source/host/src/runner/production_turn_agent_owner.rs"]["desktop_responsibility"] = (
            "Shipping Runner owner records whether the completed provider run ended on a durable silent-tool "
            "tail and attaches that fact to TurnRunFinished."
        )
        rows["source/host/src/runner/production_turn_agent_owner.rs"]["desktop_visible_effect"] = (
            "Host closing-send recovery is driven by the real provider run/checkpoint outcome, not UI heuristics."
        )
        rows["source/host/src/runner/turn_agent_composition.rs"]["desktop_responsibility"] = (
            "Wrap the durable provider checkpoint store, remember only the latest checkpoint for the current run, "
            "clear it before every run, and expose provider-neutral silent-tool-tail classification."
        )
        rows["source/host/src/runner/turn_agent_composition.rs"]["desktop_visible_effect"] = (
            "Checkpoint state cannot leak across runs and closing-send recovery inspects the exact durable checkpoint."
        )
        rows["source/host/src/runner/turn_run_shell.rs"]["desktop_responsibility"] = (
            "TurnRunFinished carries ended_on_silent_tool_calls as canonical terminal metadata, initialized false "
            "by the shell and filled by the production turn owner."
        )
        rows["source/host/src/runner/turn_run_shell.rs"]["desktop_visible_effect"] = (
            "Post-run Host policy receives one ordered silent-tool terminal fact without a parallel owner."
        )
        rows["source/host/src/runner/turn_shape.rs"]["desktop_responsibility"] = (
            "Normalize durable Cursor, Codex direct-responses, and OpenRouter checkpoints into one turn-shape "
            "classification for an acknowledgement followed by silent tool calls and no later visible SendMessage."
        )
        rows["source/host/src/runner/turn_shape.rs"]["desktop_visible_effect"] = (
            "Closing-send decisions are provider-neutral and durable; final text outside the checkpoint defeats "
            "the silent-tail classification."
        )
        rows["source/host/tests/runner_delivery_parity_contract.rs"]["desktop_responsibility"] = (
            "Focused Runner contract proving durable checkpoints drive silent-tool-tail projection and later "
            "visible sends/final text prevent it."
        )
        rows["source/host/tests/runner_delivery_parity_contract.rs"]["desktop_visible_effect"] = (
            "Regression evidence prevents spurious or missing closing-send nudges across providers."
        )
        rows["source/host/tests/turn_runtime_recovery_contract.rs"]["desktop_responsibility"] = (
            "Focused contracts for closing-send hidden-input identity isolation and ordinary empty-delivery "
            "reporting only for settled same-epoch delivery debt."
        )
        rows["source/host/tests/turn_runtime_recovery_contract.rs"]["desktop_visible_effect"] = (
            "Recovery does not impersonate a new user request, and invalid terminal states cannot be reported as empty delivery."
        )
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n")
li["source"]["commit"] = NEW
li_path.write_text(json.dumps(li, ensure_ascii=False, indent=2) + "\n")

checker_path = Path("scripts/check-desktop-pr20-ios-architecture.py")
checker = checker_path.read_text()
token = f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'
if token not in checker:
    raise SystemExit("strict checker old authority missing")
checker_path.write_text(checker.replace(token, f'EXPECTED_DESKTOP_COMMIT = "{NEW}"', 1))

spec_path = Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md")
spec = spec_path.read_text()
old_pin = f"- pinned source commit for this baseline: {BT}{OLD}{BT}"
if old_pin not in spec:
    raise SystemExit("active Spec old pin missing")
spec = spec.replace(old_pin, f"- pinned source commit for this baseline: {BT}{NEW}{BT}", 1)
if "### 1.9 Exact-HEAD rebaseline" in spec:
    raise SystemExit("Spec 1.9 already exists")
section = """### 1.9 Exact-HEAD rebaseline: 2026-10-03 / 61f8518a5e0b4bead224ec3c081da64523316908

Desktop PR #20 advanced two commits from b5f8855805ec1c0be3a821cf35a4cba047ee9d8b to 61f8518a5e0b4bead224ec3c081da64523316908. The recursive Git tree still contains exactly 7,926 selected frontend/** + source/** blobs, and the Git comparison contains only eight modified source/host/** files: no selected path was added or removed. This rebaseline updates every manifest/ledger chunk authority, both indexes, the strict checker, and the eight changed blob identities before any new iOS parity claim is accepted.

The first upstream commit restores a distinct closing-send nudge for a visible user turn that already emitted an acknowledgement, then completed tool work but ended without a later SendMessage. ProductionTurnAgentOwner records ended_on_silent_tool_calls from the exact latest durable provider checkpoint owned by TurnAgentComposition. Cursor, Codex direct-responses, and OpenRouter checkpoint forms are normalized through turn_shape; a later visible send or final text outside the persisted checkpoint defeats the silent-tail predicate. The hidden closing nudge preserves the original inference request identity while clearing message/reply/fork/attachment identity. It is attempted only for an uncancelled, same-epoch, successful visible user turn that is not WaitingUser.

The second upstream commit reports ordinary empty delivery after reply/closing recovery has settled when a visible user turn still owes delivery. The report is fail-closed unless the run succeeded, was not cancelled, is not WaitingUser, is still on the same turn epoch, and delivered neither a SendMessage nor reaction. It captures bounded reply-nudge attempts, observed tool-call count, stream-output presence, run duration, and outstanding acknowledgement state. Telemetry failure is non-fatal to settlement.

The iOS active-Agent automation projection implemented immediately before this rebaseline remains an applicable Host-owned behavior. However, the broader Desktop main responsibility now includes closing-send recovery and ordinary empty-delivery reporting. Current iOS source has no corresponding closing-send prompt, durable silent-checkpoint terminal fact, or empty-delivery report path, so all eight changed rows are conservatively mapped. The next production slice must preserve Coordinator/Host/Runner ownership: checkpoint observation belongs with Runner/runtime, terminal recovery policy belongs in canonical Host/runtime code, telemetry is a projection of those facts, and SwiftUI/renderer must not synthesize them.

"""
marker = "## 2. Product goal"
if marker not in spec:
    raise SystemExit("Spec marker missing")
spec_path.write_text(spec.replace(marker, section + marker, 1))

# Full post-write integrity.
mi = json.loads(mi_path.read_text())
li = json.loads(li_path.read_text())
manifest_rows = {}
for group in mi["groups"]:
    obj = json.loads(Path(group["path"]).read_text())
    if obj["sourceCommit"] != NEW:
        raise SystemExit(f"manifest chunk not rebound: {group['path']}")
    manifest_rows.update({r["path"]: r for r in obj["files"]})
ledger_rows = {}
for chunk in li["chunks"]:
    obj = json.loads(Path(chunk["path"]).read_text())
    if obj["sourceCommit"] != NEW:
        raise SystemExit(f"ledger chunk not rebound: {chunk['path']}")
    ledger_rows.update({r["desktop_path"]: r for r in obj["rows"]})
if len(manifest_rows) != 7926 or len(ledger_rows) != 7926:
    raise SystemExit("materialized inventory count mismatch")
for p, (sha, size) in changed.items():
    if manifest_rows[p]["blobSha"] != sha or manifest_rows[p]["size"] != size:
        raise SystemExit(f"manifest identity mismatch: {p}")
    if ledger_rows[p]["desktop_blob_sha"] != sha or ledger_rows[p]["implementation_status"] != "mapped":
        raise SystemExit(f"ledger affected-row mismatch: {p}")
if NEW not in checker_path.read_text() or NEW not in spec_path.read_text():
    raise SystemExit("checker/spec authority mismatch")
print("rebaseline-61f8518-static-integrity: ok")
