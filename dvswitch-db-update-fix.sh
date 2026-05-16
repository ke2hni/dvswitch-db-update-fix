#!/usr/bin/env bash
set -u

APP_NAME="DVSwitch database update source fix"
PATCH_VERSION="v0.2-test"
TARGET="/opt/MMDVM_Bridge/dvswitch.sh"
STAMP="$(date +%Y%m%d-%H%M%S)"
ORIGINAL_BACKUP="/opt/MMDVM_Bridge/dvswitch.sh.dvs-dbfix-original"
RUN_BACKUP="/opt/MMDVM_Bridge/dvswitch.sh.dvs-dbfix-backup-${STAMP}"
LOG_FILE="/root/dvswitch-dbfix-${STAMP}.log"

log(){ echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
die(){ log "ERROR: $*"; exit 1; }
need_root(){ [ "$(id -u)" -eq 0 ] || die "Run with sudo/root."; }

get_script_version(){
  awk -F'"' '/^SCRIPT_VERSION=/{print $2; exit}' "$TARGET" 2>/dev/null
}

is_supported_version(){
  case "$1" in
    1.6.2|1.6.3) return 0 ;;
    *) return 1 ;;
  esac
}

has_update_source_issue(){
  grep -Fq 'curl --fail -o "$MMDVM_DIR/$1" -s "http://www.pistar.uk/downloads/$2"' "$TARGET" && return 0
  grep -Fq 'downloadAndValidate "YSFHosts.txt" "YSF_Hosts.txt" "dvswitch.org"' "$TARGET" && return 0
  grep -Fq 'downloadAndValidate "TGList_TGIF.txt" "TGList_TGIF.txt" "TGIF"' "$TARGET" && return 0
  return 1
}

show_status(){
  echo "$APP_NAME $PATCH_VERSION"
  echo "Target: $TARGET"
  if [ -f "$TARGET" ]; then
    ver="$(get_script_version)"
    echo "Detected SCRIPT_VERSION: ${ver:-unknown}"
    if is_supported_version "${ver:-}"; then echo "Supported version: yes"; else echo "Supported version: no"; fi
    if has_update_source_issue; then echo "Update-source issue detected: yes"; else echo "Update-source issue detected: no"; fi
    echo
    echo "Relevant lines:"
    grep -n 'pistar.uk/downloads\|YSFHosts.txt\|YSF_Hosts.txt\|TGList_TGIF.txt\|downloadTGIFList\|api.tgif.network' "$TARGET" 2>/dev/null || true
  else
    echo "Target file missing"
  fi
  echo
  if [ -f "$ORIGINAL_BACKUP" ]; then echo "Protected original backup: $ORIGINAL_BACKUP"; else echo "Protected original backup: not found"; fi
  latest="$(ls -1 /opt/MMDVM_Bridge/dvswitch.sh.dvs-dbfix-backup-* 2>/dev/null | sort | tail -1 || true)"
  if [ -n "$latest" ]; then echo "Latest per-run backup: $latest"; else echo "Latest per-run backup: not found"; fi
}

create_backups(){
  if [ ! -f "$ORIGINAL_BACKUP" ]; then
    cp -a "$TARGET" "$ORIGINAL_BACKUP" || die "Could not create protected original backup"
    log "Created protected original backup: $ORIGINAL_BACKUP"
  else
    log "Protected original backup already exists and will NOT be overwritten: $ORIGINAL_BACKUP"
  fi
  cp -a "$TARGET" "$RUN_BACKUP" || die "Could not create per-run backup"
  log "Created per-run backup: $RUN_BACKUP"
}

restore_original(){
  need_root
  [ -f "$ORIGINAL_BACKUP" ] || die "Protected original backup not found: $ORIGINAL_BACKUP"
  cp -a "$ORIGINAL_BACKUP" "$TARGET" || die "Could not restore protected original backup"
  bash -n "$TARGET" || die "Restored file failed bash syntax check"
  log "Restored protected original backup to: $TARGET"
  log "Log file: $LOG_FILE"
}

