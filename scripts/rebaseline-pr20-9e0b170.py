#!/usr/bin/env python3
import json
import re
from pathlib import Path

OLD = "5ec257a7920478b56a88bdf24b85eb845aacfb46"
NEW = "9e0b1701d405ebd0b2707620c01781103562b39b"

CHANGED = {
    "source/host/app/src/main.rs": ("284729223dda48978a10055733e5fa628f449a7e", 526361),
    "source/host/src/extensions/transcript/automation_run_path.rs": ("7bedae399879f7269cfded2c5bf629ad9204a0b1", 17160),
    "source/host/src/extensions/transcript/completion_revivals.rs": ("b06f87124f566365b6e41190fc1382bf9c5628cd", 18871),
    "source/host/src/extensions/transcript/transcript_manager.rs": ("3d86d37255aebeff06707ed5888fb722b9760a73", 32970),
    "source/host/src/gateway_protocol.rs": ("13b6a5bad55c133ed67e39bc94b7e500808a82a5", 2832),
    "source/host/src/host_gateway_api.rs": ("b983d0d112a1cc30c8ca2c1d4678704ddf88890f", 8200),
    "source/host/src/host_production_extensions.rs": ("6294645234707fef8472aff85737c2550252fd0b", 53960),
    "source/host/tests/automation_run_path_contract.rs": ("e520c56702d4f700c85600fd53d4b7d3edbd4195", 10385),
    "source/host/tests/gateway_protocol_contract.rs": ("9d98a34267d19246cdf049a9607681b117a57f67", 3304),
    "source/host/tests/host_production_extensions_contract.rs": ("23154526a48966f1e67e6fdafe86212d38d8f45d", 21153),
    "source/host/tests/host_upgrade_production_contract.rs": ("6d569365baa4c452abd9db31a7eddea73385b102", 6993),
    "source/host/tests/remaining_planned_contract.rs": ("e2b2f6577ed5eb2c9e86e33c6fec76de5ae52cb6", 15965),
}

RESPONSIBILITIES = {
    "source/host/app/src/main.rs": "Shipping Host composition consumes the centralized ProductionHostExtensions lifecycle owners and wires their exact instances into Gateway, routed MCP/provider turns, automation/recreate recovery, transcript/run delivery, and shutdown ordering instead of constructing parallel extension owners in main.",
    "source/host/src/extensions/transcript/automation_run_path.rs": "Canonical automation execution path owns the hidden automation wake identity, routed Runner execution, terminal event settlement, timeout/cancellation classification, and upgrade-quiesce carry semantics used by production automation fires.",
    "source/host/src/extensions/transcript/completion_revivals.rs": "Canonical completion-revival path turns Shell/Subagent completion into bounded transcript wake/revival work with durable identity and interruption handling, preserving the no-blind-replay rule across upgrade/recreate.",
    "source/host/src/extensions/transcript/transcript_manager.rs": "Canonical Transcript lifecycle facade owns transcript/session/send/Runner registries and projection observers, binds exactly one PendingWakeRearm owner, delegates recreate-carried wake filtering/restoration to it, and orders quiesce/resume/dispose around subordinate transcript runtimes.",
    "source/host/src/gateway_protocol.rs": "Gateway protocol exposure consumes the single host_gateway_owner registry for the frozen Grok surface while keeping Fabushi-only resumeAfterRecreate as an explicit compatibility command outside that frozen registry.",
    "source/host/src/host_gateway_api.rs": "Single frozen Host gateway method-to-owner registry assigns every public method to its canonical Host owner, including TranscriptManager, Session, CrossUserSharing, Automations and MCP, preventing parallel dispatch ownership tables.",
    "source/host/src/host_production_extensions.rs": "Canonical production extension composition/lifecycle owner constructs or stages the shipping TurnExecution, Notifications, Session, AutoReview, Transcript, CrossUserSharing, Automations and MCP instances, rejects duplicate starts, and owns their ordered stop/drop lifecycle.",
    "source/host/tests/automation_run_path_contract.rs": "Focused contract locks automation hidden-wake identity, terminal settlement, interruption, timeout and upgrade/recreate carry behavior on the production automation run path.",
    "source/host/tests/gateway_protocol_contract.rs": "Focused contract locks the exact frozen gateway surface and its consumption of the canonical method-owner registry while keeping Fabushi compatibility commands explicit.",
    "source/host/tests/host_production_extensions_contract.rs": "Focused composition contract proves ProductionHostExtensions is the unique lifecycle owner for centralized frozen extension slots and that shipping main consumes those owners rather than constructing duplicates.",
    "source/host/tests/host_upgrade_production_contract.rs": "Focused shipping upgrade contract proves quiesce, recreate-carried pending-wake restore and resume ordering through the canonical Transcript/PendingWake owners.",
    "source/host/tests/remaining_planned_contract.rs": "Focused parity contract records the remaining frozen Host responsibilities and prevents centralized shipping owners from regressing to planned/string-only placeholders.",
}

