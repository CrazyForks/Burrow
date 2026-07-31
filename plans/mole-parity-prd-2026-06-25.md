# PRD — Close the Mole feature gaps (non-signing)

> Historical scope. Burrow's Developer ID and notarization release path landed
> in #312; the excluded resident privileged-helper features are still excluded
> because signing alone does not make their product and safety trade-offs go away.

> Local planning doc. **Not** filed as a GitHub issue (per request). Scope = every gap from the 2026-06-25 Burrow-vs-Mole audit **except** the three that require a Developer-ID-signed resident privileged helper (Battery Care, Fan control, the helper itself) — see Out of Scope.
>
> **Now also folds in two competitor-scan epics** (sourced from `competitor-feature-scan-2026-06-25.md`): **α — Process Inspector** (from ProcessSpy: deepen Status into a real inspector) and **β — Get Online → travel companion** (from Hotspot Guide: extend the shipped Get Online pane). Neither needs Developer-ID signing; β has one open permission decision (CoreWLAN + Location — see Cross-cutting decisions).

## Problem Statement

Burrow and Mole (mole.fit) both ride the `mo` engine, so our Clean / Optimize / Uninstall / Analyze **coverage** is largely at parity. But Mole's app has pulled ahead on two fronts a user actually notices: **native macOS features the engine doesn't provide** (system diagnostics, login-item management, update installation, privacy/awake utilities, process forensics) and **GUI/render polish** (treemap legibility, progressive scans, lifetime stats, keyboard/refresh affordances). A user comparing the two sees Burrow as the thinner, less-finished app even though the cleaning power is equivalent. We want to close that perceived and real gap without taking on the one thing we can't ship today — a signed privileged helper.

## Solution

A multi-phase program that brings Burrow to parity (or ahead) on everything that does **not** require Developer-ID code signing. The work splits into deep, independently testable "decision" modules (version gating, sizing, classification, parsing, posture) wrapped by thin impure seams (shell-outs, IOKit reads, render code), plus a set of pure GUI/UX refinements. Phase 1 is the cheap, high-leverage polish that makes the app feel finished; Phase 2 adds the native subsystems (modern login items, security posture, process forensics, real update resolution); Phase 3 is the heavy installer/forensics work. Everything ships behind the existing ad-hoc distribution — no new entitlements or signing.

## User Stories

**Software / Updates**
1. As a Mac user, I want App Store updates that require a newer macOS to be hidden, so that I'm not prompted to install something my Mac can't run.
2. As a Mac user, I want an App Store row to clear only once the on-disk version actually changes, so that a "still available" update doesn't linger after I've updated.
3. As a developer, I want Burrow to find updates for apps that publish only on GitHub Releases, so that I don't miss updates for tools without Sparkle/App Store feeds.
4. As an Electron-app user, I want Burrow to tell me an actual newer version exists (not just a badge), so that the Updates tab is trustworthy.
5. As a power user, I want to filter the update check by source (only Homebrew, only Sparkle, etc.), so that I can run a fast targeted check.
6. As a keyboard user, I want ⌘R to refresh the Updates list, so that I don't have to reach for the mouse.
7. As a user, I want a manual refresh to bypass stale catalog/HTTP caches, so that I see truly current versions.
8. As a user, I want a badge on the Software tab counting unseen app updates, so that I know when to look without opening the pane.
9. As a Homebrew user, I want casks and formulae distinguished in the list, so that I understand what each update is.

**Uninstall**
10. As a user, I want an app's removal details to appear as I hover its row, so that I can preview what will be deleted without clicking.
11. As a user, I want a "Clear Data" action that wipes an app's data but keeps the app, so that I can reset an app without reinstalling it.
12. As a Homebrew user, I want cask apps removed with `--zap`, so that artifacts a file scan misses are also cleaned.
13. As a bilingual / iOS-app user, I want wrapped iOS apps and bilingual-named apps detected and searchable, so that I can find and remove them.
14. As a user, I want search to resolve app aliases, so that typing a common alternate name still finds the app.
15. As a user, I want input methods (e.g. WeChat/Doubao) surfaced clearly as removable leftovers, so that they don't hide in an "Other" bucket.
16. As a user, I want root-owned leftover items I tick to be removed via an admin prompt instead of silently failing, so that the removal actually completes.
17. As a user, I want Burrow to say plainly when nothing was selected/removed, so that I'm never misled into thinking a clean sweep happened.
18. As a user, I want an app's installer **receipts** linked into its removal set, so that uninstalling forgets the package too.

