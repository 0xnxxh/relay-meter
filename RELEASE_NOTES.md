# Relay Meter v1.0.8

## Highlights

- Skips menu view rebuilds while the panel is hidden, so background refreshes only update the status item title.
- Speeds up heatmap drawing by sorting the value distribution once per pass and caching cell geometry.
- Fetches new-api monthly activity chunks concurrently instead of one round trip per month.

## Fixes

- Rotates the log file at 2 MB and reuses a single file handle instead of growing without bound.
- Reuses cached date formatters when building trend, activity, and range labels.

## Internal

- Runs the characterization tests as part of the release check.
- Builds from a globbed source list so new files cannot be missed.
- Extracts the pixel controls out of the settings window into their own file.
