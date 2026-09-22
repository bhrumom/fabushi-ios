#!/usr/bin/env python3
import argparse
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_REFERENCE = "a9f633e09d49a85829b8236331b9e21f7e612634"
EXPECTED_FILES = 2046
VALID_STATUSES = {"mapped", "implemented", "verified", "not-applicable"}

parser = argparse.ArgumentParser()
parser.add_argument("--strict", action="store_true")
parser.add_argument("--complete", action="store_true", help="require every Grok row to be verified or explicitly not-applicable")
args = parser.parse_args()

errors = []
warnings = []

manifest_path = ROOT / "manifests/grok-bot-0.18-reference-files.json"
ledger_path = ROOT / "docs/parity/grok-bot-0.18-ios-parity-ledger.csv"
manifest = json.loads(manifest_path.read_text())
if manifest["reference"]["commit"] != EXPECTED_REFERENCE:
    errors.append("reference commit drift")
if manifest["fileCount"] != EXPECTED_FILES or len(manifest["files"]) != EXPECTED_FILES:
    errors.append("reference manifest is not complete")

with ledger_path.open(newline="", encoding="utf-8") as handle:
    rows = [row for row in csv.DictReader(line for line in handle if not line.startswith("#"))]
if len(rows) != EXPECTED_FILES:
    errors.append(f"parity ledger has {len(rows)} rows, expected {EXPECTED_FILES}")
paths = [row["grok_path"] for row in rows]
if len(set(paths)) != EXPECTED_FILES:
    errors.append("parity ledger contains duplicate Grok paths")
if set(paths) != {row["path"] for row in manifest["files"]}:
    errors.append("ledger and pinned reference manifest differ")

status_counts = Counter()
materialized = 0
for row in rows:
    status = row["implementation_status"].strip()
    target = row["ios_target_path"].strip()
    target_exists = bool(target) and (ROOT / target).is_file()
    status_counts[status] += 1
    materialized += int(target_exists)

    if status not in VALID_STATUSES:
        errors.append(f"{row['grok_path']}: invalid implementation_status={status!r}")
        continue
    if status in {"implemented", "verified"} and not target_exists:
        errors.append(f"{row['grok_path']}: {status} target is missing: {target}")
    if status == "verified" and not row["test_evidence"].strip():
        errors.append(f"{row['grok_path']}: verified row has no test_evidence")
    if status == "not-applicable" and not row["adaptation_reason"].strip():
        errors.append(f"{row['grok_path']}: not-applicable row has no adaptation_reason")
    if args.complete and status not in {"verified", "not-applicable"}:
        errors.append(f"{row['grok_path']}: completion gate still has status={status}")