VISIBLE_EFFECTS = {
    "source/host/src/host_production_extensions.rs": "A single shipping Host generation owns each centralized extension lifecycle, so duplicate Notifications/Session/AutoReview/Transcript/CrossUser/Automation/MCP or TurnExecution state cannot diverge across composition paths.",
    "source/host/src/host_gateway_api.rs": "Each frozen gateway request reaches one declared canonical owner; routed MCP, session, transcript, automation and sharing calls cannot silently drift between parallel dispatch tables.",
    "source/host/src/gateway_protocol.rs": "Public protocol exposure stays exact to the frozen owner registry while Fabushi-only recreate compatibility remains explicit and reviewable.",
    "source/host/src/extensions/transcript/transcript_manager.rs": "Transcript/run truth, projections and recreate recovery remain ordered under one lifecycle facade; carried wakes are filtered by the canonical durable wake owner before replay.",
    "source/host/src/extensions/transcript/automation_run_path.rs": "Automation runs retain exact wake/run identity and settle once across success, failure, timeout, cancellation and upgrade quiesce.",
    "source/host/src/extensions/transcript/completion_revivals.rs": "Completion wakeups resume eligible work without blindly re-running interrupted shell/subagent work after lifecycle disruption.",
}

def dump(path, obj):
    Path(path).write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n")

manifest_index = json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
assert manifest_index["authority"]["commit"] == OLD
assert manifest_index["fileCount"] == 7926
manifest_rows = {}
for group in manifest_index["groups"]:
    path = Path(group["path"])
    payload = json.loads(path.read_text())
    assert payload["sourceCommit"] == OLD
    payload["sourceCommit"] = NEW
    for row in payload["files"]:
        manifest_rows[row["path"]] = row
    dump(path, payload)
for path, (sha, size) in CHANGED.items():
    assert path in manifest_rows, path
    manifest_rows[path]["blobSha"] = sha
    manifest_rows[path]["size"] = size
# Re-dump source-host because rows were mutated after initial dump.
for group in manifest_index["groups"]:
    if group["name"] == "source-host":
        payload = json.loads(Path(group["path"]).read_text())
        rows = {row["path"]: row for row in payload["files"]}
        for path, (sha, size) in CHANGED.items():
            rows[path]["blobSha"] = sha
            rows[path]["size"] = size
        dump(group["path"], payload)
manifest_index["authority"]["commit"] = NEW
manifest_index["authority"]["generatedAt"] = "2026-10-03"
dump("manifests/desktop-pr20-reference-index.json", manifest_index)

ledger_index = json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert ledger_index["source"]["commit"] == OLD
for chunk in ledger_index["chunks"]:
    path = Path(chunk["path"])
    payload = json.loads(path.read_text())
    assert payload["sourceCommit"] == OLD
    payload["sourceCommit"] = NEW
    if chunk["name"] == "source-host":
        rows = {row["desktop_path"]: row for row in payload["rows"]}
        for desktop_path, (sha, _) in CHANGED.items():
            row = rows[desktop_path]
            row["desktop_blob_sha"] = sha
            row["implementation_status"] = "mapped"
            row["production_evidence"] = ""
            row["test_evidence"] = ""
            row["desktop_responsibility"] = RESPONSIBILITIES[desktop_path]
            if desktop_path in VISIBLE_EFFECTS:
                row["desktop_visible_effect"] = VISIBLE_EFFECTS[desktop_path]
            note = (
                "Revalidated against Desktop PR #20 "
                + NEW
                + ". The 5ec257a->9e0b170 delta changes this exact source/contract identity. "
                + "Any older implemented/verified or exact-head acceptance claim is invalidated; "
                + "this row is intentionally mapped until iOS shipping composition and same-iOS-HEAD evidence prove the current responsibility."
            )
            row["notes"] = ((row.get("notes") or "").rstrip() + " " + note).strip()
    dump(path, payload)
ledger_index["source"]["commit"] = NEW
dump("docs/parity/desktop-pr20-index.json", ledger_index)

checker = Path("scripts/check-desktop-pr20-ios-architecture.py")
checker_text = checker.read_text()
old_checker = f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'
assert old_checker in checker_text
checker.write_text(checker_text.replace(old_checker, f'EXPECTED_DESKTOP_COMMIT = "{NEW}"', 1))

migration = Path("MIGRATION_SOURCE.md")
migration_text = migration.read_text()
migration_text, count = re.subn(
    r"(?m)^- Pinned source commit: [0-9a-f]{40}$",
    f"- Pinned source commit: {NEW}",
    migration_text,
    count=1,
)
assert count == 1
migration.write_text(migration_text)

