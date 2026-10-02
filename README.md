# mac-maintenance
A bash script for cleaning junk on your Mac. Yes, there's a paid app for this. 

# mac-maintenance.sh

Because I refuse to pay $40 a year for a fancy GUI app that literally just wraps basic shell commands in Electron.

Seriously, why does clearing system caches need a recurring subscription? CleanMyMac, MacPaw, whatever else—they're all charging you rent on software that executes `rm -rf ~/Library/Caches/*` and `sudo purge`. You don't need a shiny dashboard with particle animations to delete temporary junk.

This is a zero-bs shell script written specifically for Apple Silicon Macs.

## What this actually does

- User & System Caches: Deletes system logs, crash reports (where Apple records every time Music.app crashes), and general user cache bloat.
- Developer Bloat: Nukes Xcode's DerivedData (which hoards 50GB for no reason), iOS device support junk, Homebrew cache bottles, and npm cache.
- Memory & DNS: Flushes DNS cache when local network domains act up, rebuilds QuickLook, and runs `purge` to release held RAM.
- Trash & System Temp: Empties trash across volumes and clears system temp directories.
- Periodic Tasks: Runs native macOS maintenance tasks (daily, weekly, monthly).

## How to use it

1. Save the script as `mac-maintenance.sh`.
2. Make it executable:
   ```bash
   chmod +x mac-maintenance.sh
