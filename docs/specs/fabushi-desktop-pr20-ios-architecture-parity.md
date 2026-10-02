# Fabushi Desktop PR #20 -> Fabushi iOS Standalone Architecture & Product Parity — Specification

Status: active  
Owner: Fabushi iOS  
Last updated: 2026-10-02  
Related PR: `bhrumom/fabushi-ios#3`

## 1. Decision and authority

Fabushi iOS is a **standalone downstream iOS implementation of Fabushi Desktop PR #20**.

The direct migration source and product/architecture authority for this work is:

- source repository: `bhrumom/fabushi-desktop`
- source pull request: `#20`
- source branch: `refactor/grok-018-architecture-rebuild`
- pinned source commit for this baseline: `cbed42883dec4dbd12af2d54bd60d5855b3c0327`
- source specification: `docs/specs/grok-bot-018-runtime-product-parity-recovery.md`

The previous direct iOS baseline, `b-nnett/grok-bot-0.18-reconstructed@a9f633e09d49a85829b8236331b9e21f7e612634`, is **no longer the direct iOS migration authority**. Grok Bot 0.18 remains historical architecture/provenance context because Desktop PR #20 itself derives from that work, but iOS parity, implementation status, completion, and acceptance are judged against the pinned Desktop PR #20 source and product behavior.

Authority chain:

```
Grok Bot 0.18
    |
    | historical architecture / provenance
    v
Fabushi Desktop PR #20
    |
    | direct iOS migration authority
    v
Fabushi iOS PR #3
```

If Desktop PR #20 moves to a new exact HEAD, all Desktop-bound source inventory, blob identities, stale implementation-status claims, and acceptance evidence tied to the old SHA must be revalidated before they can be used for the new baseline.

## 2. Product goal

The goal is not to make an iOS app that separately reinterprets Grok Bot.

The goal is to make the **native iOS edition of the Fabushi product defined by Desktop PR #20**, preserving the same product capabilities, architecture ownership, runtime semantics, state machines, dependency direction, failure behavior, and durable lifecycle wherever they are applicable to iOS.

Desktop remains the upstream product/architecture implementation. iOS is a native platform port.

The iOS implementation may:

- directly reuse source from Desktop PR #20;
- port Rust source into iOS-owned Rust modules;
- translate TypeScript/React behavior into Swift/SwiftUI;
- adapt desktop platform mechanisms to Apple-native equivalents;
- split or merge implementation files when doing so does not collapse an architectural ownership boundary.

The iOS implementation must not:

- depend on a checkout of `fabushi-desktop` at build or runtime;
- depend on `fabushi-platform-core` or another shared Fabushi runtime repository merely to deduplicate Desktop/iOS code;
- move common Desktop/iOS production implementation into a new shared library as part of this migration;
- preserve Grok as a parallel direct iOS source of truth;
- claim parity from file names, stubs, ledger strings, or tests that do not exercise the shipping path.

Reused source becomes **iOS-owned source after migration**.

## 3. Standalone repository ownership

`bhrumom/fabushi-ios` owns the complete iOS product implementation required for a clean checkout to build, test, archive, install, and run:

- SwiftUI renderer;
- iOS platform-main lifecycle;
- trusted iOS bridge;
- Mahayana Coordinator;
- Host;
- Runner and safe local capability execution;
- remote/box execution adapters;
- iOS-local shared contracts/policies;
- iOS-local packages and runtime source;
- persistence/transcript/checkpoint state;
- auth/OAuth/passkeys;
- MCP/connectors/tools;
- messaging/communication capabilities;
- automations/workflows;
- inference/provider routing;
- telemetry/observability;
- StoreKit and Apple platform integration;
- Xcode/SPM/Cargo build integration;
- CI, signing, archive, TestFlight/App Store delivery.

A clean iOS checkout must not require another Fabushi source repository.

## 4. Architecture correspondence

Desktop PR #20 architecture is normative. iOS may substitute platform mechanisms, not ownership.

| Desktop PR #20 | Fabushi iOS |
| --- | --- |
| `frontend/**` | `frontend/**`, native Swift/SwiftUI projection |
| `source/electron-main/**` | `source/ios-main/**` |
| `source/electron-preload/**` | `source/ios-preload/**` |
| `source/electron-dev-controls/**` | `source/ios-dev-controls/**` |
| `source/node-agent-coordinator/**` | `source/mahayana-agent-coordinator/**` |
| `source/host/**` | `source/host/**` |
| `source/local-exec-daemon/**` | `source/local-exec-daemon/**` or safe iOS local-capability runtime |
| `source/box-exec-daemon/**` | `source/box-exec-daemon/**` |
| `source/internal/**` | `source/internal/**` |
| `source/packages/**` | `source/packages/**` |
| `source/shared/**` | `source/shared/**` |
| `source/mahayana/**` | iOS-owned Mahayana/Rust source under the iOS repository |
| `contracts/**` | iOS-owned versioned contracts where applicable |
| `scripts/**` | iOS-specific build/verification scripts |
| `.github/workflows/**` | iOS-specific exact-HEAD CI/release workflows |

The dependency direction is:

```
SwiftUI renderer
      |
      v
iOS trusted bridge
      |
      v
iOS platform-main
      |
      v
Mahayana Coordinator
      |
      v
Host
      |
      v
Runner / Provider / MCP / Capability adapters
```

