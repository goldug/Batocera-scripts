# zip2dvd: download ZIP → extract temp → find .iso → create .chd in $PWD → cleanup
zip2dvd() {
  if [ $# -lt 1 ]; then
    echo "Usage: zip2dvd <zip-url>"
    return 2
  fi

  URL="$1"
  CWD="$(pwd)"
  TMPDIR="$(mktemp -d "$CWD/zip2dvd.XXXXXX")" || { echo "mktemp failed"; return 1; }

  cleanup() { rm -rf "$TMPDIR"; }
  trap cleanup EXIT INT TERM

  # Chooose downloader
  if command -v wget >/dev/null 2>&1; then
    DL="wget -O- \"$URL\""
  elif command -v curl >/dev/null 2>&1; then
    DL="curl -# -L \"$URL\""
  else
    echo "Needs wget or curl."
    return 1
  fi

  # Unpack
  if command -v bsdtar >/dev/null 2>&1; then
    sh -c "$DL" | bsdtar -xvf- -C "$TMPDIR" || { echo "Extract failed"; return 1; }
  elif command -v unzip >/dev/null 2>&1; then
    ZIPFILE="$TMPDIR/in.zip"
    sh -c "$DL" > "$ZIPFILE" || { echo "Download failed"; return 1; }
    unzip -o "$ZIPFILE" -d "$TMPDIR" || { echo "Unzip failed"; return 1; }
  else
    echo "Needs bsdtar or unzip to extract."
    return 1
  fi

  # Find .iso
  ISOFILE="$(find "$TMPDIR" -type f -iname '*.iso' | head -n 1)"
  if [ -z "$ISOFILE" ]; then
    echo "No .iso found in archive."
    rm -rf "$TMPDIR"
    return 1
  fi

  BASENAME="$(basename "${ISOFILE%.*}")"
  OUTPATH="$CWD/$BASENAME.chd"

  # chdman-bin
  if command -v chdman >/dev/null 2>&1; then
    CHDMAN="chdman"
  elif [ -x /usr/bin/mame/chdman ]; then
    CHDMAN="/usr/bin/mame/chdman"
  else
    echo "chdman not found."
    rm -rf "$TMPDIR"
    return 1
  fi

  echo "Creating CHD → $OUTPATH"
  "$CHDMAN" createdvd -i "$ISOFILE" -o "$OUTPATH" || { echo "chdman failed"; rm -rf "$TMPDIR"; return 1; }
  echo "Done: $OUTPATH"

  rm -rf "$TMPDIR"
}
