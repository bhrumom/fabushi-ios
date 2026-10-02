#!/usr/bin/env python3
import json
from pathlib import Path

OLD = "827f22da7c527ab22df0700303f356d589c2a0f4"
NEW = "b5f8855805ec1c0be3a821cf35a4cba047ee9d8b"

changed = {
    "source/host/app/src/main.rs": "5aa020171b70db20da5b2ab423eb1b92020823a8",
    "source/host/src/extensions/transcript/roster_emit.rs": "5fb7bb1e99b3a04f5e9617b0fade44025b99ca7b",
    "source/host/src/extensions/transcript/transcript_manager.rs": "404cb5e138cb577bcb6c1745c888ef35134428e5",
    "source/host/tests/transcript_manager_contract.rs": "c7495806b7b3bd8720c5c7bb352cc999bd8a367b",
}

ledger_index_path = Path("docs/parity/desktop-pr20-index.json")
ledger_index = json.loads(ledger_index_path.read_text())
if ledger_index["source"]["commit"] != OLD:
    raise SystemExit(f"unexpected ledger index authority: {ledger_index['source']['commit']}")

for chunk in ledger_index["chunks"]:
    path = Path(chunk["path"])
    payload = json.loads(path.read_text())
    if payload["sourceCommit"] != OLD:
        raise SystemExit(f"{path}: unexpected sourceCommit {payload['sourceCommit']}")
    payload["sourceCommit"] = NEW

    if chunk["name"] == "source-host":
        rows = {row["desktop_path"]: row for row in payload["rows"]}
        for source_path, blob_sha in changed.items():
            row = rows[source_path]
            row["desktop_blob_sha"] = blob_sha
            row["implementation_status"] = "mapped"
            row["test_evidence"] = (
                "Desktop b5f885 changed this exact blob. Current iOS baseline did not yet contain "
                "the required success-terminal active-Agent automation projection contract; "
                "same-iOS-HEAD CI is required after shipping implementation."
            )

        main = rows["source/host/app/src/main.rs"]
        main["desktop_responsibility"] = (
            "Shipping Host composition and routed-turn settlement: after a routed provider turn "
            "has settled successfully, ask the canonical TranscriptManager to refresh that Agent's "
            "automations before the routed-turn lease is retired; failed turns skip this projection."
        )
        main["desktop_visible_effect"] = (
            "A successful routed Agent turn can immediately refresh the active Agent's automation "
            "surface from canonical Host state, while failed turns cannot publish a success-adjacent "
            "automation snapshot."
        )
        main["notes"] += (
            " Revalidated against Desktop PR #20 b5f8855805ec1c0be3a821cf35a4cba047ee9d8b. "
            "After settle_routed_provider_task_result returns success, shipping main calls "
            "TranscriptManager.emit_automations(agent_id) before the routed-turn lease is retired; "
            "an Err result skips the call. iOS FeatureHostController already owns automation "
            "state/persistence and operation-to-Agent identity, but the current OperationCompleted "
            "path drops operation_agents without a success-only active-Agent automation projection, "
            "so this row remains mapped pending real production wiring and same-HEAD evidence."
        )

        roster = rows["source/host/src/extensions/transcript/roster_emit.rs"]
        roster["desktop_responsibility"] = (
            "Canonical transcript/Agent projection surface, including active-Agent gating for "
            "automation snapshots emitted after successful routed-turn settlement."
        )
        roster["desktop_visible_effect"] = (
            "Consumers receive an automation snapshot tagged with the Agent identity only when that "
            "Agent is still the canonical active Agent at emission time; switching away suppresses "
            "the stale/inactive projection."
        )
        roster["notes"] += (
            " Revalidated against Desktop PR #20 b5f8855805ec1c0be3a821cf35a4cba047ee9d8b. "
            "ProductionRosterEmit.emit_automations re-reads the canonical active Agent and returns "
            "false without emitting when it differs; the emitted payload carries agentId plus the "
            "live automation records. This makes session-switch timing part of the contract. iOS "
            "currently has Host-owned ConversationSessionState but no corresponding active-Agent "
            "automation snapshot after terminal success, so no status promotion is allowed."
        )

        manager = rows["source/host/src/extensions/transcript/transcript_manager.rs"]
        manager["desktop_responsibility"] = (
            "Single transcript-adjacent composition owner for delegates/lifecycle plus canonical "
            "per-Agent automation refresh: read automation state through AutomationRuntime and "
            "delegate only projection to the roster surface."
        )
        manager["desktop_visible_effect"] = (
            "Automation refresh after a successful turn is sourced from the Host's canonical "
            "persisted Agent automation state rather than renderer cache or a parallel facade, "
            "while projection remains scoped to the currently active Agent."
        )
        manager["notes"] += (
            " Revalidated against Desktop PR #20 b5f8855805ec1c0be3a821cf35a4cba047ee9d8b. "
            "TranscriptManager.emit_automations reads AutomationRuntime.get_agent_automations(agent_id), "
            "converts canonical records, and delegates to the roster owner. The iOS FeatureHostController "
            "is already the single automation CRUD/persistence owner, including account-scoped reload, "
            "but it does not yet perform the success-terminal projection; the real Host path must be "
            "extended rather than adding a renderer/facade owner."
        )

        contract = rows["source/host/tests/transcript_manager_contract.rs"]
        contract["desktop_responsibility"] = (
            "Focused production contract for single transcript composition ownership, lifecycle "
            "settlement, and active-Agent-only automation projection from canonical stored automation state."
        )
        contract["desktop_visible_effect"] = (
            "Regression evidence fails if active-Agent automations are not projected, if inactive-Agent "
            "automations leak to the surface, or if projection bypasses the canonical transcript/roster path."
        )
        contract["notes"] += (
            " Revalidated against Desktop PR #20 b5f8855805ec1c0be3a821cf35a4cba047ee9d8b. "
            "The new Desktop contract creates canonical stored automation state, proves an active Agent "
            "emits channel=automations with agentId/name, then proves an inactive Agent returns false and "
            "emits nothing. Equivalent iOS focused evidence must additionally cover success-only terminal "
            "timing, duplicate terminal suppression, session switch, and persisted-state recovery before "
            "this row can advance."
        )

    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")