Renderer/UI state is a projection. It is not the canonical owner of operation/run truth, retry state, transcript truth, provider lifecycle, connector truth, or recovery state.

## 5. Process-boundary adaptation on iOS

Desktop process boundaries are architectural evidence, but iOS must obey the iOS sandbox and lifecycle.

When Desktop uses an independent OS process and iOS cannot or should not do so, iOS may implement the same responsibility as a separate actor/module/runtime boundary.

This adaptation is valid only when it preserves:

- ownership;
- protocol boundaries;
- typed identity;
- cancellation;
- ordering;
- crash/restart or lifecycle settlement semantics;
- persistence ownership;
- failure normalization;
- observability lineage.

It is not valid to collapse Coordinator + Host + Runner + renderer state into one giant Swift object merely because iOS uses a single application process.

## 6. Source reuse policy

This migration intentionally permits source reuse **without a shared source repository**.

Allowed:

```
fabushi-desktop/source/host/x.rs
          |
          | copy / port / adapt
          v
fabushi-ios/source/host/x.rs
```

Allowed:

```
Desktop TypeScript behavior
          |
          | semantic translation
          v
iOS Swift implementation
```

Allowed:

```
Desktop Rust module
          |
          | iOS platform adaptation
          v
iOS-owned Rust module
```

Forbidden for this migration:

```
Desktop ---+
           +--> new/common shared runtime repository
iOS -------+
```

Source copied or ported from Desktop PR #20 must be reviewed for licensing/provenance requirements and then maintained by the iOS repository.

## 7. Desktop-to-iOS parity ledger

The old 2,046-row Grok-direct ledger is historical evidence only. Its `mapped`, `implemented`, `verified`, and N/A statuses are not completion evidence for this Spec.

A new Desktop PR #20 parity ledger is authoritative.

Every source-bearing Desktop file in the selected migration roots must be inventoried with at least:

- `desktop_path`;
- `desktop_blob_sha`;
- `desktop_responsibility`;
- `desktop_owner`;
- `desktop_visible_effect`;
- `ios_disposition`;
- `ios_target_path`;
- `ios_language`;
- `ios_platform_delta`;
- `implementation_status`;
- `production_evidence`;
- `test_evidence`;
- `notes`.

Allowed disposition classes:

- `direct-port`: source/responsibility can be substantially reused in iOS;
- `ios-adapted`: same responsibility/effect, implemented with an iOS-native mechanism;
- `not-applicable-with-replacement`: the desktop mechanism is prohibited/inapplicable, with an explicit replacement for any still-required product effect.

Allowed work statuses:

- `unreviewed`;
- `mapped`;
- `implemented`;
- `verified`;
- `not-applicable`.

Only `verified` and reviewed `not-applicable` may satisfy the final completion gate.

A status from the previous Grok-direct ledger may not be copied forward without re-reading the corresponding Desktop PR #20 implementation and validating the current iOS shipping path against it.

## 8. Inventory roots

The baseline inventory is generated from Desktop PR #20 exact HEAD and includes source-bearing files under:

- `frontend/**`;
- `source/**`.

Additional product-defining Desktop files under `contracts/**`, relevant `scripts/**`, and the authoritative Desktop Spec must be tracked separately when they define iOS-applicable contracts or behavior.

Generated build output, caches, vendored artifacts that do not define source responsibility, and platform packaging artifacts may be excluded only by an explicit inventory rule.

## 9. Platform substitutions

### 9.1 Electron main -> iOS main

Desktop Electron-native mechanisms map to Apple-native owners:

| Desktop mechanism | iOS mechanism |
| --- | --- |
| BrowserWindow/app lifecycle | SwiftUI scene/UIKit application lifecycle |
| desktop OAuth browser flow | AuthenticationServices / ASWebAuthenticationSession |
| desktop secrets | Keychain |
| desktop notifications | UserNotifications |
| desktop downloads | URLSession / background transfer |
| desktop file picker | UIDocumentPicker / PhotosPicker |
| desktop media devices | AVFoundation / Photos / system permission APIs |
| desktop deep links | URL/universal-link routing |
| desktop updates | App Store/TestFlight-compatible update semantics |
| tray/dock/window affordances | native iOS navigation/badge/notification equivalents where applicable |

### 9.2 Local execution

Arbitrary shell execution, unrestricted filesystem access, process spawning, and long-lived desktop daemons are not iOS requirements.

The product effect must be retained when applicable through one of:

- safe in-process iOS capability adapter;
- system framework;
- BGTaskScheduler/background transfer;
- remote Runner;
- box/remote-computer execution.

The ledger must distinguish “desktop mechanism N/A” from “product capability removed”. A product effect cannot be silently removed when an iOS-safe replacement exists.

## 10. Coordinator requirements

`source/mahayana-agent-coordinator/**` is the iOS counterpart of Desktop PR #20 `source/node-agent-coordinator/**`.

### 10.1 iOS carrier adaptation

Desktop `source/node-agent-coordinator/src/carrier.rs` owns more than the desktop process mechanism. Its portable contract includes validated coordinator bootstrap metadata, distinct `coordinator-control` / `coordinator-data` / `coordinator-main-data` channel identity, ordered buffering, fail-closed handling for unknown channels, and deterministic close semantics that reject new posts and discard queued work.