spec = Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md")
spec_text = spec.read_text()
old_pin = f"- pinned source commit for this baseline: `{OLD}`"
assert old_pin in spec_text
spec_text = spec_text.replace(old_pin, f"- pinned source commit for this baseline: `{NEW}`", 1)
assert "### 1.15 Exact-HEAD rebaseline" not in spec_text
section = """### 1.15 Exact-HEAD rebaseline: 2026-10-03 / 9e0b1701d405ebd0b2707620c01781103562b39b

Desktop PR #20 advanced 30 commits from `5ec257a7920478b56a88bdf24b85eb845aacfb46` to `9e0b1701d405ebd0b2707620c01781103562b39b`. The selected `frontend/** + source/**` inventory remains exactly 7,926 paths: no selected path was added or removed. Twelve existing Host source/contract paths changed, plus Desktop's parity architecture manifest outside the selected inventory. The intermediate `8bf608904a9b5a8ec426e4ae1845df4f70280857` is not a valid iOS authority because the final `9e0b170` commit rewires shipping composition again in `source/host/app/src/main.rs` and `source/host/src/host_production_extensions.rs`.

Current Desktop shipping ownership is explicit. `host_gateway_api.rs` is the single frozen gateway method-to-owner registry; `gateway_protocol.rs` consumes that registry and keeps only the Fabushi `resumeAfterRecreate` compatibility command outside it. `ProductionHostExtensions` is now the canonical construction/lifecycle owner for the centralized TurnExecution registry plus Notifications, Session, AutoReview, Transcript, CrossUserSharing, Automations and MCP. Its slots reject duplicate starts and own stop/drop ordering. Shipping `main.rs` consumes those exact owners and wires them into routed provider/MCP, automation, transcript, cross-user and lifecycle paths rather than creating a second set. `TranscriptManager` remains the canonical transcript lifecycle facade: it owns transcript/session/send/Runner registries and observer projection, binds one `PendingWakeRearm`, delegates recreate-carried wake filtering/restoration to that durable owner, and orders quiesce/resume/dispose. Automation execution and completion revival remain subordinate production paths with exact wake/run identity and terminal/interruption settlement.

The iOS shipping topology still preserves the architectural boundary: SwiftUI is projection only; `IOSMainRuntime` forwards native lifecycle; `MahayanaCoordinator` is the only production caller allowed to invoke `MahayanaHostRuntime`; the Rust `FeatureHostController` owns canonical feature/runtime state. No SwiftUI, Coordinator or alternate Swift runtime was found constructing a parallel Host extension owner for the responsibilities above. That does not prove parity: current `feature.sessionActivity` only records scene focus/activity and does not yet implement the Desktop generation-safe quiesce -> durable recreate carry/filter -> resume state machine. Therefore all twelve changed selected-source rows are deliberately reset to `mapped`; no older implemented/verified status or old exact-head CI is inherited.

The current protected Global Dharma acceptance exposed a separate shipping auth restoration defect that must be fixed before any acceptance promotion. GitHub Actions successfully creates a bounded refresh-token-free Fabushi session and the UI test forwards its bytes to the launched Simulator app as `FABUSHI_CI_ACCOUNT_SESSION_BASE64`; the canonical Rust Mahayana product auth loader currently accepts only the host-side `FABUSHI_CI_ACCOUNT_SESSION_FILE` path, which the Simulator application cannot read. The iOS contract is therefore: CI application-session restoration remains owned by Rust product auth, never SwiftUI; it may consume exactly one bounded file or base64 transport only when `GITHUB_ACTIONS=true`; both transports must pass the same provenance, identity, size and lifetime validator; malformed, oversized, ambiguous or non-GitHub-Actions transport must fail closed; the bounded application session contains no refresh token. Swift/XCTest may transport the opaque bytes into launch environment but must not become an authentication or session-persistence owner.

"""
assert "## 2. Product goal" in spec_text
spec.write_text(spec_text.replace("## 2. Product goal", section + "## 2. Product goal", 1))

# Final integrity: every selected row still exists exactly once, all authorities
# point to the current Desktop HEAD, and all changed identities fail closed to mapped.
manifest_index = json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
ledger_index = json.loads(Path("docs/parity/desktop-pr20-index.json").read_text())
assert manifest_index["authority"]["commit"] == NEW
assert manifest_index["fileCount"] == 7926
assert ledger_index["source"]["commit"] == NEW
assert ledger_index["rowCount"] == 7926
manifest_rows = {}
for group in manifest_index["groups"]:
    payload = json.loads(Path(group["path"]).read_text())
    assert payload["sourceCommit"] == NEW
    manifest_rows.update({row["path"]: row for row in payload["files"]})
ledger_rows = {}
for chunk in ledger_index["chunks"]:
    payload = json.loads(Path(chunk["path"]).read_text())
    assert payload["sourceCommit"] == NEW
    ledger_rows.update({row["desktop_path"]: row for row in payload["rows"]})
assert len(manifest_rows) == 7926
assert len(ledger_rows) == 7926
for path, (sha, size) in CHANGED.items():
    assert manifest_rows[path]["blobSha"] == sha
    assert manifest_rows[path]["size"] == size
    assert ledger_rows[path]["desktop_blob_sha"] == sha
    assert ledger_rows[path]["implementation_status"] == "mapped"
    assert ledger_rows[path]["production_evidence"] == ""
    assert ledger_rows[path]["test_evidence"] == ""
print("rebaseline-9e0b170-static-integrity: ok")
