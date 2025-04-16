#!/bin/bash

# This is a basic backup bash script with some cool functions.
# It's not a masterpiece, of course, but I like it. It helps me a lot.
# If it can also help you, I'm glad to share it.
# Any problems or suggestions, please report me: <yurifs@atomicmail.io>
# Peace. 

# =========================
# Paths and Configurations
# =========================

BKP_BASE="$HOME/.bkp"
BKP_DIR="$BKP_BASE/list"
BKP_LOG="$BKP_BASE/backup.log"
BKP_LIST="$BKP_BASE/files.lst"
BKP_CURRENT="$(date '+%d-%m-%y_%H-%M').bkp.tar.zst"
INCREMENTAL_DIR="$BKP_BASE/tmp"
GPG_RECIPIENT="myemail@example.com"  # Your email/GPG ID here

# =========================
# Logging Functions
# =========================

log_msg() {
  local level="${1:-INFO}"
  shift
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
  echo "$msg" | tee -a "$BKP_LOG"
}

log_info()  { log_msg "INFO" "$@"; }
log_warn()  { log_msg "WARN" "$@"; }
log_error() { log_msg "ERROR" "$@"; }

# =========================
# Backup Function
# =========================

make_backup() {
  if [[ ! -f "$BKP_LIST" ]]; then
    log_error "Backup list '$BKP_LIST' not found. Use -e to create or -l to load."
    exit 1
  fi

  mkdir -p "$INCREMENTAL_DIR"
  rm -rf "$INCREMENTAL_DIR"/*

  local IFS=$'\n'
  local files=()
  readarray -t files < "$BKP_LIST"

  log_info "Starting incremental backup with rsync..."

  for i in "${files[@]}"; do
    if [[ -e "$i" ]]; then
      log_info "Syncing: $i"
      rsync -a --relative "$i" "$INCREMENTAL_DIR/"
    else
      log_warn "File or directory not found: $i"
    fi
  done

  log_info "Creating archive: $BKP_CURRENT"
  tar --use-compress-program=zstd -cf "$BKP_CURRENT" -C "$INCREMENTAL_DIR" . >> "$BKP_LOG" 2>&1

  local encrypted="$BKP_CURRENT.gpg"

  log_info "Encrypting archive to: $encrypted"
  gpg --yes --output "$encrypted" --encrypt --recipient "$GPG_RECIPIENT" "$BKP_CURRENT"

  local hash
  hash=$(sha256sum "$encrypted" | cut -d' ' -f1)
  log_info "Encrypted archive created successfully."
  log_info "SHA256: $hash"

  rm -f "$BKP_CURRENT"
  rm -rf "$INCREMENTAL_DIR"

  mv "$encrypted" "$BKP_DIR"
  log_info "Backup process completed."
}

# =========================
# Restore Function
# =========================

restore_backup() {
  echo -e "\nAvailable backups:"
  ls "$BKP_DIR"/*.gpg

  echo -e "\nEnter backup filename to restore (full name):"
  read -r file

  file="$(basename "$file")"   # remove caminho caso usuário coloque /home/etc
  file="${file##*( )}"         # remove espaços à esquerda
  file="${file%%*( )}"         # remove espaços à direita

  filepath="$BKP_DIR/$file"

  if [[ ! -f "$filepath" ]]; then
   log_error "Backup file not found: $filepath"
   exit 1
  fi

  if [[ -n "$RESTORE_DEST" ]]; then
    restore_dir="$RESTORE_DEST"
  else
    echo -e "\nEnter destination directory (leave empty for default):"
    read -r restore_dir
    [[ -z "$restore_dir" ]] && restore_dir="$HOME/.bkp/restore_$(date '+%H%M%S')"
  fi

  mkdir -p "$restore_dir"

  log_info "Decrypting backup..."
  gpg --output "$restore_dir/decrypted.tar.zst" --decrypt "$BKP_DIR/$file"

  log_info "Extracting backup to: $restore_dir"
  tar --use-compress-program=zstd -xf "$restore_dir/decrypted.tar.zst" -C "$restore_dir"
  rm "$restore_dir/decrypted.tar.zst"

  log_info "Restore completed at: $restore_dir"
}

# =========================
# Set List Function
# =========================

set_list() {
  >"$BKP_LIST"
  echo -e "\nInform file/directory to backup (type 'quit' to end):"

  while true; do
    read -r line
    [[ "$line" == "quit" ]] && break
    echo "$line" >> "$BKP_LIST"
    echo -e "Next file/directory:"
  done

  log_info "Backup list created/updated: $BKP_LIST"
}

# =========================
# Usage Function
# =========================

usage() {
  cat <<EOF

Usage: $0 [options]

Options:
  -b             Create new backup
  -l <list>      Set custom backup list
  -c             Clear backup logs
  -e             Create/edit files/directories list for backup
  -r             Restore encrypted backup
  -d <dir>       Set destination directory for restore
  -h             Show this help and exit

EOF
  exit
}

# =========================
# Initial Setup
# =========================

if [ ! "$1" ]; then
  usage && exit 1
fi

if [ ! -d "$BKP_DIR" ]; then
  mkdir -p "$BKP_DIR"
  >"$BKP_LOG"
  >"$BKP_LIST"
  log_info "Backup directory and initial files created."
fi

# =========================
# Option Parsing & Execution
# =========================

do_backup=false
do_edit=false
do_clear_log=false
do_help=false
do_restore=false
RESTORE_DEST=""

OPTSTRING="bcehrd:l:"

while getopts "$OPTSTRING" opt; do
  case $opt in
    b) do_backup=true ;;
    c) do_clear_log=true ;;
    e) do_edit=true ;;
    r) do_restore=true ;;
    d) RESTORE_DEST="$OPTARG" ;;
    l) BKP_LIST="$OPTARG" ; log_info "Using custom backup list: $BKP_LIST" ;;
    h) do_help=true ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
  esac
done

$do_help      && usage
$do_clear_log && >"$BKP_LOG" && echo "Logs cleared." && exit 0
$do_edit      && set_list
$do_restore   && restore_backup
$do_backup    && make_backup

