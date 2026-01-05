#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Rename Files to Modification Date

Renames files in a directory to their modification timestamp:
  YYYY-MM-DD_HH-MM-SS.ext
If the target name already exists, an increment is appended:
  YYYY-MM-DD_HH-MM-SS_1.ext, YYYY-MM-DD_HH-MM-SS_2.ext, ...

Usage:
  ./rename_files_to_mtime.sh [--dry-run] [--yes] <directory>

Options:
  --dry-run   Print what would happen without renaming files
  --yes       Do not prompt for confirmation
  -h, --help  Show this help

Notes:
- Only files directly inside <directory> are processed (non-recursive).
- The extension is preserved. If a file has no extension, it will be renamed without one.
EOF
}

err() { printf 'Error: %s\n' "$*" >&2; }
info() { printf '%s\n' "$*"; }

# Cross-platform: get mtime epoch seconds
mtime_epoch() {
  local file="$1"

  # macOS / BSD
  if stat -f %m "$file" >/dev/null 2>&1; then
    stat -f %m "$file"
    return 0
  fi

  # Linux / GNU
  if stat -c %Y "$file" >/dev/null 2>&1; then
    stat -c %Y "$file"
    return 0
  fi

  return 1
}

# Cross-platform: format epoch to timestamp string
epoch_to_stamp() {
  local epoch="$1"

  # macOS / BSD date
  if date -r 0 "+%Y-%m-%d_%H-%M-%S" >/dev/null 2>&1; then
    date -r "$epoch" "+%Y-%m-%d_%H-%M-%S"
    return 0
  fi

  # Linux / GNU date
  date -d "@$epoch" "+%Y-%m-%d_%H-%M-%S"
}

unique_destination_path() {
  local dir="$1"
  local stamp="$2"
  local ext="$3"

  local candidate count
  if [[ -n "$ext" ]]; then
    candidate="$dir/${stamp}.${ext}"
  else
    candidate="$dir/${stamp}"
  fi

  if [[ ! -e "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  count=1
  while :; do
    if [[ -n "$ext" ]]; then
      candidate="$dir/${stamp}_${count}.${ext}"
    else
      candidate="$dir/${stamp}_${count}"
    fi
    if [[ ! -e "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
    count=$((count + 1))
  done
}

DRY_RUN=false
ASSUME_YES=false
DIR=""

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --yes)
      ASSUME_YES=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      err "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      DIR="$1"
      shift
      ;;
  esac
done

if [[ -z "$DIR" ]]; then
  err "Please provide a directory."
  usage
  exit 1
fi

if [[ ! -d "$DIR" ]]; then
  err "Directory does not exist or is not a directory: $DIR"
  exit 1
fi

# Count regular files directly in the directory (non-recursive)
file_count=0
while IFS= read -r -d '' _; do
  file_count=$((file_count + 1))
done < <(find "$DIR" -maxdepth 1 -type f -print0)

info "Directory: $DIR"
info "Files to process (non-recursive): $file_count"

if [[ "$file_count" -eq 0 ]]; then
  info "Nothing to do."
  exit 0
fi

if [[ "$ASSUME_YES" == "false" && "$DRY_RUN" == "false" ]]; then
  printf "Continue? (y/N) "
  read -r confirmation
  if [[ "${confirmation:-}" != "y" && "${confirmation:-}" != "Y" ]]; then
    info "Aborted."
    exit 0
  fi
fi

# Use a stable list to avoid surprises if names change during iteration
file_list="$(mktemp)"
cleanup() { rm -f "$file_list"; }
trap cleanup EXIT

find "$DIR" -maxdepth 1 -type f -print0 > "$file_list"

renamed=0

while IFS= read -r -d '' file; do
  base="$(basename "$file")"

  # Determine extension (preserve if present)
  ext=""
  if [[ "$base" == *.* && "$base" != .* ]]; then
    ext="${base##*.}"
  fi

  if ! epoch="$(mtime_epoch "$file")"; then
    err "Could not read modification time: $file"
    continue
  fi

  stamp="$(epoch_to_stamp "$epoch")"
  if [[ -z "$stamp" ]]; then
    err "Could not format modification time: $file"
    continue
  fi

  dest="$(unique_destination_path "$DIR" "$stamp" "$ext")"

  # If the destination equals current path, skip
  if [[ "$file" == "$dest" ]]; then
    continue
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    info "Would rename: $file -> $dest"
    continue
  fi

  mv -- "$file" "$dest"
  renamed=$((renamed + 1))
  info "Renamed: $file -> $dest"
done < "$file_list"

info ""
if [[ "$DRY_RUN" == "true" ]]; then
  info "Dry run completed. No files were renamed."
else
  info "Done. Renamed $renamed file(s)."
fi
