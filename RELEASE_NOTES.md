# Relay Meter v1.0.15

## Highlights

- Adds a dedicated oh-my-cpa channel for traffic, tokens/cache, estimated spend, latency, recent activity, model rankings, trends, and usage heatmaps.
- Supports console URLs with a mount path such as `/omc`, as well as root-mounted consoles. Enter the CPA management key used to sign in to the console.
- Keeps login sessions in memory, isolated by console URL and credential, and signs in again when a session expires.
- Preserves the complete returned trend series in the aggregate dashboard.

## Notes

- Today, 7d, and 30d follow the Mac's local calendar; All uses oh-my-cpa's permanent usage window.
- Heatmaps use the Mac's timezone and leave days before the first stored usage unknown.
- Partially priced or unpriced windows show `--` for spend. Model rankings omit the folded remainder and retain unknown per-model failure counts.