required = [
    "frontend/src/production/ProductionRenderer.view.swift",
    "frontend/src/production/FabushiSceneRoot.swift",
    "frontend/src/production/GrokMobileShell.swift",
    "frontend/src/production/GrokMobileShell+Semantic.swift",
    "frontend/src/production/GrokMobileShell+Home.swift",
    "frontend/src/production/GrokMobileShell+Bots.swift",
    "frontend/src/production/GrokMobileBotService.swift",
    "frontend/src/recovered/features/app-shell/ContentView.swift",
    "source/ios-main/IOSMainRuntime.swift",
    "source/ios-main/background-transfer/ios-background-transfer-service.swift",
    "source/ios-main/adapters/ios-native-local-capability-backend.swift",
    "source/ios-main/auth/ios-passkey-provider.swift",
    "source/ios-main/deep-link/deep-link-controller.swift",
    "source/ios-main/lifecycle/ios-lifecycle-recovery.swift",
    "source/ios-main/telemetry/desktop-lifecycle-telemetry.swift",
    "source/ios-main/FabushiRuntime.swift",
    "source/ios-preload/preload.swift",
    "source/ios-preload/coordinator-port-bridge.swift",
    "source/ios-preload/box-vnc-clipboard-paste.swift",
    "source/ios-preload/box-vnc-liveness.swift",
    "source/ios-preload/box-vnc-visibility-gate.swift",
    "source/ios-preload/main-rpc-runtime.swift",
    "source/ios-preload/passkey-stall.swift",
    "source/ios-preload/preload-browser-base.swift",
    "source/ios-preload/preload-dev-controls.swift",
    "source/ios-preload/preload-vnc.swift",
    "source/ios-preload/preload-webview.swift",
    "source/ios-preload/rpc-edge-runtime.swift",
    "source/ios-preload/runtime/DevControlsPreloadEntrypoint.swift",
    "source/ios-preload/runtime/primary.swift",
    "source/ios-preload/runtime/VNCPreloadEntrypoint.swift",
    "source/ios-preload/runtime/webview.swift",
    "source/local-exec-daemon/invariant-violation-log.swift",
    "source/local-exec-daemon/production-executor.swift",
    "source/box-exec-daemon/cli.swift",
    "source/box-exec-daemon/server.swift",
    "source/mime-types.types.swift",
    "source/internal/host-extensions.rs",
    "source/internal/scheduling.rs",
    "source/shared/media/attachment-limits.swift",
    "source/shared/media/attachment-open-policy.swift",
    "source/shared/media/attachment-preview.swift",
    "source/shared/media/attachment-summary.swift",
    "source/shared/media/attachments.swift",
    "source/shared/media/avatar-image.swift",
    "source/shared/media/file-preview-kind.swift",
    "source/shared/media/image-dimensions.swift",
    "source/shared/media/image-mime.swift",
    "source/shared/media/markdown-preview.swift",
    "source/shared/media/media-extensions.swift",
    "source/shared/media/video-dimensions.swift",
    "source/shared/desktop.swift",
    "source/shared/deep-link.swift",
    "source/shared/external-url-policy.swift",
    "source/shared/link-preview-policy.swift",
    "source/shared/retry-after.swift",
    "source/shared/product-name.swift",
    "source/shared/update-track.swift",
    "source/shared/timezone.swift",
    "source/shared/system-errno.swift",
    "source/shared/vnc-liveness.swift",
    "source/shared/vnc-viewer-visibility.swift",
    "source/shared/message-reference.swift",
    "source/shared/ordering.swift",
    "source/shared/send-acceptance.swift",
    "source/shared/send-message-preview.swift",
    "source/shared/sidebar-sections.swift",
    "source/shared/sand-text.swift",
    "source/shared/usage.swift",
    "source/shared/write-epoch.swift",
    "source/ios-dev-controls/IOSDevControls.swift",
    "source/mahayana-agent-coordinator/MahayanaCoordinator.swift",
    "source/mahayana-agent-coordinator/local-host-supervisor.swift",
    "source/mahayana-agent-coordinator/renderer-port-server.swift",
    "source/mahayana-agent-coordinator/control-port-client.swift",
    "source/host/MahayanaHostRuntime.swift",
    "source/host/process-crash-guard.rs",
    "source/host/notify-drain-gate.rs",
    "source/host/mcp-auth/mcp-auth-wait-registry.rs",
    "source/local-exec-daemon/LocalCapabilityRunner.swift",
    "source/box-exec-daemon/RemoteRunner.swift",
    "source/shared/rpc/coordinator-port.swift",
    "source/shared/rpc/coordinator.swift",
    "source/shared/rpc/SharedRPCContracts.swift",
]
for relative in required:
    if not (ROOT / relative).is_file():
        errors.append(f"missing architecture root file: {relative}")

preload = (ROOT / "source/ios-preload/preload.swift").read_text()
for forbidden in ["CoordinatorControlPortClient", "main.dispatch("]:
    if forbidden in preload:
        errors.append(f"iOS preload bypasses renderer coordinator-port boundary: {forbidden}")
if "IOSCoordinatorPortClient" not in preload:
    errors.append("iOS preload does not use its renderer-facing coordinator-port client")




background_transfer = (ROOT / "source/ios-main/background-transfer/ios-background-transfer-service.swift").read_text()
for required_token in [
    "URLSessionConfiguration.background",
    "sessionSendsLaunchEvents = true",
    "handleEvents(",
    "urlSessionDidFinishEvents",
]:
    if required_token not in background_transfer:
        errors.append(f"background-transfer lifecycle is incomplete: {required_token}")

passkey_provider = (ROOT / "source/ios-main/auth/ios-passkey-provider.swift").read_text()
for required_token in [
    "ASAuthorizationPlatformPublicKeyCredentialProvider",
    "ASAuthorizationController",
    "allowedRelyingPartyIDs",
]:
    if required_token not in passkey_provider:
        errors.append(f"native iOS passkey provider is incomplete: {required_token}")

coordinator_runtime = (ROOT / "source/mahayana-agent-coordinator/MahayanaCoordinator.swift").read_text()
for required_token in [
    "MahayanaLocalHostSupervisor",
    "observedHostGeneration",
    "recoverAfterFailure",
]:
    if required_token not in coordinator_runtime:
        errors.append(f"MahayanaCoordinator is missing fail-closed Host recovery: {required_token}")