**Startup items**
19. As a user, I want modern Login Items / background items (the System Settings list) shown alongside LaunchAgents, so that I see everything that auto-starts.
20. As a user, I want a LaunchAgent that targets an **unplugged external drive** to not be flagged as "broken", so that I don't delete something that's actually fine.
21. As a user, I want a one-click cleanup for genuinely broken login items, so that I can remove dead entries without editing plists.
22. As a user, I want "Reveal" to open the target app (not the plist) and locked rows to deep-link into System Settings, so that I can act on items Burrow can't toggle directly.

**Clean**
23. As a user, I want clean results sorted by deletion impact (safest/regenerable first), so that I can skim and trust the top of the list.
24. As a user, I want credential/keychain remnants flagged with a distinct caution badge, so that I review them deliberately instead of treating them as ordinary cache.
25. As a user, I want my lifetime cleanup total shown on the Clean completion screen, so that I see the cumulative payoff where I just acted.
26. As a user, I want to see the path currently being scanned, so that the scan feels live and accountable.
27. As a user, I want section cards to appear and fill in progressively as the scan runs, so that I'm not staring at one number.
28. As a user, I want the macOS wallpaper cache protected by default, so that cleaning never blanks my desktop.
29. As a user, I want reclaim figures that don't double-count hardlinked files, so that the "space freed" number is honest.
30. As a user, I want root-owned items to go to a recoverable location even in Trash mode, so that I can undo a mistaken removal.

**Optimize**
31. As a user, I want Burrow to warn me before optimizing when a VPN, external audio device, external display, or a Bluetooth keyboard/mouse is active, so that a maintenance run doesn't disrupt something I'm using.
32. As a user, I want user-visible fixes grouped/surfaced first in the results, so that the outcome reads as a clear summary.

**Analyze**
33. As a user, I want tiny cells folded into a single "Other" cell and huge flat folders' long tails collapsed, so that the treemap stays legible and the picture matches the total.
34. As a user, I want app cells to show their real app icons, so that I can recognize apps at a glance.
35. As a user, I want long cell names to middle-truncate and show the full name on hover, so that I can read what a cell is.
36. As a user, I want tall narrow cells to rotate their label, so that I can read them too.
37. As a user, I want the big cells to draw immediately and slower folders to fill in, so that I don't wait on a blank pane.
38. As a user, I want to optionally start Analyze on the whole disk, so that I can see system-wide usage, not just Home.
39. As a user on a many-core Mac, I want sizing concurrency tuned to my machine, so that the scan is fast without pinning the CPU.

**Status / Menu bar**
40. As a user, I want to tap a process and see where it came from (its shell / SSH session), so that I understand what a mystery process is.
41. As a security-minded user, I want a warning when a process runs from a deleted or replaced binary, so that I can spot tampering.
42. As a user, I want the menu-bar network badge to reflect the interface actually carrying traffic, so that the readout is meaningful.
43. As a user, I want the menu-bar runner available on by default with a planet/character-style option whose cadence can track my display, so that the menu bar feels alive like Mole's.
44. As a user, I want the menu-bar item to come back automatically if Control Center drops it, so that I don't lose Burrow until I relaunch.

**Doctor**
45. As a user, I want Doctor to report SIP, Gatekeeper, FileVault, and firewall status, so that I know my security posture at a glance.
46. As a user, I want Doctor to include battery-health and high-CPU checks, so that the report reflects what's actually stressing my Mac.
47. As a user, I want display, external-volume, and network context in Doctor, so that a shared report carries the details a maintainer needs.
48. As a user, I want a "Copy diagnostics" button, so that I can paste the report into a support thread in one tap.

**Everyday / Privacy / fit-and-finish**
49. As a laptop user, I want Keep Screen On to optionally keep tasks running with the lid closed, so that a backup or render doesn't die when I shut the lid.
50. As a user, I want an active Keep-Screen-On session to be restored after a relaunch, so that my intent survives a restart.
51. As a privacy-minded user, I want a notification when my camera or microphone turns on, so that I notice usage without watching the popover.
52. As a user, I want to choose the Clean Screen color and exit via a deliberate move-and-hold, so that wiping is flexible and I don't exit by accident.
53. As a user, I want a dark-mode adaptive app icon and a native full-screen shortcut, so that the app matches platform expectations.
54. As a VoiceOver/keyboard user, I want labels on the main panes' metrics and controls and visible keyboard focus, so that the whole app is usable without a mouse.