ledger_index["source"]["commit"] = NEW
ledger_index_path.write_text(json.dumps(ledger_index, ensure_ascii=False, indent=2) + "\n")

checker_path = Path("scripts/check-desktop-pr20-ios-architecture.py")
checker = checker_path.read_text()
needle = f'EXPECTED_DESKTOP_COMMIT = "{OLD}"'
if needle not in checker:
    raise SystemExit("strict checker old authority missing")
checker_path.write_text(checker.replace(needle, f'EXPECTED_DESKTOP_COMMIT = "{NEW}"', 1))

spec_path = Path("docs/specs/fabushi-desktop-pr20-ios-architecture-parity.md")
spec = spec_path.read_text()
spec = spec.replace("Last updated: 2026-10-02", "Last updated: 2026-10-03", 1)
old_pin = f"- pinned source commit for this baseline: \`{OLD}\`"
new_pin = f"- pinned source commit for this baseline: \`{NEW}\`"
if old_pin not in spec:
    raise SystemExit("active Spec old pin missing")
spec = spec.replace(old_pin, new_pin, 1)
if "### 1.8 Exact-HEAD rebaseline" in spec:
    raise SystemExit("Spec 1.8 already exists")
section = """### 1.8 Exact-HEAD rebaseline: 2026-10-03 / \`b5f8855805ec1c0be3a821cf35a4cba047ee9d8b\`

Desktop PR #20 advanced one commit from \`827f22da7c527ab22df0700303f356d589c2a0f4\` to \`b5f8855805ec1c0be3a821cf35a4cba047ee9d8b\` in \`source/host/app/src/main.rs\`, \`source/host/src/extensions/transcript/roster_emit.rs\`, \`source/host/src/extensions/transcript/transcript_manager.rs\`, and \`source/host/tests/transcript_manager_contract.rs\`. A fresh recursive Git-tree comparison confirms that the selected \`frontend/** + source/**\` inventory is still exactly 7,926 blobs with no added, removed, or stale paths. All manifest/ledger chunks, both indexes, the strict checker, and the four changed Desktop blob identities are rebound to this exact HEAD before iOS production work continues. Three pre-existing source-host manifest size fields whose blob identities did not change are also corrected from the current Desktop Git tree; they do not represent new upstream responsibilities.

The new normative responsibility is a success-terminal automation refresh owned entirely by the Host transcript composition. After a routed provider turn has completed its result settlement successfully, shipping Host calls \`TranscriptManager.emit_automations(agent_id)\`; failed routed turns do not call it. The manager reads the current Agent automation records through its canonical \`AutomationRuntime\`/session-store owner and passes only the resulting projection to \`ProductionRosterEmit\`. The roster surface re-reads the canonical active Agent at emission time and emits \`automations { agentId, automations }\` only when the completed turn's Agent is still active. Therefore a Session/Agent switch between dispatch and terminal settlement suppresses the stale projection. Projection failure does not rewrite the already settled turn result.

This ownership also defines the duplicate/recovery rules that the iOS adaptation must preserve. A successful turn may cause at most one terminal-adjacent automation snapshot for its owned operation identity; duplicate/late terminal observation must not re-project it. Interruption/provider failure must not project a success snapshot. Relaunch/recovery must source the snapshot from durable Host automation state after account/session restoration rather than a renderer cache. The renderer may consume the Agent-tagged projection but may not decide which automation state is canonical or whether the turn qualifies.

Current iOS audit at \`1ab164e064183473110194fdd33c1de39e831da4\`: \`FeatureHostController\` is already the single Host automation CRUD owner; account-scoped automation persistence is reloaded on restored authentication, and the Host owns both \`operation_agents\` identity and \`ConversationSessionState.active_conversation_id\`. However, the normal \`RuntimeEvent::OperationCompleted\` path currently removes \`operation_agents\` and returns \`operation.completed\` without publishing an Agent-tagged automation snapshot. Failure/interruption paths likewise terminate without such a snapshot, which is correct for failure but exposes the missing success behavior. This is a real shipping-path gap, not a documentation gap. The iOS fix must extend the canonical Rust Host terminal path, carry Agent identity in the projection, gate it against the Host-owned active conversation/Agent mapping at terminal time, and consume the operation-to-Agent identity so duplicate terminal events cannot duplicate the projection. No SwiftUI/renderer fallback or second automation store is permitted.

The four affected ledger rows remain \`mapped\` through this rebaseline. They may advance only after the iOS production path and focused contracts prove success-only active-Agent projection, inactive/session-switch suppression, duplicate-terminal suppression, failed/interrupted suppression, and persisted automation reload semantics, followed by same-iOS-HEAD required CI.

"""
marker = "## 2. Product goal"
if marker not in spec:
    raise SystemExit("Spec product-goal marker missing")
