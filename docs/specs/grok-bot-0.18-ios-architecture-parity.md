# Grok Bot 0.18 → Fabushi iOS Standalone Architecture & Behavior Parity — Specification

Status: active  
Owner: Fabushi iOS  
Last updated: 2026-09-22  
Related issue/task/PR: user-requested iOS architecture parity migration; implementation PRs TBD

## 1. Context / problem

Fabushi iOS is currently implemented primarily under `mobile/ios/Fabushi` as a native SwiftUI application, with a native Mahayana host bridge and several large presentation/runtime files.

At the discovery baseline:

- `ContentView.swift` is a very large multi-feature screen/controller surface;
- `GrokMobileShell.swift` combines Grok-style presentation with bot/runtime interaction;
- `FabushiApp.swift` directly creates and coordinates `MahayanaHost`, Marketplace, Messaging, the app-agent surface, deep links, and the remote-device gateway;
- `MahayanaHost.swift` directly wraps `libmahayana_app_host` through the bridging header;
- `FabushiRemoteDeviceGateway.swift` directly owns account-scoped WebSocket transport and depends on `MahayanaHost`;
- the XcodeGen project is app-centric under `mobile/ios`, rather than expressing Grok-equivalent renderer/main/preload/coordinator/host/runner boundaries.

The requested target is not a Grok-inspired iOS skin and not a thin iOS client around shared cross-platform source. The target is a **standalone iOS implementation** whose architecture, module boundaries, contracts, lifecycle behavior, and observable product effects correspond module-by-module to the pinned Grok Bot 0.18 reconstructed reference, while using the best iOS-native implementation technique for each responsibility.

Reference baselines:

- Grok reference repository: `b-nnett/grok-bot-0.18-reconstructed`
- Grok pinned reference commit: `a9f633e09d49a85829b8236331b9e21f7e612634`
- Fabushi iOS repository: `bhrumom/fabushi-ios`
- Fabushi iOS discovery baseline: `d5ec44c14810de173f3584d1e72b067e8cd5fce2`

The Grok repository states that it is an unofficial reconstruction and that no upstream source-code license is asserted or granted. It is therefore used as an architecture, protocol, behavior, and evidence baseline. The migration must reproduce responsibilities and effects without assuming permission to bulk-copy reconstructed implementation text.

## 2. Architectural decision

### 2.1 Standalone iOS ownership

**Fabushi iOS must be self-contained.**

The iOS repository owns its complete product implementation, including:

- SwiftUI renderer/UI;
- iOS application/platform lifecycle;
- iOS trusted bridge;
- Mahayana Coordinator;
- Mahayana Host;
- local Runner capability layer;
- remote/box execution adapter;
- `source/shared/**` contracts/policies used by iOS;
- `source/packages/**` agent/runtime packages used by iOS;
- persistence and transcript;
- MCP/connectors;
- auth/OAuth/passkeys;
- inference routing;
- telemetry/observability;
- StoreKit/entitlement platform integration;
- Xcode/SPM/Cargo/build tooling;
- tests, CI, signing, TestFlight, and App Store delivery.

A clean checkout of `bhrumom/fabushi-ios` must not require checkout of another Fabushi source repository to build, test, package, or run.

If Rust is used for Coordinator/Host/Runner/runtime behavior, the corresponding Rust source and reproducible build configuration required by iOS must live in this repository. A checked-in header plus a library produced only by another Fabushi repository is not sufficient as the final architecture.

### 2.2 Best iOS effect is the priority

Implementation choices are made for the best iOS result:

- responsiveness;
- streaming latency;
- lifecycle correctness;
- battery/CPU behavior;
- memory pressure behavior;
- crash recovery;
- native interaction quality;
- accessibility;
- security;
- maintainability of the Grok-equivalent architecture.

### 2.3 Language is not the goal

Choose the best language/runtime per boundary:

- SwiftUI/Swift for iOS renderer and Apple platform APIs;
- Swift/Objective-C/C bridging where Apple/native library integration requires it;
- Rust for Coordinator/Host/Runner/runtime modules when it provides the best correctness, performance, determinism, or isolation;
- Metal/Core Animation/AVFoundation/WebKit/AuthenticationServices/StoreKit/etc. where they are the correct platform implementation;
- no Node.js or Electron requirement merely because the desktop reference uses them.

Architecture and effect correspondence are mandatory; source language correspondence is not.

## 3. Goal

Rebuild Fabushi iOS into this standalone Grok-corresponding architecture:

```
frontend/
    │
    ▼
source/ios-preload/
    │
    ▼
source/ios-main/
    │
    ▼
source/mahayana-agent-coordinator/
    │
    ▼
source/host/
    │
    ├── MCP / connectors / tools
    ├── inference / agents
    ├── transcript / workflows / automations
    └── runner composition
             │
       ┌─────┴─────┐
       ▼           ▼
source/local-   source/box-
exec-daemon/   exec-daemon/
```

The migration must:

1. enumerate every relevant Grok file under `source/**` and `frontend/**`;
2. map every item to an iOS-local counterpart;
3. preserve equivalent responsibility and contract behavior;
4. make the physical repository structure correspond to Grok's module tree;
5. preserve Coordinator / Host / Runner / trusted-bridge boundaries;
6. make SwiftUI consume coordinator projections and emit typed intents rather than own runtime orchestration;
7. reproduce supported Grok interactions and runtime effects with iOS-native behavior;
8. remove superseded legacy iOS architecture after cutover;
9. prove the result using exact-HEAD CI and a packaged iOS app/TestFlight-quality build;
10. verify lifecycle restoration across scene recreation, background suspension, memory pressure, termination/relaunch, and deep-link/OAuth return.

