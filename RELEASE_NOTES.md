# Relay Meter v1.0.9

## Highlights

- Adds a Launch at Login setting backed by macOS Login Items, with an explicit approval state when System Settings action is required.
- Shows actual or estimated spend inside the Token card without separate currency or range rows.
- Adds Spend as an optional menu bar title metric.

## Fixes

- Reads CLIProxyAPI-Pro estimated cost, sub2api actual cost, and new-api quota conversion without presenting partial aggregate spend as a total.
- Declares and pins Sparkle 2.9.3 for SwiftPM so a plain `swift build` succeeds.

## Internal

- Keeps SwiftPM in Swift 5 language mode, matching the existing release build path while using Swift 6 package tools.