spec_path.write_text(spec.replace(marker, section + marker, 1))

# Static rebaseline integrity: full authority + exact affected identities; no status promotion.
manifest_index = json.loads(Path("manifests/desktop-pr20-reference-index.json").read_text())
if manifest_index["authority"]["commit"] != NEW or manifest_index["fileCount"] != 7926:
    raise SystemExit("manifest index authority/count mismatch")
for group in manifest_index["groups"]:
    payload = json.loads(Path(group["path"]).read_text())
    if payload["sourceCommit"] != NEW:
        raise SystemExit(f"manifest chunk not rebound: {group['path']}")
for chunk in ledger_index["chunks"]:
    payload = json.loads(Path(chunk["path"]).read_text())
    if payload["sourceCommit"] != NEW:
        raise SystemExit(f"ledger chunk not rebound: {chunk['path']}")
host_manifest = json.loads(Path("manifests/desktop-pr20/source-host.json").read_text())
manifest_rows = {row["path"]: row for row in host_manifest["files"]}
for source_path, blob_sha in changed.items():
    if manifest_rows[source_path]["blobSha"] != blob_sha:
        raise SystemExit(f"manifest blob mismatch: {source_path}")
host_ledger = json.loads(Path("docs/parity/desktop-pr20/source-host.json").read_text())
ledger_rows = {row["desktop_path"]: row for row in host_ledger["rows"]}
for source_path, blob_sha in changed.items():
    row = ledger_rows[source_path]
    if row["desktop_blob_sha"] != blob_sha or row["implementation_status"] != "mapped":
        raise SystemExit(f"ledger affected row mismatch: {source_path}")
if NEW not in checker_path.read_text() or NEW not in spec_path.read_text():
    raise SystemExit("checker/spec authority mismatch")
print("rebaseline-static-integrity: ok")
