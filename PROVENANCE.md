# Fabushi iOS provenance and redistribution boundary

This repository is the standalone iOS product implementation for Fabushi. This
record distinguishes Fabushi-owned migration material from the pinned Grok Bot
0.18 reconstruction used as architecture and behavior evidence.

## Fabushi migration source

- Source repository: `bhrumom/fabushi`
- Source commit recorded by this repository: `7851b689d2fe3fc3893cd9f4363899cc4a03e83b`
- Original exported roots: `mobile/ios` and `mobile/native/include`
- Migration record: `MIGRATION_SOURCE.md`

The standalone repository subsequently owns its iOS product runtime, contracts,
Coordinator, Host, Runner, shared sources, packages, build scripts, and release
integration. It must not require another Fabushi repository to compile or run.

## Grok Bot 0.18 parity reference

- Reference repository: `b-nnett/grok-bot-0.18-reconstructed`
- Pinned reference commit: `a9f633e09d49a85829b8236331b9e21f7e612634`
- Product represented by that reconstruction: Grok Bot 0.18.0
- Upstream macOS bundle identifier reported by the reference: `com.anysphere.sand`
- Original macOS DMG SHA-256 reported by the reference:
  `a253ccd8aab01e083f9812a0264354c5034d8ba7f0610bbb557e82ae77d203eb`
- Original `app.asar` SHA-256 reported by the reference:
  `6665408168466f9cacc6087e917890c17f59d2e2e9c2404a5c4a59ad79c1de58`

The pinned reconstruction is treated as an evidence source for module
responsibilities, observable behavior, contracts, and architecture boundaries.
It is not represented here as Anysphere's authored source and this repository
does not claim an upstream Grok Bot source-code license.

The reference repository's NOTICE states that no upstream source-code license is
asserted or granted and that redistribution requires independent copyright,
trademark, dependency, and service-terms review. Its PROVENANCE record likewise
requires evidence-backed reconstruction rather than invented behavior.

## Identity and signing

Fabushi uses its own application identity (`com.ombhrum.fabushi`) and its own
Apple signing material. It must not reuse or claim the upstream application's
bundle identity, signature, notarization, or endorsement.

## Release-blocking rights review

The machine-readable release decision lives at
`docs/release/ios-rights-review.json`. Apple Store delivery is required to
fail closed unless that record is explicitly approved and has no remaining
release-blocking items.

This provenance record is technical evidence, not a legal opinion. A build,
test, archive, or successful App Store validation does not by itself resolve
copyright, trademark, third-party license, privacy, or service-terms questions.