local_host_supervisor = (ROOT / "source/mahayana-agent-coordinator/local-host-supervisor.swift").read_text()
for required_token in [
    "observedGeneration == generation",
    "recoveryCount",
    "factory()",
]:
    if required_token not in local_host_supervisor:
        errors.append(f"local Host supervisor is missing generation recovery: {required_token}")

runtime = (ROOT / "source/ios-main/FabushiRuntime.swift").read_text()
for required_token in ["IOSDeepLinkController", "resyncAfterLifecycleRecovery", "resumeAfterBackground"]:
    if required_token not in runtime:
        errors.append(f"FabushiRuntime is missing production lifecycle/deep-link integration: {required_token}")

ios_main = (ROOT / "source/ios-main/IOSMainRuntime.swift").read_text()
for required_token in ["IOSLifecycleRecoveryStore", "lifecycleReporter", "markResyncCompleted"]:
    if required_token not in ios_main:
        errors.append(f"IOSMainRuntime is missing lifecycle recovery integration: {required_token}")

app = (ROOT / "mobile/ios/Fabushi/FabushiApp.swift").read_text()
for forbidden in ["MahayanaHost", "MahayanaCoordinator", "MarketplaceModel(", "MessagingModel("]:
    if forbidden in app:
        errors.append(f"FabushiApp owns runtime responsibility: {forbidden}")

if "FabushiSceneRoot()" not in app:
    errors.append("FabushiApp does not delegate scene composition to FabushiSceneRoot")
for forbidden in [".task", ".onChange", ".onOpenURL", "NotificationCenter", "FabushiRuntime("]:
    if forbidden in app:
        errors.append(f"FabushiApp still owns scene/runtime orchestration: {forbidden}")
if len(app.splitlines()) > 24:
    errors.append("FabushiApp has regrown beyond thin App/Scene composition")

shell_path = ROOT / "frontend/src/production/GrokMobileShell.swift"
shell = shell_path.read_text()
if len(shell.splitlines()) > 120:
    errors.append("GrokMobileShell has regrown into a monolithic renderer/runtime file")
for shell_part in (ROOT / "frontend/src/production").glob("GrokMobileShell*.swift"):
    shell_part_text = shell_part.read_text()
    for forbidden in ["bridge.request(", "feature.execute", "feature.receive"]:
        if forbidden in shell_part_text:
            errors.append(
                f"SwiftUI shell owns protocol/runtime I/O ({forbidden}): "
                f"{shell_part.relative_to(ROOT)}"
            )
if "appAgentSurface.publish(" in shell:
    errors.append("GrokMobileShell main file owns semantic-surface publication")

for path in (ROOT / "mobile/ios/Fabushi").glob("*.swift"):
    if path.name == "MahayanaHost.swift":
        continue
    text = path.read_text()
    if "MahayanaHost" in text:
        errors.append(f"presentation/platform source bypasses coordinator through Host: {path.relative_to(ROOT)}")

for root in ["source/box-exec-daemon", "source/local-exec-daemon"]:
    for path in (ROOT / root).rglob("*.swift"):
        text = path.read_text()
        for forbidden in ["Process(", "NSTask", "posix_spawn", "/bin/sh", "/bin/bash"]:
            if forbidden in text:
                errors.append(f"iOS runner emulates forbidden desktop process semantics ({forbidden}): {path.relative_to(ROOT)}")

for root in ["source/box-exec-daemon", "source/local-exec-daemon", "source/host"]:
    for path in (ROOT / root).rglob("*.swift"):
        text = path.read_text()
        if "IOSPreloadBridge" in text:
            errors.append(f"lower runtime layer depends on renderer preload bridge: {path.relative_to(ROOT)}")

# Swift requires source basenames to be unique inside one compilation target.
# Grok's repeated main.ts/view.tsx names are mapped to semantic iOS filenames
# unless/until those folders become separate Swift modules.
compiled_roots = [
    ROOT / "mobile/ios/Fabushi",
    ROOT / "frontend",
    ROOT / "source/internal",
    ROOT / "source/shared",
    ROOT / "source/ios-dev-controls",
    ROOT / "source/ios-main",
    ROOT / "source/ios-preload",
    ROOT / "source/mahayana-agent-coordinator",
    ROOT / "source/local-exec-daemon",
    ROOT / "source/box-exec-daemon",
]
by_basename = defaultdict(list)
for root in compiled_roots:
    if not root.exists():
        continue
    for path in root.rglob("*.swift"):
        by_basename[path.name].append(path.relative_to(ROOT))
for basename, duplicates in sorted(by_basename.items()):
    if len(duplicates) > 1:
        errors.append(
            f"Swift filename collision in app target ({basename}): "
            + ", ".join(str(path) for path in duplicates)
        )