The final product must feel like the iOS edition of the same Grok architecture, not a separate mobile product that only resembles Grok visually.

## 4. Non-goals / out of scope

- Do not embed Electron in iOS.
- Do not add Node.js solely to match Grok's implementation language.
- Do not preserve another Fabushi source repository as a required runtime dependency.
- Do not keep the current `mobile/ios` layout as the final architecture merely because it already exists.
- Do not flatten Grok modules into a handful of giant Swift files.
- Do not emulate desktop-only operating-system capabilities that iOS explicitly prohibits.
- Do not introduce arbitrary shell/process execution on iOS.
- Do not require pixel-identical desktop geometry on iPhone/iPad; preserve interaction semantics, information architecture, state behavior, visual language, and animation intent responsively.
- Do not use a primary WKWebView shell as a shortcut for native renderer parity.
- Do not keep two production coordinators, transcript truths, auth truths, or execution paths after cutover.
- Do not bulk-copy reconstructed source text without explicit rights review.
- Do not include a code-reuse/DRY optimization policy in this architecture Spec.

## 5. Requirements

### R1 — Complete file-level parity ledger

Before implementation changes beyond scaffolding, generate and maintain a parity ledger for every file under the pinned Grok reference:

- `source/**`
- `frontend/**`

Each row must include:

- Grok path;
- Grok responsibility;
- evidence/contract anchor;
- iOS target path;
- target language/runtime;
- parity class: `direct-equivalent`, `ios-adapted`, or `not-applicable`;
- implementation status;
- test/evidence;
- current iOS path replaced/removed.

There is no `shared-core` disposition. iOS implementation belongs to this repository.

No Grok module may silently disappear. `not-applicable` requires an iOS-specific platform reason and reviewer acceptance.

### R2 — Physical directory structure parity

The final repository must mirror Grok's major source organization, with explicit iOS substitutions only where platform naming requires them.

| Grok Bot 0.18 | Fabushi iOS target |
| --- | --- |
| `frontend/` | `frontend/` |
| `source/electron-main/` | `source/ios-main/` |
| `source/electron-preload/` | `source/ios-preload/` |
| `source/electron-dev-controls/` | `source/ios-dev-controls/` |
| `source/node-agent-coordinator/` | `source/mahayana-agent-coordinator/` |
| `source/host/` | `source/host/` |
| `source/local-exec-daemon/` | `source/local-exec-daemon/` |
| `source/box-exec-daemon/` | `source/box-exec-daemon/` |
| `source/internal/` | `source/internal/` |
| `source/packages/` | `source/packages/` |
| `source/shared/` | `source/shared/` |
| `tests/` | `tests/` |
| `scripts/` | `scripts/` |
| `manifests/` | `manifests/` |
| `docs/` | `docs/` |

The same rule applies recursively.

Example:

```
Grok:
source/electron-main/auth/
source/electron-main/attachments/
source/electron-main/coordinator/
source/electron-main/mcp/
source/electron-main/media/
source/electron-main/notifications/
source/electron-main/prefs/
source/electron-main/secrets/
source/electron-main/startup/
source/electron-main/telemetry/
source/electron-main/update/
source/electron-main/vnc/

iOS:
source/ios-main/auth/
source/ios-main/attachments/
source/ios-main/coordinator/
source/ios-main/mcp/
source/ios-main/media/
source/ios-main/notifications/
source/ios-main/prefs/
source/ios-main/secrets/
source/ios-main/startup/
source/ios-main/telemetry/
source/ios-main/update/
source/ios-main/vnc/
```

Xcode/SPM/Cargo structure must adapt to these architecture boundaries rather than forcing all responsibilities into a single app target source directory.

Any target-path divergence requires a documented technical reason in the parity ledger.

### R3 — Grok boundary parity

The target must preserve:

- renderer/UI;
- trusted bridge;
- platform/main lifecycle owner;
- coordinator;
- host;
- runner/local capability execution;
- remote/box execution;
- local shared contracts/policies;
- MCP/connectors;
- auth/OAuth/passkeys;
- persistence/telemetry/observability.

Direct layer bypasses are forbidden.

### R4 — Mahayana Coordinator

`source/mahayana-agent-coordinator/**` is the iOS counterpart of Grok `source/node-agent-coordinator/**`.

It must own:

- renderer port lifecycle;
- request/reply correlation;
- ordered event fan-out;
- streaming turn activity;
- cancellation;
- reconnect/resync;
- transcript routing;
- client-side tool relay;
- gateway routing;
- inference routing;
- local capability routing;
- routed MCP bridge;
- OAuth forwarding;
- passkey/WebAuthn mediation where applicable;
- telemetry/request lineage;
- Host supervision;
- crash settlement;
- deterministic terminal states.

Initial submodule correspondence:

| Grok | iOS |
| --- | --- |
| `carrier.ts` | coordinator carrier/transport |
| `client-side-tool-v2-relay.ts` | client-side tool relay |
| `control-port-client.ts` | control-port client |
| `gateway/**` | `gateway/**` |
| `inference-router.ts` | inference router |
| `local-exec/**` | local capability/runner routing |
| `main.ts` | Coordinator assembly/bootstrap |
| `oauth/**` | `oauth/**` |
| `renderer-port-server.ts` | iOS renderer-port server |
| `routed-mcp-bridge.ts` | routed MCP bridge |
| `telemetry/**` | `telemetry/**` |
| `webauthn/**` | AuthenticationServices/passkey counterpart |

SwiftUI Models/Views must not independently recreate coordinator behavior.

### R5 — Mahayana Host

`source/host/**` is iOS-owned and sits behind Coordinator.

It must map **iOS-relevant** Grok Host responsibilities, including:

