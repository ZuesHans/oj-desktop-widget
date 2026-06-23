# Changelog

## v0.1.3 - 2026-06-23

- Added optional OJ Float Sync Webhook v1.
- Stored the sync token in secure storage instead of the normal config JSON.
- Added field-level privacy switches for daily stats, problem rows, notes, and solution analysis.
- Kept OJ usernames, account-level deltas, passwords, cookies, and tokens out of the sync payload.
- Sent empty arrays for disabled sync scopes so the server can clear public projections.
- Required HTTPS sync endpoints, with localhost HTTP allowed for local development.
- Added manual "Save & Sync Now" and optional auto-sync after refresh.
- Updated the website receiver/public projection contract for stable v0.1.3 use.