**α — Process Inspector (from ProcessSpy)**
55. As a power user, I want a rich inspector panel for a selected process (identity, command line, launched-by, arch/native-vs-Rosetta, sandbox/hardened/signing/entitlements), so that I understand exactly what a process is.
56. As a power user, I want per-process resource detail — CPU user/sys split, QoS class, memory footprint + peak, page-ins, threads, and per-process disk I/O — so that I can diagnose what a process is doing.
57. As a user, I want a per-process **network** up/down readout in the table and inspector, so that I can see which process is eating my bandwidth (a thing ProcessSpy refuses to do).
58. As a user, I want a **watchdog** that alerts me — and can optionally quit or suspend a process — when one holds high CPU/memory/disk for a sustained time, so that runaway processes get caught automatically.
59. As an automation user, I want to run a macOS Shortcut when a process matching a rule spawns / exits / crosses a threshold, so that I can wire process events into my own workflows.
60. As a power user, I want a process tree/hierarchy view with summed CPU/memory/threads (XPC children linked), so that I can see a process and its children together.
61. As a power user, I want predicate/expression filters and saved filter tabs (unsigned, ANE/Neural, startup, recent, app-specific), so that I can slice the process list precisely.
62. As a user, I want a per-row mini CPU graph, so that I can spot a spiking process at a glance.
63. As a user, I want to suspend and resume a process (and have resume actually work), so that I can pause a heavy task without killing it.
64. As a user, I want to reveal a process's open files in Finder, so that I can see what it's touching.
65. As a user, I want recently-finished processes kept visible with their last metrics, so that I can investigate something that already exited.
66. As a user, I want to export the visible process list to JSON/CSV, so that I can share or analyze it.

**β — Get Online → travel companion (from Hotspot Guide)**
67. As a traveler, I want Burrow to recognize the venue/airline by network name and show its known portal quirks + bypass tips, so that I know what to try before guessing.
68. As a traveler, I want a history of my connection attempts per network — success/failure, measured speed, and what went wrong — so that I know which networks (or lounges) actually work.
69. As a traveler, I want an accurate speed test with jitter and packet loss, so that I can tell a slow connection from a flaky one.
70. As a user at home, I want a Home mode showing my network details and the surrounding Wi-Fi networks (signal, channel, security), so that I can troubleshoot my own network too.
71. As a traveler, I want the troubleshooting guides to work with no connectivity, so that I can read them exactly when I'm offline.
72. As a user, I want the checks to run as a visible staged sequence and show lifetime stats (networks, checks, portals fixed), so that the run feels alive and I see the payoff.
73. As a returning traveler, I want Burrow to optionally remember and autofill my portal login per network, so that re-joining a hotel chain is one tap. *(niche; depends on an embedded portal browser — see Out of Scope.)*

## Implementation Decisions

**Architecture.** Each gap is split into a **deep, pure decision module** (the testable core) and a **thin impure seam** (shell-out / IOKit / render / persistence). This mirrors the existing pattern (e.g. the nettop and scutil parsers are pure; sampling is the seam). No new entitlements, no signing, no resident helper — elevation, where needed, reuses the existing one-shot `osascript … with administrator privileges` broker (already used for Clean/Optimize and the Connectivity flush-DNS/renew-DHCP fixes).

