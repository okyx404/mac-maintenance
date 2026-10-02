#!/usr/bin/env zsh
#
# mac-maintenance.sh - Free CleanMyMac alternative because I refuse to pay 
# $40/year for a subscription to bash commands.
# Tested on Apple Silicon (M-series).

set -e

# Ask for root upfront so we don't get interrupted halfway through
echo "🔐 Enter your password so we can clear out Apple's hoard of cache files:"
sudo -v

# Keep sudo alive while script runs so it doesn't time out
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

get_free_mb() {
  df -m / | awk 'NR==2 {print $4}'
}

START_FREE=$(get_free_mb)

echo "\n🧹 Starting the deep clean..."

# --- 1. USER & SYSTEM CACHES ---
# Clear diagnostic logs (aka Apple recording every single time Music.app crashes)
echo "➜ Nuking user caches and crash reports..."
rm -rf ~/Library/Caches/* 2>/dev/null || true
rm -rf ~/Library/Logs/* 2>/dev/null || true
rm -rf ~/Library/Application\ Support/CrashReporter/* 2>/dev/null || true

# System-level logs (requires sudo)
sudo rm -rf /Library/Caches/* 2>/dev/null || true
sudo rm -rf /var/log/* 2>/dev/null || true


# --- 2. DEV & PACKAGE MANAGER JUNK ---
# Xcode casually holding 60GB hostage for a single "Hello World" app
if [ -d "$HOME/Library/Developer/Xcode" ]; then
  echo "➜ Cleaning Xcode's absurd storage footprint..."
  rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null || true
  rm -rf ~/Library/Developer/Xcode/Archives/* 2>/dev/null || true
  rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/* 2>/dev/null || true
fi

# Homebrew (because brew cleanup never actually cleans up everything)
if command -v brew >/dev/null 2>&1; then
  echo "➜ Telling Homebrew to stop hoarding old downloaded bottles..."
  brew cleanup -s >/dev/null 2>&1 || true
  rm -rf "$(brew --cache)" 2>/dev/null || true
fi

# Node/npm (half of node_modules is probably duplicate left-pad packages anyway)
if command -v npm >/dev/null 2>&1; then
  echo "➜ Purging npm cache..."
  npm cache clean --force >/dev/null 2>&1 || true
fi


# --- 3. MEMORY & OS TWEAKS ---
# Flush DNS because macOS randomly decides local web domains don't exist anymore
echo "➜ Flushing DNS cache..."
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Rebuild QuickLook preview cache
qlmanage -r cache >/dev/null 2>&1 || true

# Force release inactive unified memory
# ("8GB is equivalent to 16GB on PC" - Tim Cook, probably)
echo "➜ Reclaiming unused RAM..."
sudo purge >/dev/null 2>&1 || true


# --- 4. TRASH & TEMP FILES ---
echo "➜ Emptying Trash (where your money went when upgrading storage tiers)..."
rm -rf ~/.Trash/* 2>/dev/null || true
sudo rm -rf /Volumes/*/.Trashes/* 2>/dev/null || true
sudo rm -rf /private/var/folders/* 2>/dev/null || true


# --- 5. ANCIENT UNIX MAINTENANCE ---
# Run Apple's maintenance scripts from 1998
# echo "➜ Executing macOS periodic cron tasks..."
# sudo periodic daily weekly monthly


# --- RESULTS ---
END_FREE=$(get_free_mb)
DIFF=$((END_FREE - START_FREE))

echo "\n✨ All done!"
if [ $DIFF -gt 0 ]; then
  GB=$(echo "scale=2; $DIFF / 1024" | bc 2>/dev/null || echo "0")
  echo "Reclaimed ~$DIFF MB (~$GB GB). You just saved yourself $200 in Apple SSD upgrade fees."
else
  echo "Didn't free up much. Either your Mac was already clean, or Apple hid the files in iCloud."
fi
