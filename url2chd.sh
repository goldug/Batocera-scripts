# url2chd: download ZIP → extract temp → find .cue → create .chd in $PWD → cleanup
url2chd() {
  if [ $# -lt 1 ]; then
    echo "Usage: url2chd <zip-url>"
    return 2
  fi

  URL="$1"
  CWD="$(pwd)"
  TMPDIR="$(mktemp -d /tmp/url2chd.XXXXXX)" || { echo "mktemp failed"; return 1; }

  cleanup() { rm -rf "$TMPDIR"; }
  trap cleanup EXIT INT TERM

  # Choose downloader
  if command -v wget >/dev/null 2>&1; then
    DL="wget -qO- \"$URL\""
  elif command -v curl >/dev/null 2>&1; then
    DL="curl -sL \"$URL\""
  else
    echo "Needs wget or curl."
    return 1
  fi

  # Unpack
  if command -v bsdtar >/dev/null 2>&1; then
    EXTRACT="bsdtar -xvf- -C \"$TMPDIR\""
    sh -c "$DL" | sh -c "$EXTRACT" || { echo "Extract failed"; return 1; }
  elif command -v unzip >/dev/null 2>&1; then
    ZIPFILE="$TMPDIR/in.zip"
    sh -c "$DL" > "$ZIPFILE" || { echo "Download failed"; return 1; }
    unzip -o "$ZIPFILE" -d "$TMPDIR" || { echo "Unzip failed"; return 1; }
  else
    echo "Needs bsdtar or unzip to extract."
    return 1
  fi

  # Find .cue
  CUEFILE="$(find "$TMPDIR" -type f -iname '*.cue' | head -n 1)"
  if [ -z "$CUEFILE" ]; then
    echo "No .cue found in archive."
    return 1
  fi

  BASENAME="$(basename "${CUEFILE%.*}")"
  OUTPATH="$CWD/$BASENAME.chd"

  # chdman-bin
  if command -v chdman >/dev/null 2>&1; then
    CHDMAN="chdman"
  elif [ -x /usr/bin/mame/chdman ]; then
    CHDMAN="/usr/bin/mame/chdman"
  else
    echo "chdman not found."
    return 1
  fi

  echo "Creating CHD → $OUTPATH"
  "$CHDMAN" createcd -i "$CUEFILE" -o "$OUTPATH" || { echo "chdman failed"; return 1; }
  echo "Done: $OUTPATH"

  # Clear temporary files even if trap doesn't trigger
  rm -rf "$TMPDIR"
}