On iOS these responsibilities remain Coordinator-owned even though the transport is in-process. `source/mahayana-agent-coordinator/carrier.swift` is the canonical iOS carrier owner, and the shipping `InProcessCoordinatorPort` must route its frame delivery through that carrier rather than bypassing it. `IOSMainRuntime` supplies validated app-version/package/data-directory bootstrap metadata to `IOSCoordinatorLauncher`; SwiftUI/renderer code never owns or synthesizes carrier truth. The iOS transport may project the existing `CoordinatorPort` API onto the control channel while retaining typed data/main-data channels for Coordinator-internal routing.

### 10.2 Client-side tool v2 relay

Desktop `source/node-agent-coordinator/src/client_side_tool_v2_relay.rs` at blob `a01c69f3eb7aec0e07a8bcc003d251ad9d3d7c33` is the normative Coordinator responsibility for the `client-side-tool-v2` event family. The relay does not invent request IDs or run IDs. Its durable ordering/settlement identity is `(agentId, epoch, sequence, protobuf toolCallId)`: wire version must be `1`, account slot must be `host`, agent/epoch must be non-empty, sequence is strictly increasing within the current agent epoch, retired epochs are rejected, and protobuf/base64 payloads must carry the expected message type plus the matching tool-call-id field (`3` for Call and `35` for Result). A Result without a current Call is dropped. Reset clears current tool-call lifecycles, epoch changes retire the previous epoch, replay exposes only the current epoch's accepted Call/Result pairs in sequence order, and Coordinator shutdown clears relay state.

The iOS platform adaptation may receive Host events through the existing in-process Host/Coordinator boundary rather than Desktop stdio, but ownership may not move into SwiftUI. The shipping Coordinator must own the relay, route accepted events to the renderer event family, and replay accepted current-epoch state only from Coordinator-owned state. Host production of these events is a separate upstream responsibility: until the iOS Host turn-observation path can emit the same versioned `client-side-tool-v2` transport envelope, this Coordinator row may be implemented only for the Coordinator ingress/projection path and must not be represented as end-to-end verified.

### 10.3 Control-port client settlement

Desktop `source/node-agent-coordinator/src/control_port_client.rs` owns the Coordinator control-client handshake, monotonically allocated `c-N` request identity, pending request settlement, cancellation signaling, event posting, protocol-direction enforcement, and deterministic disconnect semantics. iOS may replace Desktop mpsc waiters with `@MainActor` Swift continuations over the in-process carrier, but it must preserve the same protocol effect: exactly one matching-version Ready transitions the client into service; repeated/mismatched Ready or any server-posted client-direction frame is a protocol breach; unknown/late replies are ignored; cancel is emitted only for a still-pending request; local shutdown posts Requested before closing; and no request/event is accepted once settled.

Every terminal control-port path must reject all pending calls with the Desktop `COORDINATOR_DISCONNECTED` failure class while retaining the causal message. Port close uses `control port closed`; local shutdown uses `shutdown requested`; peer shutdown uses its detail when present or the normalized `coordinator shutdown: <reason>` fallback; protocol breach uses the breach detail. Settlement clears pending continuations and closes the carrier exactly once. Generic `port-settled` errors must not erase this failure normalization.

It owns, as applicable:

- renderer port lifecycle;
- request/reply correlation;
- typed operation/run identity;
- ordered event fan-out;
- streaming activity;
- cancellation;
- reconnect/resync;
- transcript routing;
- inference routing;
- local/remote capability routing;
- client-side tool relay;
- MCP routing/OAuth forwarding;
- gateway routing;
- Host supervision;
- crash/lifecycle settlement;
- telemetry lineage.

SwiftUI Views and presentation Models must not reimplement these responsibilities.

## 11. Host / Runner requirements

The iOS Host/Runner implementation is ported from Desktop PR #20 responsibilities, not reconstructed independently from Grok.

It must preserve applicable Desktop behavior for:

- send acceptance and durable identity;
- transcript lifecycle;
- provider streaming;
- first-output/watchdog behavior;
- retry/backoff;
- checkpoint/resume;
- cancellation;
- tool/MCP execution;
- waiting-user states;
- terminal settlement;
- durable persistence;
- agent/group/workflow/automation lifecycle;
- connector state;
- communication/messaging lifecycle;
- failure and recovery semantics.

### 11.1 Send/media shaping platform adaptation

Desktop send_message_shaping.rs remains the normative responsibility boundary even though iOS does not reproduce the Desktop provider call shape literally. The iOS production path must remain FeatureHost ChatSend or AgentSend -> Host-owned selected-image materialization -> existing mahayana.conversation.send contract -> MahayanaRuntime and KernelConversationProvider -> NativeEngine current user turn -> single model boundary.

The canonical image owner is the iOS-owned Rust Host, not SwiftUI or the shared Swift image helper. source/host/selected-image-inputs.rs owns byte loading, MIME classification, and byte-level dimensions; Desktop pitm / ispe / irot behavior for ISO-BMFF HEIC/HEIF/AVIF dimensions must be preserved. FeatureHost may additionally honor an iOS-native picker's declared image MIME when the Desktop extension classifier does not claim that extension, but this is a platform input adaptation, not a second media owner.