- `agent-isolation/**`;
- `agents/**`;
- `automations/**`;
- `box/**`;
- `cloud-agents/**`;
- `connectors/**`;
- `extensions/**`;
- `groups/**`;
- `local-exec/**`;
- `mcp-auth/**`;
- `ports/**`;
- `runner/**`;
- `storage/**`;
- `transcript-mirror/**`;
- `workflows/**`;
- gateway protocol/server API;
- event bus;
- initial transcript load;
- Host single-owner/lock semantics;
- durable file policy and paths;
- roster bookkeeping;
- secret abstraction;
- request context;
- runner composition;
- diagnostics/crash guards;
- activity/user identity/trace behavior.

Host code must not own SwiftUI screens, NavigationStack state, UIKit presentation, or scene navigation.

### R6 — Runner / local-exec / remote-exec

Grok `source/local-exec-daemon/**`, `source/box-exec-daemon/**`, Host runner modules, and local-exec contracts must map to explicit iOS-local modules.

Required behavior:

- request validation;
- session/capability identity;
- permission checks;
- cancellation;
- output streaming;
- timeout;
- error normalization;
- capability advertisement;
- sandboxed local capabilities supported by iOS;
- remote-device execution;
- remote/box execution for capabilities iOS cannot perform locally.

**iOS platform restrictions are authoritative.** Arbitrary process spawning, shell execution, unrestricted filesystem access, or background daemons are not required and must not be simulated. Those Grok semantics must be represented by safe in-process capability adapters, BGTaskScheduler where appropriate, or remote Runner/box execution, with the parity ledger marking the adaptation.

### R7 — Thin iOS trusted bridge

`source/ios-preload/**` is the iOS counterpart of Grok `source/electron-preload/**`.

It must be narrow and typed, covering iOS equivalents of:

- coordinator-port bridge;
- main RPC runtime;
- RPC edge runtime;
- remote-computer/VNC liveness;
- visibility gating;
- clipboard transfer where permitted;
- WKWebView/Mini App bridge;
- passkey stall/settlement;
- dev controls;
- platform browser/auth bridge.

Free-form dictionaries/JSON must disappear from UI-facing boundaries. Raw JSON remains only at explicit wire/protocol edges.

### R8 — iOS platform-main parity

`source/ios-main/**` is the iOS counterpart of Grok `source/electron-main/**`.

`FabushiApp.swift` must cease to be the application coordinator. Its final responsibility is SwiftUI app/scene composition and forwarding platform lifecycle/openURL/scene phase events to the platform layer.

Required correspondence:

| Grok `electron-main` | iOS `ios-main` |
| --- | --- |
| `account/**` | account/session |
| `adapters/**` | Apple capability adapters |
| `attachments/**` | PhotosPicker/UIDocumentPicker/security-scoped URL handling |
| `auth/**` | AuthenticationServices/ASWebAuthenticationSession/Keychain |
| `box/**` | remote execution/computer connector |
| `coordinator/**` | Mahayana Coordinator bootstrap/ownership |
| `deep-link/**` | URL/universal-link router |
| `dev/**` | debug-only controls |
| `downloads/**` | URLSession/background transfer |
| `experiments/**` | local typed flags |
| `feedback/**` | native feedback/share surface |
| `generated/**` | generated local bindings |
| `local-exec/**` | iOS local-capability Runner integration |
| `mcp/**` | MCP lifecycle/platform integration |
| `media/**` | AVFoundation/Photos/media viewing |
| `models/**` | provider/model settings |
| `notifications/**` | UNUserNotificationCenter |
| `onepassword/**` | credential-provider counterpart or reviewed N/A |
| `prefs/**` | typed local settings |
| `process-metrics/**` | memory/thermal/runtime metrics |
| production adapters/bindings/RPC | Swift/C/Rust local production bindings |
| `secrets/**` | Keychain/Secure Enclave where appropriate |
| `startup/**` | App/scene startup |
| `telemetry/**` | iOS-local telemetry |
| `update/**` | App Store/TestFlight/version/update messaging |
| `vnc/**` | remote-computer rendering/input |
| window/chrome/shortcuts/state | scene/window/keyboard-command/navigation equivalents |

Desktop-only window behavior may be `ios-adapted` or reviewed N/A, but not silently omitted.

### R9 — Native renderer parity in `frontend/**`

`frontend/**` remains the renderer module name to correspond to Grok, but its iOS implementation is native SwiftUI (with UIKit/Metal/etc. where needed).

It must provide responsive iPhone/iPad equivalents of:

- production renderer/root shell;
- agent/bot roster/sidebar;
- conversation transcript;
- composer;
- streaming/thinking/running/completed states;
- stop/cancel;
- agent name/edit/delete;
- row actions;
- command palette/search/action dispatch;
- settings/notices;
- reactions;
- groups/members;
- attachments/media;
- MCP/connector affordances;
- remote-computer/context;
- errors/retry/recovery;
- onboarding/auth transitions.

`ContentView.swift` and `GrokMobileShell.swift` must not remain giant renderer/controller/runtime files. Renderer modules render immutable projections and emit typed intents.

### R10 — iOS-local `source/shared/**`

Grok `source/shared/**` maps to iOS-local `source/shared/**`, governed by this repository.

It must cover iOS equivalents of:

- agents;
- auth;
- automations/schedules;
- box runtime/secrets/migration;
- channels/channel messaging;
- client persistence;
- errors/retry;
- deep links;
- gateway reachability/wire;
- Host settings;
- inference router contracts;
- local capability gateway/process identity/permissions;
- MCP contracts/instructions/OAuth;
- media;
- message references;
- observability;
- ordering;
- notifications;
- persistence;
- RPC;
- transcript/threads;
- transport types;
- workflow model/workflows;
- usage;
- remote-computer/VNC liveness;
- passkey/WebAuthn gateway;
- write epoch/versioning.

