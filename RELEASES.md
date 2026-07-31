<!-- Latest release ONLY. This file is the GitHub release body (release.yml --notes-file), so it must contain just the newest version. OVERWRITE it each release; do not accumulate. Full prose history lives in docs/releases.json → docs/releases.html (the site Releases page). -->

# Burrow 0.11.0

Burrow's first Developer ID signed and Apple-notarized release. Gatekeeper can
verify the app before first launch, and official tags now fail closed instead
of publishing an unsigned or un-notarized build.

> Upgrading from 0.10.5 or earlier changes Burrow from an ad-hoc identity to a
> stable Developer ID identity. macOS may ask you to grant Full Disk Access one
> final time; subsequent signed updates keep the same identity.

## Improved
- **Official downloads are trusted by Gatekeeper.** The app and every bundled
  executable carry a Developer ID signature, hardened runtime, secure
  timestamp, and a stapled Apple notarization ticket. Direct-download users no
  longer need to strip quarantine or use the right-click Open workaround.
- **Full Disk Access has a stable identity.** Developer ID gives macOS one
  consistent code identity across releases, so privacy grants can survive
  normal updates after the one-time transition from an older ad-hoc build.
- **Privacy disclosures match the app.** The bundled privacy manifest declares
  Product Interaction, Other Usage, Crash, Performance, and Other Diagnostic
  data as unlinked and non-tracking. Analytics and crash reporting remain
  opt-out, and signing adds no telemetry.

## Security
- **A tag cannot publish a partially trusted build.** The release stops before
  packaging or publication unless signing, notarization, ticket stapling,
  strict code-sign verification, and Gatekeeper assessment all succeed.
- **Homebrew preserves Apple's security checks.** Only after the notarized
  artifact passes every gate does the workflow remove Burrow's legacy
  quarantine bypass and unsigned warning from the live cask.
  ([#312](https://github.com/caezium/Burrow/pull/312))