apply_patch(){
  need_root
  [ -f "$TARGET" ] || die "Missing target file: $TARGET"

  ver="$(get_script_version)"
  [ -n "$ver" ] || die "Could not detect SCRIPT_VERSION in $TARGET"
  if ! is_supported_version "$ver"; then
    die "Unsupported SCRIPT_VERSION=$ver. This patch is limited to 1.6.2 and 1.6.3 until newer versions are verified."
  fi

  if ! has_update_source_issue; then
    log "No known update-source issue patterns found. Nothing to patch."
    log "Detected SCRIPT_VERSION=$ver"
    log "Log file: $LOG_FILE"
    return 0
  fi

  create_backups

  python3 - "$TARGET" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
original = text
changes = []

def replace_once(old, new, label):
    global text
    if old in text:
        text = text.replace(old, new, 1)
        changes.append(label)
    elif new in text:
        changes.append(label + " already applied")

# Fix the generic Pi-Star download helper from stale HTTP/no-redirect behavior to HTTPS + redirects.
replace_once(
    '${DEBUG} curl --fail -o "$MMDVM_DIR/$1" -s "http://www.pistar.uk/downloads/$2"',
    '${DEBUG} curl -L --fail -o "$MMDVM_DIR/$1" -s "https://www.pistar.uk/downloads/$2"',
    'Pi-Star download helper -> HTTPS with redirects'
)

# Fix the direct DMR host download line too, but keep output path unchanged.
replace_once(
    '${DEBUG} curl -s -N "http://www.pistar.uk/downloads/DMR_Hosts.txt" > "${MMDVM_DIR}/DMR_Hosts.txt"',
    '${DEBUG} curl -L -s -N "https://www.pistar.uk/downloads/DMR_Hosts.txt" > "${MMDVM_DIR}/DMR_Hosts.txt"',
    'DMR_Hosts direct download -> HTTPS with redirects'
)

# Correct the YSF output filename. Old code downloaded YSF_Hosts.txt but saved it as YSFHosts.txt,
# which left /var/lib/mmdvm/YSF_Hosts.txt missing for normal users/tools.
replace_once(
    'downloadAndValidate "YSFHosts.txt" "YSF_Hosts.txt" "dvswitch.org"',
    'downloadAndValidate "YSF_Hosts.txt" "YSF_Hosts.txt" "YSF"',
    'YSF host list filename/validation fixed'
)

# Ensure ParseTGFile also uses HTTPS + redirects for BM list parsing used by mobile data generation.
replace_once(
    'curl --fail -o "$NODE_DIR/$1" -s http://www.pistar.uk/downloads/$1',
    'curl -L --fail -o "$NODE_DIR/$1" -s https://www.pistar.uk/downloads/$1',
    'ParseTGFile download -> HTTPS with redirects'
)

# Add a dedicated TGIF CSV downloader for the database update path if missing.
helper = r'''
function downloadTGIFList() {
    local dest="$MMDVM_DIR/TGList_TGIF.txt"
    local tmp="${dest}.tmp"
    ${DEBUG} curl -L --fail -s "https://api.tgif.network/dmr/talkgroups/csv" | awk -F, 'BEGIN{OFS=";"} /^[0-9]+,/ {print $1,$2}' > "$tmp"
    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        echo "Error, TGList_TGIF.txt file has no contents"
        _ERRORCODE=$ERROR_INVALID_FILE
        return
    fi
    if ! grep -q '^[0-9][0-9]*;' "$tmp"; then
        rm -f "$tmp"
        echo "Error, TGList_TGIF.txt file does not seem to be valid"
        _ERRORCODE=$ERROR_INVALID_FILE
        return
    fi
    mv "$tmp" "$dest"
}
'''

if 'function downloadTGIFList()' not in text:
    marker = '#################################################################\n# Download all user databases\n#################################################################\nfunction downloadDatabases() {'
    if marker not in text:
        raise SystemExit('Could not find downloadDatabases marker to insert downloadTGIFList()')
    text = text.replace(marker, helper + '\n' + marker, 1)
    changes.append('added downloadTGIFList() using api.tgif.network CSV')
else:
    changes.append('downloadTGIFList() already present')

replace_once(
    'downloadAndValidate "TGList_TGIF.txt" "TGList_TGIF.txt" "TGIF"',
    'downloadTGIFList',
    'TGIF update source -> api.tgif.network CSV'
)

if text == original:
    print('No file changes were needed')
else:
    path.write_text(text)

for c in changes:
    print(c)
PY
  rc=$?
  [ "$rc" -eq 0 ] || { cp -a "$RUN_BACKUP" "$TARGET" 2>/dev/null || true; die "Patch failed; restored per-run backup"; }

  if bash -n "$TARGET"; then
    log "bash syntax check passed for $TARGET"
  else
    cp -a "$RUN_BACKUP" "$TARGET" 2>/dev/null || true
    die "bash syntax check failed; restored per-run backup"
  fi

  log "Patch complete for SCRIPT_VERSION=$ver."
  log "Now test with: sudo /opt/MMDVM_Bridge/dvswitch.sh update"
  log "Expected: no YSFHosts invalid/missing error and no TGList_TGIF missing error."
  log "Log file: $LOG_FILE"
}

case "${1:-menu}" in
  apply) apply_patch ;;
  restore-original|restore-factory) restore_original ;;
  status) show_status ;;
  *)
    echo "$APP_NAME $PATCH_VERSION"
    echo "1 = Apply database update source fixes"
    echo "2 = Restore protected original dvswitch.sh"
    echo "3 = Show status"
    echo "0 = Exit"
    printf "Choose an action [0/1/2/3]: "
    read -r choice
    case "$choice" in
      1) apply_patch ;;
      2) restore_original ;;
      3) show_status | tee -a "$LOG_FILE"; log "Log file: $LOG_FILE" ;;
      0) exit 0 ;;
      *) die "Invalid choice" ;;
    esac
  ;;
esac