**Deep modules to build (pure cores), each with a stable, narrow interface:**
- **OSUpdateGate** — inputs: an app's `minimumOsVersion` + the running OS version; output: installable / blocked. Also re-reads the on-disk version to clear a row.
- **GitHubReleaseResolver** — inputs: repo coordinates + installed version + a release-list payload; output: newer version / none. Plus a bundle→repo heuristic.
- **ElectronVersionResolver** — resolves an Electron app's latest version from its update feed; pure parse over the fetched payload.
- **UpdateSeenStore** — diff of current available-update set vs a persisted "seen" set → unseen count for the badge.
- **CleanImpactRanker** — assigns a safety/impact rank to a clean category/item → review-list ordering.
- **SensitiveRemnantMatcher** — flags credential/keychain-style paths for a caution badge.
- **HardlinkAwareSizer** — given a path set and an inode/nlink provider, computes exclusive bytes (de-counts shared inodes). Phase-3 full version; Phase-1 ships a cheaper "de-dup obvious double-counts" variant.
- **TreemapTail** — folds the long tail (by area/count threshold) into one inert "Other" cell before layout.
- **LoginItemsReader** — parses the modern background-task-manager dump (`sfltool dumpbtm`-style) into login/background items, merged with the plist scan.
- **RemovableVolumeGuard** — given a missing executable path + the mounted-volume set, classifies "on an unplugged removable drive" vs "broken."
- **ReceiptLinker** — parses `pkgutil` output, maps receipts → bundle id, lists forgotten files for the uninstall set.
- **SecurityPosture** — parses `csrutil status` / `spctl` / `fdesetup status` / firewall state into SIP/Gatekeeper/FileVault/firewall verdicts (each a tiny pure parser).
- **ProcessOrigin** — given a ppid chain + controlling tty + ancestry, classifies a process's launch origin (login shell / Terminal session / sshd connection).
- **BinaryIntegrity** — given a running exe path + on-disk state, classifies intact / deleted / replaced.
- **OptimizeGuards** — given VPN / external-audio / external-display / BT-input state, emits pre-run warnings (reuses the existing VPN detector).
- **UninstallPlanner additions** — `DataOnly` subset (everything except the `.app`), cask-zap token derivation, input-method/iOS-wrapper/bilingual classification + alias index.

**α — Process Inspector modules (pure cores):**
- **ProcessInspectorReader** — reads QoS / footprint+peak / page-ins / user-sys split / per-process disk I/O / threads / arch (Rosetta) via `proc_pidinfo` / `proc_pid_rusage`; the syscall is the seam, field decoding is pure. Composes with **ProcessOrigin** + **BinaryIntegrity** (already above) + **NetUsage** (per-pid bandwidth, already built for Ports) to populate one inspector panel.
- **ProcessRule / ProcessWatchdog** — given a rule (match predicate + metric + threshold + sustain window) and the per-process sample stream, decides fire/clear and the action (notify / quit / suspend). Pure rule eval, same shape as **AlertEngine**; the sampler + signal/Shortcut dispatch are seams. Also drives **Shortcuts-on-process-event** (spawn/exit/threshold).
- **ProcessTree** — folds the flat ppid list into a parent→children tree with summed CPU/memory/threads; XPC children linked by responsible pid. Pure.
- **ProcessFilter** — evaluates a filter expression over a process record (see filter-language decision); pure. Saved smart tabs are presets over it.
- **ProcessExport** — serialize the visible set to JSON/CSV; pure.

**β — Get Online companion modules:**
- **VenueMatcher** — given an SSID + the bundled, community-extensible venue/airline catalog, returns the matched venue + its tips. Pure (the SSID read is a seam, gated on CoreWLAN+Location).
- **ConnectionHistoryRecorder** — records per-attempt events (SSID, result, measured speed, failure reason) into the existing SQLite history DB; the failure-reason classification reuses the Get Online probe verdicts (pure), the DB write is the seam.
- **SpeedTest** — multi-stream throughput + jitter + packet-loss; the network transfer is the seam, the sample→result aggregation is pure (single-stream undercounts badly — see the earlier connectivity research).
- **NearbyNetworks** — CoreWLAN scan → per-network RSSI / channel / channel-congestion / security; the scan is the seam (needs Location), the sorting/congestion read-out is pure.

**Modified surfaces (thin seams + GUI):** Updates pane (gate/resolvers/filter/badge/⌘R/cache-policy), Uninstall flow (hover pre-scan, Clear-Data, zap branch, root-owned via broker, receipts), Startup segment (BTM merge, removable-drive guard, broken cleanup, reveal-app + Settings deep-link), Clean (impact sort, sensitive badge, lifetime total on done screen, live path, progressive sections, wallpaper default-protect), Optimize (pre-run guard banner), Analyze treemap (Other-fold, real icons, hover tooltip, rotated labels, progressive entries, whole-disk option, core-count concurrency, mtime cache invalidation), Status/menu bar (process-origin inspector, binary-integrity badge, default-route badge interface, runner default + planet variant + display-Hz cadence, Control-Center restore watchdog, incremental rows, lazy GPU), Doctor (security/battery/CPU/display/volume/network checks + copy button), Everyday (lid-closed assertion + restore, Clean Screen color + move-and-hold, camera/mic start notification), and app-level fit-and-finish (dark-mode appicon variant, full-screen command, accessibility-label sweep). **α** — Status process view (inspector detail panel + tree view + per-process net/QoS/footprint/page-ins/disk columns + watchdog rules + predicate filters/saved tabs + per-row sparkline + suspend/resume + reveal-open-files + recently-finished recall + JSON/CSV export). **β** — Get Online pane (venue auto-detect/picker + per-network connection history + multi-stream speed test + Public/Home mode + nearby-networks scanner + bundled offline guides + lifetime stats + staged check run).