mahayana.conversation.send carries an optional image-data channel while existing text-only callers serialize no extra media field. KernelConversationProvider forwards that channel as operation metadata; NativeEngine projects only data:image values into the same current user turn as input_image blocks. The model boundary owns wire-specific projection: Responses keeps input_image, Chat Completions emits image_url, and Anthropic Messages emits a base64 image source. Renderer-owned state must never become the media owner.

For direct Agent-to-Agent delivery, agent.send keeps image URL/alt metadata in durable AgentPeerMessage state. Only local file URLs are materialized into recipient selected-image input; unsupported or remote URLs are not falsely treated as local bytes. The recipient wake reuses schedule_background_agent_turn and mahayana.conversation.send. Group messaging keeps the Desktop product behavior and does not invent a separate image execution owner.

selected_image_inputs.rs and the direct generated-media consumer in agent_to_agent_messaging.rs may be implemented once this production wiring exists, but they remain unverified until exact-HEAD CI runs the production Rust Host graph and focused contracts. For ordinary ChatSend, the Rust FeatureHost must split attachments before Runtime dispatch into three Host-owned channels: images, selected videos, and generic files. Images continue through the typed selected-image data channel. Because the current iOS NativeEngine/model adapters do not expose a native provider video/file content block, selected-video descriptors (path, MIME, filename, fixed 4 fps sampling intent) and generic-file descriptors are consumed by the Host into distinct model-visible local attachment context before the Runtime boundary; images must not be duplicated into that generic context, and videos must not be downgraded to generic files. This is the iOS platform replacement for Desktop Runner argument shaping, not a second media owner. The broader send_message_shaping.rs row remains mapped until this three-way shipping split is wired and the remaining applicable reaction/reply/thread shaping semantics are audited.

### 11.2 Generated SendMessage pipeline rebaseline

Desktop PR #20 advanced from `dcb19a94383833fc1ec5074f10c4bbbd28c09036` to `f1d06ed8ad2a1ce4b5adeeed6df8e97152553661`. Unlike the preceding manifest-only acceptance, this advance changes shipping Host source: `source/host/app/src/main.rs`, `source/host/src/extensions/transcript/production_runtime.rs`, and `source/host/src/extensions/transcript/send_pipeline.rs`, with focused production-composition coverage. Runner-generated `SendMessage` is no longer allowed to append an ad-hoc `runner-send:<tool_call_id>` transcript object directly. It must enter the canonical Host send pipeline, derive a live transcript entry ID, validate explicit reply targets, apply turn reply-context threading, reuse the session attachment batch identity, stamp fork-generated entries as branched, durably append through the canonical Session owner, and then continue through the existing media persistence/delivery/ack/activity owner.

For iOS this is an applicable product responsibility, not a desktop-only mechanism. The in-process iOS Host may replace Desktop process mechanics, but `AgentSend` or any Runner-generated send must not bypass canonical transcript shaping/persistence or create a parallel sender. NativeEngine `send_message` tool output is a generated send, not an ordinary model completion: the tool must return its generated payload to the Kernel, while the canonical KernelConversationProvider/Runtime transcript owner allocates the visible MessageId, persists exactly one assistant entry, and emits the user-visible completion. The tool implementation must not append or simulate a second ordinary completion itself. Generated-send metadata must retain the originating tool-call identity so future reply/thread, attachment-batch, and fork semantics can extend the same owner instead of creating another sender. The affected iOS row remains `mapped` until reply/thread validation, attachment batch identity, fork stamping, and their downstream settlement semantics are applicable and proven with exact-HEAD tests. Existing generated-media materialization does not by itself satisfy this broader pipeline responsibility.

### 11.3 Direct-turn context and workflow-reference rebaseline

Desktop PR #20 advanced from `f1d06ed8ad2a1ce4b5adeeed6df8e97152553661` to `bf36916c80e68737f02217ae85be4d22a6a5f928` with source-bearing changes in the shipping Host direct-turn path. `send_turn_dispatch.rs` now shapes direct Runner arguments only after the user turn has been durably admitted: it carries the persisted user `messageId`, projects durable recent user messages (including rich text), expands enabled workflow references, prepends an offline-composed timestamp note when applicable, and injects mentioned-Agent context derived from the live roster. `main.rs` invokes this shaping before the canonical `sendPrompt` Host lane dispatch. `workflow_commands.rs` and `main.rs` also route a visible workflow-reference run-now back through the canonical sendPrompt path instead of a compatibility dispatch, preserving ordinary user-turn history/context ownership.

These are applicable iOS product effects even though iOS may use an in-process Host/Runner boundary. The iOS implementation must preserve one canonical user-turn admission/dispatch owner, durable message identity and recent-history context, workflow-reference expansion, mentioned-Agent context, and offline-composed semantics before Runner execution. No status is inherited from Desktop. The affected rows remain unreviewed until the iOS shipping owners are audited against this exact responsibility; this upstream change does not invalidate the already-audited selected-image/media ownership unless that audit finds an ownership conflict.

### 11.4 Direct user-turn supersession rebaseline

