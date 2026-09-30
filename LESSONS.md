# LESSONS

Append-only log of debugging lessons for Nightglow and nightglow.io.

## 2026-09-29T19:20 - Bundled app crashed at launch; the bare binary worked

**Problem**: `Nightglow.app` died instantly after `open` (no process, no window), while `.build/debug/Nightglow --status` and `--probe` ran fine.

**Root Cause**: `UserDefaults(suiteName: "fyi.micah.nightglow")!`. Foundation returns nil when the suite name equals the main bundle identifier. Only the bundled app has that bundle id, so the force-unwrap trapped there and nowhere else. The crash report (`~/Library/Logs/DiagnosticReports/Nightglow-*.ips`, faulting thread frames) pointed straight at `Preferences.swift:22`.

**Lesson**: Anything keyed on the bundle identifier behaves differently between `swift run` and the installed `.app`. Test the installed bundle, and read the `.ips` before guessing.

**Solution**: `SettingsStore.userDefaults(suiteName:mainBundleIdentifier:)` returns `.standard` when the two match (same plist domain), with a regression test in `SettingsStoreTests` (commit a76a1e1 after the history rewrite).

**Prevention**: No force-unwraps on Foundation initialisers that can fail. `scripts/build-app.sh --install --open` fails loudly when `pgrep` finds no process.

## 2026-09-29T19:23 - SwiftUI settings window collapsed to its title bar

**Problem**: System Events reported the settings window as 460 x 32. The screenshot showed only the title bar.

**Root Cause**: A `Form` with `.formStyle(.grouped)` is scroll-backed and has no ideal height, so `NSHostingController` sized the `NSWindow` to zero content height.

**Solution**: `.frame(width: 460, height: 740)` on the root view.

**Prevention**: After opening any hosted SwiftUI window, read its `size` through System Events. A height near 32 means empty.

## 2026-09-29T19:50 - App screenshots leaked the user's precise location and browser tabs

**Problem**: While preparing the repo for open source, a text grep of the whole history came back clean, but `docs/screenshots/*.png` showed "Current location 37.771, -122.405" and the titles of the user's open browser tabs.

**Root Cause**: Screenshots of a location-aware app, taken with a region wider than the app's own UI. Grep cannot see into images.

**Lesson**: Open-source readiness includes looking at every image in history, not only grepping text.

**Solution**: Retook both with manual San Francisco city-centre coordinates, cropped to the menu and window rectangles from System Events, and restored the user's settings. Before the first push, replaced the images inside the commit that introduced them with a scripted `GIT_SEQUENCE_EDITOR=sed … rebase -i`. Backups: bundle in `archive/`, local-only branch `backup/pre-open-source`.

**Prevention**: The `/osr` skill (audit step 3). Capture UI screenshots with `screencapture -R` set to the element's own bounds.

## 2026-09-29T19:52 - A failed rebase plus `;` amended the wrong commit

**Problem**: `git rebase -i …` refused to start ("You have unstaged changes": a freshly written `.beads/issues.jsonl`). The next commands were joined with `;`, so `cp …; git add …; git commit --amend` still ran and amended the new screenshots into HEAD, the session-summary commit.

**Solution**: `git reset --soft` to the previous tip, unstaged the images, committed `.beads`, and re-ran the rebase with every step chained by `&&` plus a `git log -1 --format=%s | grep -q …` guard that the stop is on the intended commit.

**Prevention**: History surgery gets `&&` only, a clean tree first (commit beads before rebasing), and an assertion about which commit you are on before `--amend`.

## 2026-09-29T20:10 - Site text: horizon line through the copy, descender collisions, a hidden button that showed

**Problem**: First renders of nightglow.io had three layout bugs. The horizon rule (fixed at 72% of the hero) struck through the lede. Gloock's deep `g` descenders overlapped the lede. The "Back to now" button showed while nothing was being previewed. A fourth, the ghost button's text colour lagging behind the theme, appeared in golden-hour renders.

**Root Cause**: The horizon was a fixed fraction, while text height varies with viewport and fonts. `.button { display: inline-flex }` overrides the UA `[hidden] { display: none }`. A button with its own `transition: color` inherits an already-transitioning colour from `.hero`, so the transitions compound.

**Solution**: Measure the eyebrow's position after `document.fonts.ready` and set `--horizon` from it. Add `[hidden] { display: none !important; }`. Drop colour from the button transition. Increase the lede margin to clear the descenders.

**Prevention**: `scripts/verify-site.mjs` asserts `isVisible` (not the `.hidden` property, which is why the first check passed while the bug was visible) and captures every phase. Look at the screenshots, not only the PASS lines.

## 2026-09-29T21:30 - Fresh domain: two layers of negative DNS caching on the developer's Mac

**Problem**: Right after nightglow.io went live (Pages built, certificate approved, 1.1.1.1 and 8.8.8.8 resolving), `curl` on the Mac kept failing with exit 6. The user asked to check the site and offered a GCP VM if hosting was broken.

**Root Cause**: A `dig` made minutes after registration, before the .io zone delegated the domain, cached NXDOMAIN at two layers: the VPN's resolver `10.2.0.1` (SOA negative TTL 3600, seen counting down in `dig nightglow.io`) and macOS mDNSResponder, which `curl` and browsers use. The first expired at 03:29:27Z exactly as predicted. The second held until the user ran `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`.

**Lesson**: Verify a new domain from outside the local cache: pin requests with `curl --resolve host:443:IP` and Chrome with `--host-resolver-rules`, and confirm from a second host (corsair) before touching the hosting. `dig` working while `curl` fails means the macOS system cache, not the site.

**Solution**: `scripts/check-live.sh` pins every probe to a Pages IP from public DNS and prints the flush command when only the local machine fails. No VM was needed.

**Prevention**: Don't look a domain up before its NS delegation is visible at the TLD (`dig @a0.nic.io NS <domain>`). If you do, expect up to an hour of local NXDOMAIN.

## Meta-Lessons

- Verify what the user will actually run (the installed bundle, the production URL from outside), not the most convenient stand-in.
- An assertion on a property (`.hidden`) can pass while the pixels disagree. Assert on rendered state (`isVisible`, window size) and look at a screenshot.
