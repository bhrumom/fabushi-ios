#!/usr/bin/env python3
import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_REFERENCE = "a9f633e09d49a85829b8236331b9e21f7e612634"
EXPECTED_FILES = 2046

parser = argparse.ArgumentParser()
parser.add_argument("--strict", action="store_true")
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

required = [
    "frontend/production/ProductionRenderer.swift",
    "source/ios-main/IOSMainRuntime.swift",
    "source/ios-main/FabushiRuntime.swift",
    "source/ios-preload/IOSPreloadBridge.swift",
    "source/mahayana-agent-coordinator/MahayanaCoordinator.swift",
    "source/host/MahayanaHostRuntime.swift",
    "source/local-exec-daemon/LocalCapabilityRunner.swift",
    "source/box-exec-daemon/RemoteRunner.swift",
    "source/shared/rpc/CoordinatorPort.swift",
]
for relative in required:
    if not (ROOT / relative).is_file():
        errors.append(f"missing architecture root file: {relative}")

app = (ROOT / "mobile/ios/Fabushi/FabushiApp.swift").read_text()
for forbidden in ["MahayanaHost", "MahayanaCoordinator", "MarketplaceModel(", "MessagingModel("]:
    if forbidden in app:
        errors.append(f"FabushiApp owns runtime responsibility: {forbidden}")

for path in (ROOT / "mobile/ios/Fabushi").glob("*.swift"):
    if path.name == "MahayanaHost.swift":
        continue
    text = path.read_text()
    if "MahayanaHost" in text:
        errors.append(f"presentation/platform source bypasses coordinator through Host: {path.relative_to(ROOT)}")

project = (ROOT / "mobile/ios/project.yml").read_text()
for required_source in [
    "../../frontend",
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
if not runtime_manifest.is_file() or not mobile_ffi.is_file():
    message = "iOS-owned Mahayana Rust source import is not complete"
    (errors if args.strict else warnings).append(message)

if args.strict and (ROOT / "mobile/ios/Fabushi/MahayanaHost.swift").exists():
    errors.append("legacy mobile/ios MahayanaHost.swift still exists")
if args.strict and (ROOT / "mobile/native/include/mahayana_app_host.h").exists():
    errors.append("legacy mobile/native header still exists")

if warnings:
    for warning in warnings:
        print(f"WARNING: {warning}")
if errors:
    for error in errors:
        print(f"ERROR: {error}")
    raise SystemExit(1)
print(f"PASS: Grok iOS architecture ledger={len(rows)} reference={EXPECTED_REFERENCE} strict={args.strict}")
