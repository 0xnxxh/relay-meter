# Relay Meter v1.0.6

## Highlights

- Adds a 13-week activity heatmap with calendar-aligned week columns, weekday rows, and month labels.
- Adds a full activity window with Calendar Year / Rolling Year, source, and Requests / Tokens controls.
- Uses native daily aggregate endpoints for CLIProxyAPI-Pro and sub2api, plus new-api data export aggregates.

## Fixes

- Distinguishes zero usage, partial multi-adapter data, unavailable data, and disabled new-api data export.
- Matches the activity source selector and detail window chrome to the RelayTheme pixel interface.
- Honors new-api's 100-row log page limit for non-heatmap cards.