project = (ROOT / "mobile/ios/project.yml").read_text()
for required_source in [
    "../../frontend",
    "../../source/internal",
    "../../source/mime-types.types.swift",
    "../../source/shared",
    "../../source/ios-dev-controls",
    "../../source/ios-main",
    "../../source/ios-preload",
    "../../source/mahayana-agent-coordinator",
    "../../source/host/MahayanaHostRuntime.swift",
]:
    if required_source not in project:
        errors.append(f"XcodeGen target does not compile {required_source}")
if "$(SRCROOT)/Frameworks" in project:
    errors.append("opaque Frameworks runtime remains in production library path")

runtime_manifest = ROOT / "source/packages/mahayana-rs/Cargo.toml"
mobile_ffi = ROOT / "source/packages/mahayana-rs/mahayana-app-host-mobile/src/lib.rs"
internal_host_extensions = ROOT / "source/internal/host-extensions.rs"
internal_scheduling = ROOT / "source/internal/scheduling.rs"
if internal_host_extensions.is_file() and internal_scheduling.is_file() and mobile_ffi.is_file():
    mobile_ffi_text = mobile_ffi.read_text()
    for required_module in [
        "internal/host-extensions.rs",
        "internal/scheduling.rs",
        "host/process-crash-guard.rs",
        "host/notify-drain-gate.rs",
        "host/mcp-auth/mcp-auth-wait-registry.rs",
        "host/agent-isolation/conversation-blob-db.rs",
        "host/agent-isolation/conversation-blob-gc.rs",
        "host/agent-isolation/legacy-blob-retirement.rs",
        "host/agent-isolation/conversation-blob-store.rs",
        "host/agent-isolation/agent-store-worker.rs",
        "host/agent-isolation/agent-worker-pool.rs",
        "host/agent-isolation/worker-blob-store.rs",
        "host/agent-isolation/transcript-mirror-offload.rs",
        "host/agent-isolation/transcript-mirror-worker.rs",
        "host/transcript-mirror/conversation-state-binary.rs",
        "host/transcript-mirror/generated-occurrence-codec.rs",
        "host/transcript-mirror/transcript-journal-codec.rs",
        "host/transcript-mirror/transcript-mirror-router.rs",
        "host/transcript-mirror/transcript-occurrence-deriver.rs",
        "host/transcript-mirror/transcript-mirror.rs",
        "host/transcript-mirror/legacy-transcript-mirror.rs",
        "host/extensions/extension-ids.generated.rs",
        "host/extensions/session/session-diagnostics.rs",
        "host/extensions/telemetry/send-trace-sampler.rs",
        "host/host-diagnostics.rs",
        "host/ports/product-analytics.rs",
        "host/ports/sand-analytics-types.rs",
        "host/ports/transport.rs",
        "host/ports/user-computer.rs",
        "host/runner/clock-skew-guard.rs",
        "host/runner/video-container.rs",
        "host/sand-user-identity.rs",
        "host/selected-image-inputs.rs",
        "host/transcript-mutation-events.rs",
    ]:
        if required_module not in mobile_ffi_text:
            errors.append(f"iOS-owned Rust internal module is not compiled by mobile host: {required_module}")

if not runtime_manifest.is_file() or not mobile_ffi.is_file():
    message = "iOS-owned Mahayana Rust source import is not complete"
    (errors if args.strict else warnings).append(message)

for legacy in [
    "mobile/ios/Fabushi/MahayanaHost.swift",
    "mobile/native/include/mahayana_app_host.h",
    "mobile/ios/Fabushi/GrokMobileShell.swift",
    "mobile/ios/Fabushi/ContentView.swift",
    "source/ios-main/main.swift",
    "source/ios-dev-controls/main.swift",
    "source/mahayana-agent-coordinator/main.swift",
    "source/local-exec-daemon/main.swift",
    "source/box-exec-daemon/main.swift",
    "source/shared/rpc/main.swift",
]:
    if args.strict and (ROOT / legacy).exists():
        errors.append(f"legacy or collision-prone source still exists: {legacy}")

print(
    "INFO: parity materialized="
    f"{materialized}/{EXPECTED_FILES} status="
    + ",".join(f"{key}:{status_counts[key]}" for key in sorted(status_counts))
)
if warnings:
    for warning in warnings:
        print(f"WARNING: {warning}")
if errors:
    for error in errors:
        print(f"ERROR: {error}")
    raise SystemExit(1)
print(
    f"PASS: Grok iOS architecture ledger={len(rows)} "
    f"reference={EXPECTED_REFERENCE} strict={args.strict} complete={args.complete}"
)
