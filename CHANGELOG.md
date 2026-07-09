# Changelog

## v0.1.3beta - 2026-07-10

- Reworked the frontend into a clearer product structure: compact widget, large float, and full Dashboard now have distinct responsibilities.
- Added Dashboard navigation, overview layout, settings panel, reusable surface cards, and home summary view model.
- Polished the compact widget, large float, title bar, entry panels, problem book, contests, teammates, heatmap, refresh logs, and settings surfaces.
- Fixed compact widget overflow at the configured Windows floating-window height.
- Improved Nowcoder fallback behavior when OJ Hunt is unavailable, including nickname-to-user-ID resolution and clearer failure messages.
- Added a Ninja-based Windows release build script for machines where Visual Studio/MSBuild HostX86 hangs or fails.
- Added focused tests for the home summary view model, compact widget layout, and Nowcoder fallback parsing.
- Rewrote the README with current product usage, privacy notes, build instructions, and release guidance.

## v0.1.3 - 2026-06-23

- Added optional OJ Float Sync Webhook v1.
- Stored the sync token in secure storage instead of the normal config JSON.
- Added field-level privacy switches for daily stats, problem rows, notes, and solution analysis.
- Kept OJ usernames, account-level deltas, passwords, cookies, and tokens out of the sync payload.
- Sent empty arrays for disabled sync scopes so the server can clear public projections.
- Required HTTPS sync endpoints, with localhost HTTP allowed for local development.
- Added manual "Save & Sync Now" and optional auto-sync after refresh.
- Updated the website receiver/public projection contract for stable v0.1.3 use.