Desktop PR #20 advanced from `bf36916c80e68737f02217ae85be4d22a6a5f928` to `3ad5c76a67408357cfe5647c6d073b36015c8eb5`. The shipping Host now treats a newly durably admitted direct local user turn as a supersession boundary: it cancels the current routed one-to-one Runner task for the same Agent with a stable `superseded by a new user message` reason, also preempts an applicable group-member run, records an acknowledgement interruption when an active run was actually interrupted, and emits turn-interrupt telemetry. `runner_registry.rs` resolves only the current routed stream for the Agent, so a stale/completed stream is not accidentally cancelled.

This behavior is applicable on iOS regardless of process topology. The iOS Host/Runner boundary must preserve current-run identity, targeted same-Agent cancellation, stale-run fencing, cancellation reason, acknowledgement settlement, and observable interruption lineage. A superseded run must settle as an interruption, not a provider failure: the stable supersession reason belongs to the canonical Runtime/Host operation owner, must not create an error tray, and stale/duplicate completion must not erase the replacement operation. Explicit user interruption remains a distinct reason. The changed Runner-registry responsibility remains incomplete until the iOS shipping task registry and direct user-send path are audited; no Desktop status is inherited.

### 11.5 Workflow-reference trace-context rebaseline

Desktop PR #20 advanced from `3ad5c76a67408357cfe5647c6d073b36015c8eb5` to `84dbe458a8f14307bbdeaff469388734e6ce8879` with a focused shipping correction: a visible workflow-reference run-now still re-enters the canonical `sendPrompt` path, but it does so without carrying a synthetic gateway trace context. This preserves the ordinary user-turn execution/telemetry boundary rather than manufacturing a gateway parent span for a locally synthesized workflow-reference turn.

The iOS workflow-reference responsibility remains unreviewed until its shipping owner is audited. No media or direct-turn supersession status changes are inherited from this upstream change.


### 11.6 Await-turn terminal settlement and pre-dispatch supersession rebaseline

Desktop PR #20 advanced from `84dbe458a8f14307bbdeaff469388734e6ce8879` to `3e735e6e5b7253713815ee1d034bd8ec446fb5a7` in two commits. The selected `frontend/**` + `source/**` inventory remains 7,925 files, but seven source-bearing blobs changed and the Desktop architecture manifest changed with them. Every affected ledger row is invalidated until revalidated against the iOS shipping path.

The eight changed Desktop files and their normative responsibility deltas are:

- `source/node-agent-coordinator/src/inference_router.rs`: Coordinator owns explicit `awaitTurn` parsing. Only boolean `true` requests terminal settlement, and workflow-reference run-now now sends `awaitTurn=true` plus `source=workflow-reference`.
- `source/node-agent-coordinator/src/main.rs`: request acceptance and turn completion are distinct. Ordinary sends settle the renderer request after queue admission; `awaitTurn` preserves that same request identity until `execute_local_inference` reaches terminal success or normalized failure/cancel.
- `source/node-agent-coordinator/tests/inference_host_boundary_contract.rs`: focused contract proves the workflow-reference metadata and terminal-request semantics.
- `source/host/src/extensions/transcript/runner_registry.rs`: Host canonical Runner registry now records `dispatched` and `recovery_shaped` per routed stream, and removes that state on finish.
- `source/host/src/runner/turn_run_shell.rs`: the active run records dispatch/recovery shape. Before actual dispatch, supersession is allowed only when the superseding turn carries recovery and the active turn is recovery-shaped; after dispatch normal targeted cancellation applies.
- `source/host/app/src/main.rs`: shipping composition wires recovery-shape registration and dispatch marking into the real routed turn path; this is not helper-only parity.
- `source/host/tests/runner_routed_provider_contract.rs`: focused Host contract proves the pre-dispatch/recovery-shaped fencing and dispatched-state behavior.
- `projects/grok-fabu-parity/architecture-manifest.json`: Desktop's own parity manifest promotes the corresponding send-turn-dispatch responsibility; this file is outside the iOS selected source inventory but is part of the audit evidence.

iOS disposition at this baseline:

- `MahayanaCoordinator.request/dispatchTransport` currently returns the Host's accepted response and does not expose an `awaitTurn` contract that keeps the same renderer request pending through terminal Runtime settlement.
- The iOS Runtime/Host already has stable operation identity, targeted same-conversation supersession, and stale-settlement fencing, but it does not yet model Desktop's pre-dispatch `dispatched + recovery_shaped` gate at the canonical Runner owner.
- The Coordinator terminal-settlement half is now implemented in the iOS shipping path: only literal `awaitTurn=true` on `feature.execute` holds the Coordinator request; `feature.execute` atomically registers the accepted `operationId`; Host-owned `feature.awaitOperation` advances the canonical Runtime event pump in bounded steps, remembers terminal completion/interruption/failure only for registered waiters, and re-enqueues translated Host events so the terminal waiter cannot become a second renderer event owner. Coordinator cancellation removes the waiter registration without inventing a terminal operation state.
- This implementation is not `verified` until the new iOS exact HEAD passes its own Rust/Swift/architecture/lifecycle acceptance. The changed Host Runner-registry/turn-shell rows remain `unreviewed`: iOS still lacks Desktop's canonical pre-dispatch `dispatched + recovery_shaped` supersession fence.
- Existing `send_pipeline` reply-target/thread/generated-attachment/fork gaps remain valid candidate work only after the remaining pre-dispatch supersession delta is handled; no old `84dbe458` acceptance evidence proves parity with `3e735e6e`.


