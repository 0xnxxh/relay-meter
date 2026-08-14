# Relay Meter v1.0.12

## Highlights

- Restores the last successful dashboard immediately at launch while refreshing current data in the background.
- Keeps the cached dashboard scoped to matching adapters, credentials, and time range without storing management keys.

## Performance

- Coalesces overlapping refreshes and cancels obsolete requests after configuration or time-range changes.
- Removes unused API-key ranking requests from all supported adapters, reducing startup network work.
