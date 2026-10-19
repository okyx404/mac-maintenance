#!/usr/bin/env zsh
# ------------------------------------------------------------
# mac-maintenance.sh - The Ultimate Free Mac Cleaner & Orphan Hunter
# Optimized & De-duplicated Version
# ------------------------------------------------------------

set -e
setopt NO_NOMATCH
setopt NULL_GLOB

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
RESET=$'\033[0m'

VERSION="2.1"
CURRENT_USER="$(id -un)"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_DIR="$HOME/Desktop/Mac-Cleanup-Logs"
LOG_FILE="$LOG_DIR/mac-maintenance-$TIMESTAMP.log"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

[[ "$(uname)" == "Darwin" ]] || { print -P "${RED}macOS only, chief.${RESET}"; exit 1; }

clear
print -P "${CYAN}============================================================${RESET}"
print -P "${CYAN}         MACOS STREAMLINED MAINTENANCE & ORPHAN CLEANER     ${RESET}"
print -P "${CYAN}============================================================${RESET}"
print "Hey $CURRENT_USER. Let's sweep up the digital dust."
print "Log: $LOG_FILE\n"

# Sudo upfront for system tasks
print -P "${YELLOW}Enter your password for system-level cleanups and RAM purging:${RESET}"
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

get_free_mb() { df -m / | awk 'NR==2 {print $4}'; }
START_FREE=$(get_free_mb)

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

INSTALLED_APPS="$WORKDIR/installed_apps.txt"
INSTALLED_IDS="$WORKDIR/installed_ids.txt"
CANDIDATES="$WORKDIR/candidates.txt"
DELETE_LIST="$WORKDIR/delete_list.txt"

# ------------------------------------------------------------
# 1. ORPHAN APP SCAN (Must run BEFORE nuking caches)
# ------------------------------------------------------------
print -P "${CYAN}[1/5] Scanning installed apps & bundle IDs...${RESET}"
APP_LOCATIONS=("/Applications" "$HOME/Applications" "/System/Applications" "/System/Library/CoreServices")

for loc in "${APP_LOCATIONS[@]}"; do
    [[ -d "$loc" ]] && find "$loc" -type d -name "*.app" -prune -print 2>/dev/null
done | sort -u > "$INSTALLED_APPS"

while IFS= read -r app; do
    [[ -z "$app" ]] && continue
    plist="$app/Contents/Info.plist"
    [[ -f "$plist" ]] || continue
    bid=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$plist" 2>/dev/null)
    [[ -n "$bid" ]] && print -r -- "$bid" >> "$INSTALLED_IDS"
done < "$INSTALLED_APPS"
sort -u "$INSTALLED_IDS" -o "$INSTALLED_IDS"

is_installed() { grep -Fxq "$1" "$INSTALLED_IDS"; }
is_protected() { [[ "$1" == com.apple.* || "$1" == apple.* ]]; }

SEARCH_PATHS=(
    "$HOME/Library/Application Support" "$HOME/Library/Caches"
    "$HOME/Library/Containers" "$HOME/Library/Group Containers"
    "$HOME/Library/Preferences" "$HOME/Library/Saved Application State"
    "$HOME/Library/WebKit" "$HOME/Library/Logs" "$HOME/Library/HTTPStorages"
    "$HOME/Library/Cookies" "$HOME/Library/LaunchAgents"
)

print -P "${CYAN}[2/5] Hunting for orphaned application leftovers...${RESET}"
while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    is_protected "$id" && continue
    is_installed "$id" && continue

    for base in "${SEARCH_PATHS[@]}"; do
        [[ -d "$base" ]] || continue
        find "$base" -maxdepth 3 \( -name "$id" -o -name "$id.plist" -o -name "$id.savedState" -o -name "$id.lockfile" \) -print 2>/dev/null >> "$CANDIDATES"
    done
done < "$INSTALLED_IDS"

# Scan direct preference/cache filenames
for base in "$HOME/Library/Preferences" "$HOME/Library/Caches" "$HOME/Library/Saved Application State" "$HOME/Library/HTTPStorages" "$HOME/Library/WebKit"; do
    [[ -d "$base" ]] || continue
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        name="$(basename "$item")"
        id="${name%.plist}"
        id="${id%.savedState}"
        [[ "$id" == *.* ]] && ! is_installed "$id" && ! is_protected "$id" && print -r -- "$item" >> "$CANDIDATES"
    done < <(find "$base" -maxdepth 2 -mindepth 1 -print 2>/dev/null)