### 11.7 Public recovery-shape helper export rebaseline

Desktop PR #20 advanced from `3e735e6e5b7253713815ee1d034bd8ec446fb5a7` to `a8cc75d1917ae8aa8c81d241f17cba57589bb4db` in one commit. The selected inventory remains 7,925 files and only two selected source blobs changed: `source/host/app/src/main.rs` and `source/host/src/runner/mod.rs`.

The change does not alter the recovery/supersession state machine introduced at `3e735e6e`. `runner/mod.rs` now publicly re-exports `is_recovery_shaped_turn`, while `host/app/src/main.rs` imports that helper through the public `runner` surface instead of the private `runner::turn_run_shell` path. Shipping composition still registers recovery shape before dispatch and marks the same routed stream dispatched; request/run identity, terminal settlement, targeted cancellation, recovery classification, and failure semantics are unchanged.

For iOS this export shape is not itself a required mechanism because the iOS Host/Runner boundary is iOS-owned and in-process. The applicable product responsibility remains the pre-dispatch `dispatched + recovery_shaped` supersession fence identified in section 11.6. The two changed Desktop rows are revalidated against `a8cc75d1`; no previous exact-HEAD CI is promoted to current parity evidence.



### 11.8 Deferred windowed Session activation rebaseline

Desktop PR #20 advanced from `a8cc75d1917ae8aa8c81d241f17cba57589bb4db` to `cbed42883dec4dbd12af2d54bd60d5855b3c0327` in two commits. Four selected Host blobs changed: `source/host/app/src/main.rs`, `source/host/src/extensions/transcript/roster_emit.rs`, `source/host/src/extensions/transcript/session_runtime.rs`, and `source/host/tests/transcript_session_runtime_contract.rs`.

The normative product responsibility added by this delta is Session activation after a bounded/windowed transcript read:

- the bounded response settles before a cold Session becomes the canonical active Agent;
- SessionRuntime assigns a monotonically supersedable activation generation and retains the target Agent plus the last transcript entry already shipped in the bounded response;
- only the latest matching generation/Agent may claim activation; explicit Agent switch and Agent deletion invalidate pending activation;
- after the claim, Host switches the canonical active Agent and emits only transcript entries strictly after the retained `shippedThroughId`; if that anchor is missing, it does not guess a catch-up range;
- roster projection is refreshed for the newly active Agent and the previously active Agent when they differ;
- ordinary gateway contact refreshes focus freshness only while the desktop window is focused, preserving the existing focus/staleness state machine.

iOS must preserve this responsibility but need not reproduce a desktop window or background thread. The iOS-native replacement should keep a generation-fenced pending conversation/Agent activation owner at the canonical session/runtime boundary, settle any bounded snapshot first, then apply the latest activation and delta catch-up through structured concurrency. iOS scene activity replaces desktop focus freshness where that product effect applies. The current iOS UI's local `selectedConversation` state and `markRead` call are only presentation state and are not accepted as a replacement canonical Session activation owner.

The iOS production disposition is now implemented in the canonical Rust Host path, but remains pending exact-HEAD verification:

- `mahayana-host-protocol` exposes typed `conversation.openWindowed` / `conversation.openTail` commands plus canonical window, append, activation, and activation-failure events. SwiftUI does not own activation truth.
- `FeatureHostController` owns `ConversationSessionState`: active conversation identity, pending activation generation, shipped-through anchor, explicit-switch/delete/session-reset invalidation, active-only contact freshness, and fail-closed catch-up.
- bounded/tail commands first enqueue the bounded window projection. Only after queued response events are drained does the Host event pump claim the latest pending generation, switch the canonical active conversation, emit entries strictly after the shipped anchor, emit the active-conversation projection, and refresh the canonical conversation roster. A newer bounded request replaces the prior pending claim.
- iOS does not create a desktop-style background thread for activation. The trusted Host event pump is the deferred task boundary, so there is no thread-spawn failure mode. Runtime/history failure after a claim is surfaced as `conversation.activationFailed` carrying both conversation identity and generation rather than silently switching or guessing.
- `IOSMainRuntime` forwards native scene active/inactive/background state through Coordinator → AppHost `feature.sessionActivity`; the freshness timestamp itself remains Rust Host-owned. Ordinary Host feature traffic only refreshes freshness while that canonical scene-active bit is true.
- the ordinary Runtime `ConversationHistory` command keeps its existing 500-message clamp and 200-message explicit-open read-acknowledgement contract. A separate canonical `ConversationHistoryWindow` path now delegates `beforeMessageId` / `afterMessageId` slicing to the owning `ConversationProvider`; the Kernel provider slices its full current canonical transcript, so bounded paging and shipped-through catch-up do not depend on the ordinary-history clamp and do not accidentally mark unread state as read. Missing anchors still fail closed.
- focused Rust contracts cover latest-generation supersession, explicit-switch invalidation, strict-after-anchor catch-up, missing-anchor fail-closed behavior, active-only freshness, stable command/event wire shapes, and provider-owned before/after window boundaries. They are production-focused implementation evidence only until the new iOS exact HEAD passes GitHub Actions.