### R11 — iOS-local `source/packages/**`

Every Grok package under `source/packages/**` must receive an iOS-local disposition under the corresponding `source/packages/**` tree.

Initial required set:

- `agent-analytics`
- `agent-client`
- `agent-core`
- `agent-exec`
- `agent-kv`
- `agent-store-sync`
- `agent-summarization`
- `agent-transcript`
- `agent`
- `analytics-client`
- `chat-inference-proto`
- `chat-inference`
- `constants`
- `context-rpc`
- `context`
- `cursor-config`
- `cursor-plugins`
- `git-core`
- `hooks-carriers`
- `hooks-exec`
- `hooks`
- `local-exec`
- `mcp-agent-exec`
- `mcp-core`
- `metrics`
- `prompt-jsx`
- `proto`
- `redacted-protos`
- `redaction`
- `shell-exec`
- `utils`

When a desktop package assumes shell/process/filesystem capability prohibited by iOS, keep the module responsibility explicit and implement a safe adapter or remote route. Do not silently collapse it into unrelated code.

### R12 — Feature-effect parity

For supported features, parity is measured by observable behavior and state transitions:

- request lifecycle;
- first-state/first-token responsiveness;
- incremental streaming;
- tool-call presentation/settlement;
- thinking/running/completed/failed/recovered;
- cancellation;
- reconnect/resync;
- transcript restoration;
- duplicate/out-of-order event handling;
- reactions;
- MCP/connector discovery/auth/invocation;
- OAuth return;
- passkeys;
- attachment open/upload/share;
- voice/media;
- remote-computer activity;
- error/retry;
- settings persistence;
- notifications;
- foreground/background;
- scene recreation;
- termination/relaunch.

### R13 — One iOS-local canonical truth

After cutover exactly one iOS-local owner exists for:

- auth/account;
- agent/bot roster;
- transcript/conversation;
- active operation;
- MCP/connector state;
- installed Mini App/plugin state;
- remote-device identity;
- settings;
- execution permissions;
- commerce entitlement projection.

SwiftUI Models may project/cache presentation state, but may not create a competing durable truth.

### R14 — iOS lifecycle resilience

The architecture must explicitly handle:

- scene activation/inactivation;
- background suspension;
- memory pressure;
- app termination and relaunch;
- state restoration;
- deep-link/universal-link delivery;
- OAuth callback after scene recreation;
- URLSession/background transfer completion;
- remote gateway reconnection;
- cancellation/timeout cleanup;
- no leaked native handles;
- no duplicate sends or tool calls after restoration.

A permanently stuck "thinking" state is release-blocking.

### R15 — Security and platform rules

- secrets use Keychain/Secure Enclave where appropriate;
- trusted bridge APIs are typed/allowlisted;
- WKWebView bridges are origin/capability scoped;
- local capabilities obey iOS sandbox/entitlements;
- remote control exposes reviewed semantic capabilities rather than arbitrary Swift/shell/credential mutation;
- OAuth/passkey secrets never enter transcript/UI logs;
- URL/deep-link policy is allowlisted;
- telemetry/logs scrub sensitive data;
- App Store entitlement/background-mode constraints are authoritative.

### R16 — Provenance / rights

Because the Grok reconstruction grants no upstream source-code license:

- use it as architecture/protocol/behavior evidence;
- do not present reconstructed material as official source;
- do not bulk-copy implementation text without explicit rights review;
- record provenance for behavior-sensitive mappings;
- keep a release-blocking rights review for directly derived redistributed material.

Folder/module correspondence and independently implemented effect parity are required; textual source copying is not.

### R17 — Legacy removal

After replacement paths pass acceptance:

- remove runtime orchestration from `FabushiApp.swift`;
- split/remove monolithic responsibilities from `ContentView.swift` and `GrokMobileShell.swift`;
- remove duplicate Host ownership/event pumps;
- remove presentation -> Host direct calls;
- remove Coordinator bypasses;
- remove obsolete compatibility state/flags;
- migrate/delete legacy `mobile/ios` and `mobile/native` production paths as their responsibilities move into the Grok-corresponding root layout.

The task is not complete while the old architecture remains a production fallback.

### R18 — Standalone build guarantee

A clean checkout of the exact iOS implementation SHA must build, test, archive, and run without checking out another Fabushi source repository.

The final build must not rely on an opaque Mahayana binary whose source/build recipe exists only elsewhere. If `libmahayana_app_host` or successor native libraries remain, their required source, pinned third-party dependencies, build scripts, headers, architecture slices, and reproducible CI build must be owned by this repository.

External third-party package dependencies are allowed.

### R19 — App Store/TestFlight production constraints

The architecture must preserve deployability:

- supported iOS deployment target is explicit;
- arm64 device and simulator build paths are reproducible;
- signing/entitlements remain reviewable;
- no private API dependence;
- no prohibited dynamic code execution;
- background modes are declared only when justified;
- privacy usage descriptions match actual capability use;
- StoreKit flows remain Apple-compliant;
- final release acceptance includes archive/export/TestFlight-quality packaging.

## 6. Migration baseline (historical)

The observations below describe the repository at the migration kickoff. They are retained as historical migration input only; they are **not** the current implementation state and must not be used as completion evidence. Current truth comes from the parity ledger, shipping production wiring, and exact-HEAD CI/release artifacts:

- production source is concentrated in `mobile/ios/Fabushi`;
- `ContentView.swift` is a large multi-feature SwiftUI surface holding substantial navigation/composer/attachment/agent-surface state;
- `GrokMobileShell.swift` combines Grok-like avatar/bot UI with direct `MahayanaHost` interaction;
- `FabushiApp.swift` creates `MahayanaHost`, Marketplace, Messaging, app-agent surface, remote-device gateway, and handles deep links;
- `MahayanaHost.swift` wraps C functions from `mahayana_app_host.h` and links `-lmahayana_app_host`;
- `mobile/native` currently contains only the native header boundary visible in this repository;
- `FabushiRemoteDeviceGateway.swift` directly holds Host plus URLSession WebSocket transport;
- `project.yml` is a single app-centric XcodeGen project rooted under `mobile/ios`.

This baseline code was migration input, not the target architecture. As migration progresses, the compliance record in Section 17 must cite current evidence rather than restating this historical snapshot.

## 7. Target repository state

The repository converges to:

```
fabushi-ios/
├── frontend/
│   ├── Package.swift / project integration
│   └── Sources/
│       ├── Production/
│       └── Recovered/            # only if useful for evidence-oriented reconstruction
├── source/
│   ├── ios-dev-controls/
│   ├── ios-main/
│   │   ├── account/
│   │   ├── adapters/
│   │   ├── attachments/
│   │   ├── auth/
│   │   ├── box/
│   │   ├── coordinator/
│   │   ├── deep-link/
│   │   ├── dev/
│   │   ├── downloads/
│   │   ├── experiments/
│   │   ├── feedback/
│   │   ├── generated/
│   │   ├── local-exec/
│   │   ├── mcp/
│   │   ├── media/
│   │   ├── models/
│   │   ├── notifications/
│   │   ├── prefs/
│   │   ├── process-metrics/
│   │   ├── secrets/
│   │   ├── startup/
│   │   ├── telemetry/
│   │   ├── update/
│   │   └── vnc/
│   ├── ios-preload/
│   │   └── runtime/
│   ├── box-exec-daemon/
│   ├── host/
│   │   ├── agent-isolation/
│   │   ├── agents/
│   │   ├── automations/
│   │   ├── box/
│   │   ├── cloud-agents/
│   │   ├── connectors/
│   │   ├── extensions/
│   │   ├── groups/
│   │   ├── local-exec/
│   │   ├── mcp-auth/
│   │   ├── ports/
│   │   ├── runner/
│   │   ├── storage/
│   │   ├── transcript-mirror/
│   │   └── workflows/
│   ├── internal/
│   ├── local-exec-daemon/
│   ├── mahayana-agent-coordinator/
│   │   ├── gateway/
│   │   ├── local-exec/
│   │   ├── oauth/
│   │   ├── telemetry/
│   │   └── webauthn/
│   ├── packages/
│   │   └── <Grok-corresponding packages>
│   └── shared/
│       ├── agents/
│       ├── errors/
│       ├── media/
│       ├── observability/
│       └── rpc/
├── manifests/
├── scripts/
├── tests/
├── docs/
└── Xcode/SPM/Cargo/build assembly files
```

The complete file-level ledger is authoritative; this is the minimum structural skeleton.

### 7.1 Dependency direction

Allowed:

```
frontend
   ↓
ios-preload
   ↓
ios-main
   ↓
mahayana-agent-coordinator
   ↓
host
   ↓
local-exec-daemon / box-exec-daemon

source/shared + source/packages are repository-local libraries/contracts.
```

Forbidden:

- frontend -> Host direct;
- frontend -> Runner direct;
- SwiftUI App/View -> agent-domain mutation;
- Runner -> renderer;
- Host -> SwiftUI/UIKit presentation;
- feature Model -> independent Host creation after cutover;
- another Fabushi source repository required for runtime/build;
- circular cross-layer ownership.

## 8. Interfaces / contracts / data flow

### 8.1 Coordinator envelope

Define an iOS-local versioned contract equivalent in capability to Grok Coordinator/RPC contracts:

```
Request {
  protocolVersion
  requestId
  sessionId
  method
  params
  deadline?
}

Reply {
  requestId
  ok
  result?
  error?
}

Event {
  eventId
  sessionId
  sequence
  type
  payload
}

Cancel {
  requestId | operationId
  reason?
}
```

The schema is stored locally under corresponding `source/shared/**` / `source/packages/**` modules.

### 8.2 Renderer

SwiftUI consumes immutable projections and emits typed intents. Renderer code does not poll Host or parse arbitrary Host JSON.

### 8.3 Transcript ordering

Coordinator/Host define stable event IDs, ordering, deduplication, mutation semantics, and resync snapshots.

### 8.4 Execution flow

```
SwiftUI intent
 -> iOS preload/bridge
 -> iOS main
 -> Mahayana Coordinator
 -> Host
 -> Runner/tool/MCP
 -> Host event
 -> Coordinator ordered event
 -> iOS main/bridge
 -> renderer projection
 -> SwiftUI render
```

Cancellation settles through the same ownership chain.

## 9. Constraints and non-functional requirements

- best iOS effect is the primary implementation criterion;
- primary shell is native SwiftUI;
- no runtime source dependency on another Fabushi repository;
- no blocking native dispatch on the main actor;
- responses stream incrementally;
- foreground/background transitions must not corrupt active operations;
- app termination/relaunch must not duplicate commands;
- deterministic error codes replace UI parsing of arbitrary exception strings;
- idle animation respects Reduce Motion and battery/thermal conditions;
- memory pressure must release disposable renderer/media state safely;
- logs/evidence are privacy scrubbed;
- architecture must be testable without production network access;
- folder/module parity is enforced by CI.

## 10. Failure modes and edge cases

Required coverage:

- Coordinator starts but Host fails;
- Host/native runtime crashes/fails mid-turn;
- local capability Runner fails or times out;
- remote Runner/box disconnects;
- MCP disconnect/reconnect;
- OAuth callback after scene recreation;
- passkey cancellation;
- network loss during streaming;
- duplicate/out-of-order events;
- renderer reconnect after suspension;
- app termination/relaunch;
- memory warning/pressure;
- native library load/symbol failure;
- stale native handle;
- multiple SwiftUI observers;
- double send/double cancel;
- attachment security-scope expiry;
- unavailable iOS capability;
- remote gateway session/token rollover;
- WKWebView process termination;
- storage full/corrupt/protected-data unavailable;
- local protocol version mismatch;
- migration incompatibility;
- update/relaunch during active operation.

Every path must end in deterministic recoverable or terminal state.

## 11. Implementation strategy

### Phase 0 — Inventory and exact folder map

1. pin Grok and iOS SHAs;
2. generate complete Grok `source/**` + `frontend/**` tree;
3. generate an iOS target path for every Grok file;
4. create root scaffolding matching Section 7;
5. inventory every existing `mobile/ios` and `mobile/native` file and planned target/removal;
6. record provenance/rights classification;
7. define critical behavior fixtures.

Exit gate: 100% file mapping and zero unexplained folder divergence.

### Phase 1 — iOS-local contracts/packages/runtime source

1. create `source/shared/**`;
2. create `source/packages/**`;
3. define local Coordinator contracts;
4. bring required runtime source/build recipes under this repository;
5. create Swift/Rust/C bindings as needed;
6. add contract/build reproducibility tests.

Exit gate: clean checkout builds all required local contracts/native runtime pieces without another Fabushi source checkout.

### Phase 2 — Mahayana Coordinator

Implement `source/mahayana-agent-coordinator/**`.

Exit gate: normal, streaming, tool, cancel, reconnect, duplicate, Host failure, and resync state-machine tests pass.

### Phase 3 — Host + Runner

Implement/migrate `source/host/**`, `source/local-exec-daemon/**`, `source/box-exec-daemon/**`, and `source/internal/**`.

Exit gate: all domain execution flows Coordinator -> Host -> local capability/remote Runner/tool and returns ordered events.

### Phase 4 — iOS main/preload

Build `source/ios-main/**`, `source/ios-preload/**`, and `source/ios-dev-controls/**`. Move orchestration out of `FabushiApp.swift`.

Exit gate: `FabushiApp.swift` is thin scene/app composition.

### Phase 5 — Frontend

Move/rebuild SwiftUI renderer into root `frontend/**`, following Grok frontend responsibilities and iPhone/iPad-native behavior.

Exit gate: roster, conversation, composer, streaming states, command palette, settings, MCP/connectors, attachments, remote computer, and recovery operate through Coordinator only.

### Phase 6 — Existing Fabushi features

Move Marketplace, Mini Apps, messaging, bot projection, commerce/StoreKit, remote-device gateway, media/voice, location, updates, and other iOS features into corresponding Grok-aligned modules.

Exit gate: no feature keeps a competing runtime architecture.

### Phase 7 — Delete old architecture

Remove obsolete `mobile/ios` and `mobile/native` production paths after their replacements own production. Remove presentation-to-Host calls and all compatibility bypasses/fallbacks.

Exit gate: architecture checker sees only the Grok-corresponding module graph.

### Phase 8 — Exact-HEAD verification/package/TestFlight-quality acceptance

Run compile, unit, contract, architecture, UI, lifecycle, packaged archive/export/install, and release-candidate acceptance from the exact implementation SHA.

## 12. Verification / test strategy

### 12.1 Folder parity checker

CI compares pinned Grok inventory to parity ledger and iOS target tree.

Fail if:

- any Grok file/module is unclassified;
- required target counterpart is absent;
- target path diverges without ledger rationale;
- old monolithic path regains migrated responsibility.

### 12.2 Architecture checker

Fail CI if:

- frontend imports Host/Runner implementation;
- SwiftUI Model/View directly constructs Host after cutover;
- `FabushiApp.swift` owns product orchestration;
- Coordinator is bypassed;
- duplicate Coordinator implementations exist;
- another Fabushi source repository is required for runtime build;
- legacy architecture path is reintroduced.

### 12.3 Contract/state tests

Cover:

- send -> stream -> complete;
- send -> tool -> result -> complete;
- cancel;
- reconnect/resync;
- duplicate event;
- Host failure/recovery;
- stale session/generation.

### 12.4 iOS lifecycle tests

- scene active/inactive/background;
- view/scene recreation;
- termination/relaunch;
- protected-data unavailable/available;
- memory pressure;
- notification/deep link/universal link;
- OAuth callback;
- passkey flow;
- document/photo picker;
- background URLSession completion;
- remote gateway reconnect.

### 12.5 UI/effect parity

Capture tests/evidence for:

- agent list/row actions;
- conversation;
- composer/send/stop;
- thinking/running/completed/failed/recovered;
- command palette;
- settings;
- MCP/connectors;
- reactions/groups;
- attachments/media/voice;
- Mini App;
- remote computer;
- errors/retry;
- iPad responsive behavior.

### 12.6 Packaged acceptance

Use an exact-HEAD archived/exported app. Validate fresh install, upgrade, launch, login, normal chat, streaming, stop, tool/MCP, background/recovery, termination/relaunch, remote-device registration where applicable, StoreKit sandbox path where applicable, logout, and relaunch.

## 13. Acceptance criteria / Definition of Done

