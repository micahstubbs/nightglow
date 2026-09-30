# Open-sourcing Nightglow and launching nightglow.io (bd-w3r)

## Summary
Audited and published the repo (Apache 2.0), released v0.1.0, built a sun-aware landing page, pointed the Spaceship domain at GitHub Pages, verified production, and emailed the user.

## Completed Work
- History scrub before the first push: screenshots with precise location and browser tabs replaced inside the original commit (backup: local branch backup/pre-open-source plus a bundle in archive/)
- Apache-2.0 LICENSE and NOTICE (GitHub detects Apache-2.0); README badges
- https://github.com/micahstubbs/nightglow public; release v0.1.0 (universal zip + sha256)
- site/: TypeScript NOAA solar port, phase palette with contrast tests, multiply tint overlay, SF fallback, day scrubber, GitHub corner
- DNS: scripts/configure-dns.sh (4 A, 4 AAAA, www CNAME); Pages cert approved, HTTPS enforced
- Verification: 10 site unit tests; scripts/verify-site.mjs 19/19 against production
- Email delivered: Resend 01a0f036-09d4-7019-9ecb-b405f11ca710

## Pending/Blocked
- bd-185 needs-human: Apple Developer ID notarization decision
- bd-1s4 optional DDC hardware brightness

## Next Session Context
Redeploy with yarn site-deploy; verify with yarn site-verify (pass a URL for production). This Mac cached NXDOMAIN for nightglow.io from before delegation; that clears within an hour.