Accordingly the four changed Host rows are `implemented`, not `verified`. Their known production semantics are now dispositioned; exact-HEAD CI remains required before promotion. Once that exact-head evidence closes, section 11.6's pre-dispatch `dispatched + recovery_shaped` supersession fence is again the earliest production gap. Existing supersession implementation work remains migration material because its Desktop source semantics are unchanged by this delta.


## 12. Frontend requirements

Desktop PR #20 `frontend/**` is the product/UI behavior source. iOS implements it natively in SwiftUI.

The goal is not pixel-identical desktop geometry. The goal is the same information architecture, product capabilities, state semantics, control meaning, and observable lifecycle, adapted to iPhone/iPad.

iOS presentation must consume canonical runtime projections and emit typed intents. It must not infer canonical run state from local booleans such as “busy” when runtime state exists.

## 13. Existing PR #3 implementation

The current PR #3 implementation is retained as migration material, not accepted wholesale.

Existing code must be classified against the pinned Desktop source:

- matches current Desktop responsibility -> may be promoted after evidence;
- derived from Grok but Desktop changed the responsibility -> stale, must be changed;
- implements a Desktop-removed/unauthorized feature -> remove;
- implements an iOS-native substitute for a Desktop responsibility -> retain after mapping/evidence;
- bypasses Desktop ownership boundaries -> refactor/remove.

No previous Grok-ledger count is a completion metric under this Spec.

## 14. Rebaseline protocol

Before any substantial new migration slice:

1. read Desktop PR #20 current exact HEAD;
2. compare it with the pinned SHA in this Spec and reference manifest;
3. if unchanged, continue against the existing baseline;
4. if changed:
   - record the new exact HEAD;
   - regenerate Desktop source inventory/blob identities;
   - diff added/removed/changed upstream paths;
   - invalidate stale row/evidence claims affected by the diff;
   - update this Spec/reference metadata;
   - only then continue implementation.

A green workflow for an older Desktop baseline does not prove parity with a newer PR #20 HEAD.

## 15. Implementation phases

### Phase 0 — Authority cutover

- replace Grok-direct authority with Desktop PR #20;
- pin Desktop exact HEAD;
- supersede the old Grok-direct Spec as an active authority;
- generate Desktop source manifest;
- create Desktop->iOS ledger with all rows initially unreviewed unless revalidated;
- change architecture CI to validate the Desktop-based baseline.

Exit: no active completion gate claims Grok-direct row counts as iOS parity.

### Phase 1 — Re-audit existing iOS architecture

Audit current `frontend/**`, `source/ios-main/**`, `source/ios-preload/**`, Coordinator, Host, Runner, shared/packages, and mobile bootstrap against Desktop PR #20.

Exit: every upstream source responsibility has a disposition and no inherited `implemented` status exists without Desktop comparison.

### Phase 2 — Runtime and contract parity

Port Desktop Coordinator/Host/Runner/shared/packages behavior required by iOS. Reuse Rust source directly when appropriate; otherwise use semantically equivalent iOS-owned implementations.

Exit: canonical send/stream/tool/cancel/retry/recovery paths match Desktop contracts.

### Phase 3 — iOS platform-main parity

Port Electron-main/preload responsibilities into iOS main/preload owners with native adapters.

Exit: no presentation layer owns platform/runtime orchestration.

### Phase 4 — Frontend/product parity

Port Desktop frontend product behavior to native SwiftUI, including iPhone/iPad layout adaptations.

Exit: product flows are driven by canonical Coordinator projections.

### Phase 5 — Communication/connectors/full product closure

Close all applicable Desktop PR #20 communication, MCP/connectors, automations, remote-computer, media, and product responsibilities.

### Phase 6 — Legacy removal

Delete Grok-direct compatibility paths and previous iOS bypass/fallback implementations that are not part of the Desktop-derived architecture.

### Phase 7 — Exact-HEAD acceptance

Run exact-HEAD GitHub Actions and packaged iOS acceptance, including archive/install and lifecycle recovery evidence.

## 16. Verification

All build/test work for this migration runs in GitHub Actions or the designated remote runtime. Do not use a local developer-machine build as acceptance evidence.

Architecture CI must fail when:

- Desktop source manifest and ledger differ;
- duplicate `desktop_path` rows exist;
- a row claims `implemented`/`verified` but its target is missing;
- a verified row lacks production/test evidence;
- a not-applicable row lacks an explicit platform reason/replacement;
- renderer bypasses Coordinator/Host ownership;
- another Fabushi source repository becomes required to build/run iOS;
- a shared Desktop/iOS runtime dependency is introduced contrary to this Spec;
- a stale Desktop exact HEAD is represented as current.

Final completion additionally requires all mandatory rows `verified` or reviewed `not-applicable`.

## 17. Acceptance criteria