- **AC-1**: 100% of pinned Grok `source/**` and `frontend/**` files exist in the parity ledger.
- **AC-2**: Every relevant Grok module has an iOS-local counterpart or reviewed N/A.
- **AC-3**: Repository root physically follows the Grok-corresponding `frontend/source/tests/scripts/manifests/docs` structure.
- **AC-4**: `source/electron-main` responsibilities correspond to `source/ios-main`.
- **AC-5**: `source/electron-preload` responsibilities correspond to `source/ios-preload`.
- **AC-6**: `source/node-agent-coordinator` responsibilities correspond to first-class `source/mahayana-agent-coordinator`.
- **AC-7**: Host and Runner are independent and cannot be directly invoked by renderer code.
- **AC-8**: iOS-local `source/shared/**` and `source/packages/**` cover all required reference responsibilities.
- **AC-9**: Clean checkout builds/tests/archives without another Fabushi source repository.
- **AC-10**: Required native runtime source/build recipe is owned here; no opaque cross-repo Mahayana build dependency remains.
- **AC-11**: `FabushiApp.swift` is thin app/scene composition.
- **AC-12**: `ContentView.swift` / `GrokMobileShell.swift` monolithic runtime responsibilities are removed/split.
- **AC-13**: Product presentation Models/Views do not directly construct/use Host runtime outside approved platform bootstrap.
- **AC-14**: Supported Grok-equivalent flows stream and settle with equivalent behavior.
- **AC-15**: Background/suspension/termination/relaunch restores/resyncs without duplicate sends, stuck turns, or leaked native handles.
- **AC-16**: MCP/connector discovery/auth/invocation/result/error works through Coordinator/Host.
- **AC-17**: Attachments, media/voice, deep links, OAuth/passkeys, notifications, StoreKit, and remote-computer use native iOS adapters.
- **AC-18**: One canonical iOS-local truth exists for auth, roster, transcript, operations, MCP, Mini Apps, remote device, settings, permissions, and entitlement projection.
- **AC-19**: Old production architecture/fallbacks are removed.
- **AC-20**: Folder and architecture checkers prevent regression.
- **AC-21**: Exact-HEAD CI passes compile/unit/contract/architecture/UI/lifecycle checks required by this Spec.
- **AC-22**: Exact-HEAD archive/export/install acceptance passes on a fresh environment and upgrade path.
- **AC-23**: Rights/provenance review has no unresolved release-blocking item.
- **AC-24**: App Store/TestFlight constraints have no unresolved release-blocking violation.
- **AC-25**: Final compliance table records every requirement/AC as `passed`, `blocked`, or `not-applicable`; mandatory completion requires all mandatory items `passed`.

## 14. Release / migration / rollback

Temporary cutover flags may exist only during controlled migration and must be removed before AC-19.

Persistent migrations must be versioned and idempotent. Rollback must preserve account/transcript/entitlement integrity and must not silently activate a second state store.

Architecture-complete cannot be declared from source tests alone. Exact-HEAD archive/export/install acceptance is required.

For release completion, signing, export, TestFlight upload (when required by the release task), and canonical-main verification must use the exact accepted source SHA.

## 15. Observability / evidence

Each phase retains:

- file-level parity ledger;
- folder-parity checker output;
- architecture dependency report;
- native runtime reproducibility proof;
- contract/state-machine reports;
- lifecycle/background/termination report;
- UI screenshots/video for critical flows;
- MCP/connector trace with secrets scrubbed;
- exact SHA;
- CI run IDs;
- archive/export artifact identity/checksum;
- fresh install/upgrade acceptance;
- final Spec compliance table.

## 16. References / provenance

Primary Grok baseline:

- `b-nnett/grok-bot-0.18-reconstructed@a9f633e09d49a85829b8236331b9e21f7e612634`
- `README.md`
- `NOTICE.md`
- `PROVENANCE.md`
- `docs/ARCHITECTURE.md`
- `frontend/**`
- `source/electron-main/**`
- `source/electron-preload/**`
- `source/electron-dev-controls/**`
- `source/node-agent-coordinator/**`
- `source/host/**`
- `source/local-exec-daemon/**`
- `source/box-exec-daemon/**`
- `source/internal/**`
- `source/packages/**`
- `source/shared/**`
- `tests/**`
- `scripts/**`
- `manifests/**`

Fabushi iOS discovery baseline:

- `bhrumom/fabushi-ios@d5ec44c14810de173f3584d1e72b067e8cd5fce2`
- `AGENTS.md`
- `docs/specs/spec-first-ai-development.md`
- `mobile/ios/project.yml`
- `mobile/ios/Fabushi/FabushiApp.swift`
- `mobile/ios/Fabushi/ContentView.swift`
- `mobile/ios/Fabushi/GrokMobileShell.swift`
- `mobile/ios/Fabushi/MahayanaHost.swift`
- `mobile/ios/Fabushi/MarketplaceModel.swift`
- `mobile/ios/Fabushi/MessagingModel.swift`
- `mobile/ios/Fabushi/FabushiAppAgentSurface.swift`
- `mobile/ios/Fabushi/FabushiRemoteDeviceGateway.swift`
- `mobile/ios/Fabushi/GlobalDharmaMiniAppBridge.swift`
- `mobile/ios/Fabushi/MiniAppWebMcpSurface.swift`
- `mobile/ios/Fabushi/RemoteComputerSurface.swift`
- `mobile/native/include/mahayana_app_host.h`

## 17. Spec compliance record

This table is an evidence register, not a migration progress counter. `pending` is allowed while Work is in progress; final release status is limited to `passed`, `blocked`, or `not-applicable`. A row may move to `passed` only when its requirement is independently satisfied and evidenced.

