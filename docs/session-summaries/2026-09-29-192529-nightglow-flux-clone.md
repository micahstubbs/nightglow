# Nightglow: f.lux clone for macOS

## Summary
Scaffolded with the new np script (test of scripts bd-1ah) and built a Swift menu bar app that warms and dims every display from the sun's elevation at the user's location.

## Completed Work
- 6886d35 failing core tests; 41825e6 NightglowCore (NOAA solar, Kelvin->RGB, schedule, gamma ramps, zone.tab location)
- 9417e88 app: GammaEngine, Controller, StatusMenu, SettingsView, LocationProvider, CLI (--status/--gamma/--probe), scripts/build-app.sh, scripts/verify-live.sh
- Fixed: bundled-app launch crash (UserDefaults suite == bundle id returns nil, regression test SettingsStoreTests); settings window collapsing to title bar
- Verified: 23 XCTest pass; --probe PASS (0 error, restored); verify-live.sh 4/4 PASS against ~/Applications/Nightglow.app; menu and settings screenshots in docs/screenshots

## Pending/Blocked
- bd-2oj needs-human: no git remote, repo not pushed
- bd-1s4 optional DDC/CI hardware brightness (MonitorControl approach)

## Next Session Context
Nightglow.app is installed in ~/Applications and was left running. Rebuild with yarn install-app, then scripts/verify-live.sh. Launch at login is off until toggled in Settings.