- **AC-1**: Desktop PR #20 exact HEAD is explicitly pinned and provenance recorded.
- **AC-2**: 100% of selected Desktop `frontend/**` and `source/**` source-bearing files are present in the Desktop-based inventory and ledger.
- **AC-3**: Grok Bot 0.18 is no longer a direct iOS completion authority.
- **AC-4**: No shared Fabushi runtime repository is required for Desktop/iOS code reuse.
- **AC-5**: A clean iOS checkout owns all source/build inputs required by the iOS product.
- **AC-6**: Desktop -> iOS architectural correspondence in Section 4 is enforced.
- **AC-7**: Coordinator, Host, and Runner remain separate ownership boundaries on iOS even when implemented in one OS process.
- **AC-8**: Renderer does not own canonical operation/run/retry/transcript truth.
- **AC-9**: Electron-specific mechanisms are replaced by documented iOS-native adapters without silently dropping applicable product effects.
- **AC-10**: Existing PR #3 code is revalidated rather than grandfathered from the old Grok ledger.
- **AC-11**: Applicable Desktop Agent/chat lifecycle semantics are ported and verified.
- **AC-12**: Applicable MCP/connectors/tools behavior is ported and verified.
- **AC-13**: Applicable communication/messaging behavior in Desktop PR #20 is ported and verified.
- **AC-14**: iOS lifecycle/background/relaunch recovery preserves canonical durable state without duplicate execution.
- **AC-15**: Old bypass/fallback architectures are removed after cutover.
- **AC-16**: Architecture CI is based on the Desktop PR #20 source manifest/ledger.
- **AC-17**: Exact-HEAD compile/unit/contract/architecture/UI/lifecycle workflows pass on one final iOS SHA.
- **AC-18**: Exact-HEAD archive/export/install acceptance succeeds on the final accepted SHA.
- **AC-19**: Required rights/provenance review for reused source has no unresolved release-blocking item.
- **AC-20**: App Store/TestFlight delivery constraints have no unresolved release-blocking issue.
- **AC-21**: Final compliance table records every requirement/AC as passed, blocked, or not-applicable; mandatory completion requires all mandatory items passed.

## 18. Current compliance record

The authority cutover begins from iOS PR #3 exact HEAD `cdcbfd4344377b592ed882e049dfb1a36a534aa6`.

All implementation counts/statuses from the prior Grok-direct ledger are **historical only** until revalidated against Desktop PR #20 `84dbe458a8f14307bbdeaff469388734e6ce8879`. The current baseline contains 7,925 source-bearing `frontend/**` + `source/**` files. Relative to the immediately previous iOS baseline `95995bdf36a9687788e106c8544d292b2bb0877f`, Desktop advanced to `dcb19a94383833fc1ec5074f10c4bbbd28c09036` with exactly two source-bearing changes under the authoritative roots: `source/host/src/selected_image_inputs.rs` and `source/host/tests/transcript_send_echo_contract.rs`. Desktop then advanced from `bbc7b34a5f6dad46e3d4ca88fe21cc4f7932ce09` to `dcb19a94383833fc1ec5074f10c4bbbd28c09036` only by accepting the send-message-shaping architecture row; no `frontend/**` or `source/**` blob changed. The full 7,925-row source inventory was revalidated against the dcb19a tree with zero missing paths and zero blob mismatches. The newly accepted Desktop responsibility does not transfer status to iOS: send_message_shaping.rs, selected_image_inputs.rs, and agent_to_agent_messaging.rs are explicitly re-audited independently. The iOS port may advance a row only after its own Host-owned production path exists. The production change adds native ISO-BMFF HEIC/HEIF/AVIF primary-image dimension extraction with rotation handling; the test change adds focused contract coverage. All other 7,923 source-bearing blob identities are unchanged. Previously reviewed Coordinator `carrier.rs` and `client_side_tool_v2_relay.rs` blobs are unchanged, so their `implemented` status is preserved, but neither may be promoted to `verified` without exact-HEAD iOS CI and the relay's adjacent Host producer closure described above.

| Item | Status | Evidence / reason |
| --- | --- | --- |
| AC-1 | passed | Desktop PR #20 repository/PR/branch/exact HEAD are pinned in this Spec. |
| AC-2 | passed | All 7,925 selected Desktop source paths/blob identities were revalidated against the pinned dcb19a tree with zero missing paths and zero blob mismatches; manifest and ledger sourceCommit metadata are rebound to this authority. |
| AC-3 | passed | This Spec explicitly demotes Grok to historical provenance and supersedes the old direct authority. |
| AC-4 | passed-by-design | Standalone source ownership and no-shared-runtime rule are normative; repository audit still guards regression. |
| AC-5 | pending | Existing PR #3 is designed standalone; exact-HEAD clean-checkout acceptance must be rerun after rebaseline. |
| AC-6..AC-16 | pending | Existing implementation requires Desktop-based re-audit. |
| AC-17 | pending | New exact-HEAD CI evidence required after authority-cutover commits. |
| AC-18 | pending | Packaged acceptance required after implementation closure. |
| AC-19 | blocked | Reused-source provenance/right review must be updated for Desktop PR #20 source reuse. |
| AC-20 | pending | Final delivery evidence required. |
| AC-21 | pending | Final compliance review not yet complete. |

## 19. Superseded authority

`docs/specs/grok-bot-0.18-ios-architecture-parity.md` is retained only as historical migration context after this Spec lands. Where it conflicts with this document, this document wins.

The old Grok reference manifest and Grok parity ledger may remain temporarily for audit/history, but must not be used as the active architecture-completion gate after the Desktop-based gate is enabled.