**Elevation policy.** Anything requiring root (root-owned trash, pkgutil --forget, batch login/agent removal) goes through the existing one-shot osascript admin broker — never a resident helper. If a given action can't be done acceptably with a single per-action prompt, it is deferred rather than gated on signing. (α's suspend/resume + quit are plain `kill`/`SIGSTOP`/`SIGCONT` on the user's own processes — no elevation.)

**Cross-cutting decisions (resolve before building the dependent items):**
- **CoreWLAN + Location permission** — yes/no. Gates **β**'s SSID auto-detect (→ VenueMatcher), Public/Home mode, and NearbyNetworks scanner. If declined, β degrades gracefully to a manual venue picker + connection history + speed test + offline guides (still useful, no SSID). The Mole-gap audit previously *deferred* Wi-Fi SSID/signal scanning for this reason; β is the case to reconsider it. One permission unlocks three β features.
- **Filter language for ProcessFilter** — embedded JS (ProcessSpy's choice) vs a small typed predicate DSL. The typed DSL likely fits Burrow's agent-native angle better (no JS runtime, same predicates usable from MCP/agents) and avoids shipping a JS engine; decide before α's filter work.
- **Per-process deep-metrics reader** (`proc_pidinfo`/`proc_pid_rusage`) is built **once** and feeds the whole α inspector — sequence it first within α.

## Testing Decisions

**What a good test is here:** exercise a module's external behavior through its public interface against **captured real-world fixtures**, never its internals. The codebase's parser tests are the model — e.g. the connectivity parsers are tested against real `scutil`/`route` output, the nettop parser against a real `nettop` frame, the clean-list/disk-scanner parsers against captured engine output. New pure modules follow the same shape: feed recorded command output / version strings / path sets in, assert the decision out.

**Modules to cover with tests (the pure cores):** OSUpdateGate, GitHubReleaseResolver, ElectronVersionResolver, UpdateSeenStore, CleanImpactRanker, SensitiveRemnantMatcher, HardlinkAwareSizer, TreemapTail, LoginItemsReader, RemovableVolumeGuard, ReceiptLinker, SecurityPosture (one case per tool's output), ProcessOrigin, BinaryIntegrity, OptimizeGuards, and the UninstallPlanner additions (DataOnly subset, cask-zap token, classifiers/alias index). **α:** ProcessInspectorReader (field decode from a captured `proc_pidinfo` blob), ProcessRule/Watchdog (fire/clear over a synthetic sample stream + correct action), ProcessTree (tree shape + summed aggregates), ProcessFilter (predicate eval), ProcessExport (JSON/CSV shape). **β:** VenueMatcher (SSID→venue+tips against the catalog), ConnectionHistoryRecorder's failure-reason classifier (probe-verdict → reason), SpeedTest sample→result aggregation (jitter/loss math), NearbyNetworks sorting/congestion read-out.

**Not unit-tested (integration / impure seams):** render code (treemap drawing, label rotation, real-icon compositing), IOKit/IOPMAssertion calls, `NSStatusItem` visibility watchdog, notification posting, osascript-admin spawns, and live network installs. These are verified by build + hand-test, consistent with how the native enumeration and render paths are handled today.

**Prior art to copy:** `ConnectivityTests`, `NetUsageTests`, `CleanListTests`, `DiskScannerTests`, `AnomalyScanTests`, `DoctorTests`, `PortInspectorTests` — same fixture-in / verdict-out structure.

## Out of Scope

- **Battery Care** (hold charge ~80% / resume <75%), **Fan control** (Auto/Cool/Quiet presets), and the **shared resident signed privileged helper** they both require. These need a Developer-ID-signed `SMJobBless`/`SMAppService` LaunchDaemon that writes SMC / charge-controller keys; Burrow ships **ad-hoc (no Developer ID)**, so a resident helper can't be installed/trusted. Explicitly excluded per request. (We keep the existing read-only SMC fan-RPM monitoring.)
- **Bundling RunCat's actual cat artwork** or any third-party runner art — licensing. The runner work ships **original/programmatic** runners only (the planet/character variant is our own art/shapes).
- **Per-app camera/mic attribution + "mute trusted apps" + suppressing Siri/dictation as false alarms** — this needs per-app device-usage attribution that may require private APIs/entitlements; the camera/mic **start notification** (system-level) is in scope, the per-app attribution layer is parked pending feasibility.
- **Managed website-installer download-cache + notarization-verify install** beyond the serial Update-All flow is Phase 3 and may be reduced if it proves to need more than a single admin prompt per app.
- **β: embedded portal browser + per-network credential autofill** (story 73) — needs a bundled web view + a Keychain credential store; parked as niche, revisit only if the rest of β lands well.
- **Embedding a JavaScript runtime for process filters** — avoided in favor of a typed predicate DSL (see Cross-cutting decisions); reconsider only if the DSL proves too limiting.
- Anything already at parity or where Burrow exceeds Mole (see the audit's "match/exceed" list) — no work.

## Further Notes

- **Phasing (by value ÷ effort).**
  - **Phase 1 — quick wins / polish:** OSUpdateGate, ⌘R + cache-bypass, Doctor (battery/CPU + copy + SIP/Gatekeeper/FileVault/firewall), Clean impact-sort + sensitive-badge + lifetime-total-on-done + live-path + wallpaper-protect, treemap Other-fold + tooltip + real icons, Keep-Screen-On lid-closed + restore, Clean Screen color + move-and-hold, dark-mode appicon, full-screen shortcut, uninstall Clear-Data + alias search + input-method + "all-skipped" message + hover pre-scan, startup removable-drive guard + broken cleanup + reveal-app + Settings deep-link, net-badge default-route interface, hardlink double-count de-dup.
  - **Phase 2 — native subsystems:** GitHub/Electron resolvers + source filter + unseen badge + cask split, LoginItemsReader (BTM), ReceiptLinker + cask `--zap` + iOS-wrapper detection, OptimizeGuards, treemap progressive render + rotated labels + core-count concurrency + whole-disk scope + mtime invalidation, ProcessOrigin + BinaryIntegrity inspector, Control-Center restore watchdog, camera/mic start notification, runner-on-by-default + planet variant + display-Hz cadence, root-owned trash via broker, incremental process rows + lazy GPU, accessibility-label sweep.
  - **Phase 3 — heavy:** managed serial Update-All / installer, full HardlinkAwareSizer, Dock-ghost + one-prompt batch login/agent removal at uninstall.
  - **Epic α (Process Inspector) — sequence:** α1 deep-metrics reader + **per-process network column** (near-free, reuses NetUsage) → α2 **watchdog + actions + Shortcuts-on-event** (reuses AlertEngine — top ask) → α3 inspector panel (composes ProcessOrigin + BinaryIntegrity) → α4 tree view + predicate filters/saved tabs + per-row sparkline → α5 suspend/resume + reveal-open-files + recently-finished recall + export.
  - **Epic β (Get Online companion) — sequence:** β1 connection history (reuses the DB) + lifetime stats + staged check run → β2 venue/airline tips DB (curated + community JSON) → β3 multi-stream speed test → β4 *(gated on CoreWLAN+Location)* nearby-networks scanner + Public/Home mode → β5 offline guides.
- **Highest-ROI shortlist across all epics (build first):** per-process network column (α1) · per-process watchdog + actions + Shortcuts (α2) · connection history + venue DB (β1/β2) · inspector panel + the `proc_pidinfo` reader (α3). All reuse existing infra (NetUsage, AlertEngine, the history DB, ProcessOrigin/BinaryIntegrity) and are the most visible depth wins.
- **Engine caveat.** A few "gaps" are partly the `mo` engine's job (external-Applications enumeration, some leftover breadth, optimize task ordering). Where the engine already covers it, the app change is just surfacing/guarding; where it doesn't, the module above owns it. Items that would require changing `mo` itself are flagged in their issue, not solved here.
- **No third-party-app coupling.** Update resolvers and receipt/zap logic must degrade gracefully (an app with no resolvable source simply shows no update, never a wrong one) — same honesty bar as the rest of the app.
- This doc stays in `plans/`; do not file as a GitHub issue or push without an explicit go-ahead.