| Requirement / AC | Status | Evidence / reason |
| --- | --- | --- |
| R1 | pending | The pinned inventory is present at 2,046/2,046 rows, but ledger closure is incomplete: 1,519 mapped, 507 implemented, 20 reviewed N/A, 0 verified at the audited snapshot; `replaces_ios_path` is still unfilled and some implemented/N/A rows still lack test evidence. |
| R2 | pending | Grok-corresponding roots and strict architecture checking exist; recursive physical cutover remains incomplete. |
| R3 | pending | Shipping renderer → ios-preload → ios-main → Coordinator → Host paths exist, including auth; full no-bypass boundary audit remains incomplete. |
| R4 | pending | First-class Mahayana Coordinator, renderer port, Host supervision and production assembly exist; remaining mapped Coordinator responsibilities and exact-HEAD acceptance are not closed. |
| R5 | pending | iOS-owned Host/Rust source is present and built in-repo; substantial Host ledger work remains mapped rather than verified. |
| R6 | pending | iOS-safe local capability and remote/box adaptations exist; full Runner behavior/evidence closure remains incomplete. |
| R7 | pending | Shipping IOSPreloadBridge/Coordinator port boundary exists; UI-facing free-form payload cleanup and complete parity evidence remain open. |
| R8 | pending | IOSMainRuntime now owns production main composition with account, lifecycle and update wiring; remaining electron-main → ios-main rows are not fully implemented/verified. |
| R9 | pending | All 322 frontend reference rows are mapped, but renderer migration remains the largest unresolved implementation domain. |
| R10 | pending | All 165 source/shared rows are implemented in the ledger snapshot, but exact behavior verification is still required before final closure. |
| R11 | pending | source/packages has 164 implemented, 680 mapped and 8 reviewed N/A rows at the audited snapshot; package parity is incomplete. |
| R12 | pending | Cross-feature effect-parity acceptance is incomplete. |
| R13 | pending | Rust Host is authoritative for account identity and Coordinator account settings now follow settled Host auth replies; the wider canonical-truth audit remains open. |
| R14 | pending | Scene/background/protected-data/relaunch recovery code and tests exist; protected-session packaged E2E and termination/relaunch acceptance still need successful exact-SHA evidence. |
| R15 | pending | CI-session provenance, URL/deep-link, Keychain and trusted-boundary controls exist; full security/entitlement/privacy review remains open. |
| R16 | blocked | `docs/provenance/grok-bot-0.18-rights-review.md` explicitly records an open release-blocking independent rights review; technical CI cannot clear it. |
| R17 | pending | FabushiApp has been reduced to thin Scene/App composition, but legacy renderer/fallback paths are still referenced by shipping/UI acceptance code. |
| R18 | pending | iOS-owned Rust Cargo source, headers/build script, simulator build and physical-device archive lane exist; final clean-checkout/archive proof on one accepted SHA is still required. |
| R19 | pending | Exact-SHA signed archive/export/App Store Connect upload workflow exists and fails closed on missing credentials; credential-backed TestFlight/App Store success evidence is still required. |
| AC-1 | passed | The ledger contains all 2,046 pinned Grok source/frontend paths. |
| AC-2 | pending | Mapping exists for all rows, but relevant counterparts/N/A dispositions are not all implemented and verified. |
| AC-3 | pending | Target roots exist; recursive physical cutover and legacy removal remain incomplete. |
| AC-4 | pending | ios-main mapping/implementation is partial and not fully verified. |
| AC-5 | pending | ios-preload exists and ships, but full responsibility parity/verification remains open. |
| AC-6 | pending | Mahayana Coordinator is first-class and shipping; remaining Coordinator ledger rows and behavior acceptance are open. |
| AC-7 | pending | Auth and primary renderer traffic follow the required boundary; repository-wide no-bypass proof is not yet final. |
| AC-8 | pending | source/shared is implemented at ledger level; source/packages remains substantially mapped. |
| AC-9 | pending | Exact clean-checkout build/test/archive success on the final accepted SHA is pending. |
| AC-10 | pending | Native runtime source/build recipe is repository-owned, but final exact-SHA standalone proof must still pass. |
| AC-11 | passed | FabushiApp.swift only installs FabushiSceneRoot in WindowGroup; product orchestration lives below the App entry point. |
| AC-12 | pending | Legacy GrokMobileShell/ContentView responsibilities remain present/referenced and require final split/removal proof. |
| AC-13 | pending | Primary models use IOSPreloadBridge, but a repository-wide direct-Host audit remains to be closed. |
| AC-14 | pending | Behavioral acceptance remains incomplete. |
| AC-15 | pending | Lifecycle unit coverage exists; packaged background/termination/relaunch acceptance remains incomplete. |
| AC-16 | pending | MCP/connector contracts and tests exist; complete discovery/auth/call/result/error E2E evidence remains open. |
| AC-17 | pending | Native adapter work exists across auth/deep-link/passkey/background-transfer/remote-computer; complete cross-feature acceptance remains open. |
| AC-18 | pending | Account canonical ownership has been narrowed; full canonical-state ownership audit remains open. |
| AC-19 | pending | Old production fallback/legacy paths are not yet fully removed. |
| AC-20 | passed | PR workflow runs the architecture checker and strict checker on the exact pull-request head SHA, preventing unmapped/forbidden-root regressions. |
| AC-21 | pending | Exact-HEAD architecture/Rust/build/unit/UI/lifecycle jobs must all succeed on the final accepted SHA. |
| AC-22 | pending | Unsigned physical-device archive lane exists; fresh-install/upgrade/export/install acceptance remains pending. |
| AC-23 | blocked | The independent rights/provenance checklist is still open; release remains blocked until it is reviewed and recorded against the final SHA/IPA. |
| AC-24 | pending | Signed App Store/TestFlight lane exists; no successful final credential-backed delivery evidence yet. |
| AC-25 | pending | Final compliance review remains pending; mandatory completion requires all mandatory rows to be passed. |

Allowed migration status: `pending`. Allowed final statuses: `passed`, `blocked`, `not-applicable`.
