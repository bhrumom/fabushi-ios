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
- pinned source commit for this baseline: `95995bdf36a9687788e106c8544d292b2bb0877f`
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

All implementation counts/statuses from the prior Grok-direct ledger are **historical only** until revalidated against Desktop PR #20 `95995bdf36a9687788e106c8544d292b2bb0877f`. The current baseline contains 7,925 source-bearing `frontend/**` + `source/**` files. Relative to the immediately previous source-bearing baseline `f782c0c8fb6e2641c64d3daf25ebe0a9bcc3b110`, Desktop advanced by three commits that only modify `projects/grok-fabu-parity/architecture-manifest.json`, which is outside the authoritative iOS inventory roots `frontend/**` + `source/**`. Therefore all 7,925 source-bearing paths and blob identities are unchanged in this rebaseline. The prior `f782c0c8` step changed only `source/host/tests/runner_routed_provider_contract.rs` (blob `cc5ef858c2ecc9ee79746b56225c4b4ab9e9be16`) and strengthened current-stream watchdog cancellation evidence without changing production source. The previously reviewed `source/node-agent-coordinator/src/carrier.rs` blob is unchanged, so its iOS status remains `implemented` but requires new exact-HEAD iOS CI before promotion to `verified`.

| Item | Status | Evidence / reason |
| --- | --- | --- |
| AC-1 | passed | Desktop PR #20 repository/PR/branch/exact HEAD are pinned in this Spec. |
| AC-2 | pending | Desktop source manifest/ledger is being regenerated from the pinned Desktop HEAD. |
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
