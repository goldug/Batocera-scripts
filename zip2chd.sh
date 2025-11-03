# zip2chd: extract local ZIPs → find .cue → create .chd in $PWD → cleanup
zip2chd() {
  CWD="$(pwd)"

  # Check that at least one ZIP file exists 
  shopt -s nullglob nocaseglob
  ZIPFILES=(*.zip)
  if [ ${#ZIPFILES[@]} -eq 0 ]; then
    echo "No ZIP files found in $CWD"
    return 1
  fi

  # Check that chdman exists 
  if command -v chdman >/dev/null 2>&1; then
    CHDMAN="chdman"
  elif [ -x /usr/bin/mame/chdman ]; then
    CHDMAN="/usr/bin/mame/chdman"
  else
    echo "chdman not found."
    return 1
  fi

  # Loop through ZIP files 
  for ZIP in "${ZIPFILES[@]}"; do
    echo "Processing: $ZIP"

    TMPDIR="$(mktemp -d /tmp/zip2chd.XXXXXX)" || { echo "mktemp failed"; return 1; }
    trap 'rm -rf "$TMPDIR"' EXIT INT TERM

    # Unpack 
    if command -v bsdtar >/dev/null 2>&1; then
      bsdtar -xf "$ZIP" -C "$TMPDIR" || { echo "Failed to extract $ZIP"; rm -rf "$TMPDIR"; continue; }
    elif command -v unzip >/dev/null 2>&1; then
      unzip -qo "$ZIP" -d "$TMPDIR" || { echo "Failed to extract $ZIP"; rm -rf "$TMPDIR"; continue; }
    else
      echo "Needs bsdtar or unzip to extract."
      rm -rf "$TMPDIR"
      return 1
    fi

    # Find .cue
    CUEFILE="$(find "$TMPDIR" -type f -iname '*.cue' | head -n 1)"
    if [ -z "$CUEFILE" ]; then
      echo "No .cue found in $ZIP"
      rm -rf "$TMPDIR"
      continue
    fi

    BASENAME="$(basename "${CUEFILE%.*}")"
    OUTPATH="$CWD/$BASENAME.chd"

    echo "Creating CHD → $OUTPATH"
    "$CHDMAN" createcd -i "$CUEFILE" -o "$OUTPATH" || {
      echo "chdman failed on $ZIP"
      rm -rf "$TMPDIR"
      continue
    }

    echo "Done: $OUTPATH"
    rm -rf "$TMPDIR"
  done

  echo "All done."
}