done

sort -u "$CANDIDATES" -o "$CANDIDATES"

# Validate safe paths
while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    case "$item" in
        "$HOME/Library/"*) print -r -- "$item" >> "$DELETE_LIST" ;;
    esac
done < "$CANDIDATES"
sort -u "$DELETE_LIST" -o "$DELETE_LIST"

COUNT=$(wc -l < "$DELETE_LIST" | tr -d ' ')
ORPHAN_DELETED=0

if [[ "$COUNT" -gt 0 ]]; then
    print -P "${YELLOW}Found $COUNT orphaned leftovers:${RESET}"
    print "------------------------------------------------------------"
    cat "$DELETE_LIST"
    print "------------------------------------------------------------"
    print -P "${YELLOW}Type DELETE to remove them (anything else skips):${RESET}"
    read "CONFIRM?Confirm: "
    if [[ "$CONFIRM" == "DELETE" ]]; then
        while IFS= read -r item; do
            [[ -z "$item" ]] && continue
            if [[ -e "$item" || -L "$item" ]]; then
                print "Removing: $item" | tee -a "$LOG_FILE"
                rm -rf -- "$item" 2>>"$LOG_FILE" && (( ORPHAN_DELETED++ ))
            fi
        done < "$DELETE_LIST"
    fi
else
    print -P "${GREEN}No orphaned app files found. Nice and tidy.${RESET}"
fi

# ------------------------------------------------------------
# 2. SYSTEM MAINTENANCE & CACHE NUKING
# ------------------------------------------------------------
print -P "${CYAN}[3/5] Cleaning system caches, logs, and developer junk...${RESET}"
rm -rf ~/Library/Caches/* ~/Library/Logs/* ~/Library/Application\ Support/CrashReporter/* 2>/dev/null || true
sudo rm -rf /Library/Caches/* /var/log/* 2>/dev/null || true

if [ -d "$HOME/Library/Developer/Xcode" ]; then
  rm -rf ~/Library/Developer/Xcode/DerivedData/* ~/Library/Developer/Xcode/Archives/* ~/Library/Developer/Xcode/iOS\ DeviceSupport/* 2>/dev/null || true
fi

if command -v brew >/dev/null 2>&1; then
  brew cleanup -s >/dev/null 2>&1 || true
  rm -rf "$(brew --cache)" 2>/dev/null || true
fi

if command -v npm >/dev/null 2>&1; then
  npm cache clean --force >/dev/null 2>&1 || true
fi

print -P "${CYAN}[4/5] Flushing network caches and reclaiming RAM...${RESET}"
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
qlmanage -r cache >/dev/null 2>&1 || true
sudo purge >/dev/null 2>&1 || true

print -P "${CYAN}[5/5] Emptying trash and temp files...${RESET}"
rm -rf ~/.Trash/* 2>/dev/null || true
sudo rm -rf /Volumes/*/.Trashes/* /private/var/folders/* 2>/dev/null || true

# Tidying empty dirs
for dir in "$HOME/Library/Application Support" "$HOME/Library/Caches" "$HOME/Library/Containers" "$HOME/Library/Group Containers" "$HOME/Library/Saved Application State"; do
    [[ -d "$dir" ]] && find "$dir" -type d -empty -delete 2>/dev/null
done

# ------------------------------------------------------------
# RESULTS
# ------------------------------------------------------------
END_FREE=$(get_free_mb)
DIFF=$((END_FREE - START_FREE))

print "\n============================================================"
print -P "${GREEN}                  MAINTENANCE COMPLETE                      ${RESET}"
print "============================================================"
[[ $DIFF -gt 0 ]] && print "Storage Reclaimed: ~$DIFF MB (~$(echo "scale=2; $DIFF / 1024" | bc 2>/dev/null || echo "0") GB)"
print "Orphan files removed: $ORPHAN_DELETED"
print "Log saved to: $LOG_FILE\n"