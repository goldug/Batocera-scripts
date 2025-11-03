#!/bin/sh

# Logga att custom.sh körs vid boot
logger "[custom.sh] Körs vid systemstart ($(date))"

# 1) Säkerställ symlänk till chdman
if [ ! -L /usr/bin/chdman ]; then
    ln -s /usr/bin/mame/chdman /usr/bin/chdman
fi

# 2) Se till att /etc/profile.d finns
[ -d /etc/profile.d ] || mkdir -p /etc/profile.d

# 3) Se till att /etc/profile laddar skript i /etc/profile.d (endast om saknas)
if ! grep -q '/etc/profile.d' /etc/profile 2>/dev/null; then
    cat >> /etc/profile <<'EOF'

# Load additional profile scripts
if [ -d /etc/profile.d ]; then
  for s in /etc/profile.d/*.sh; do
    [ -r "$s" ] && . "$s"
  done
fi
EOF
fi

# 4) Skapa/uppdatera global alias-fil för interaktiva skal
cat > /etc/profile.d/aliases.sh <<'EOF'
# Global aliases (loaded for login shells via /etc/profile)

# Färger för ls om stöds (BusyBox/GNU)
if ls --color=auto >/dev/null 2>&1; then
  alias ls='ls --color=auto'
elif ls --colour=auto >/dev/null 2>&1; then
  alias ls='ls --colour=auto'
fi

# Vanliga ls-alias
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias wine-deadzone='/userdata/system/wine-deadzone.sh'
EOF

logger "[custom.sh] alias-fil skapad"
chmod 644 /etc/profile.d/aliases.sh

# 5) Skapa/uppdatera url2chd-funktionen i separat fil
cat > /etc/profile.d/url2chd.sh <<'EOF'
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

  # Välj hämtare
  if command -v wget >/dev/null 2>&1; then
    DL="wget -qO- \"$URL\""
  elif command -v curl >/dev/null 2>&1; then
    DL="curl -sL \"$URL\""
  else
    echo "Needs wget or curl."
    return 1
  fi

  # Packa upp
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

  # Hitta .cue
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

  # Rensa temporära filer även om trap inte triggas
  rm -rf "$TMPDIR"
}
EOF

logger "[custom.sh] url2chd-fil skapad"
chmod 644 /etc/profile.d/url2chd.sh

# --- Xbox 360 driftfix via evsieve, robust detektering och retry ---
(
  DEADZONE=8000
  LINKNAME="/dev/input/by-id/x360-deadzone"
  MAX_TRIES=30
  TRY=1

  logger "[custom.sh] initierar evsieve deadzone-filter (±$DEADZONE)"

  EVENT=""
  for i in $(seq 1 $MAX_TRIES); do
      DEVPATH=$(grep -l "Xbox 360 Wireless Receiver" /sys/class/input/event*/device/name 2>/dev/null | head -n1)
      if [ -n "$DEVPATH" ]; then
          # extrahera event-numret direkt, även om sökvägen innehåller 'device'
          EVENTNUM=$(echo "$DEVPATH" | sed -n 's#.*/\(event[0-9]\+\)/device/name#\1#p')
          if [ -n "$EVENTNUM" ] && [ -e "/dev/input/$EVENTNUM" ]; then
              EVENT="/dev/input/$EVENTNUM"
              break
          fi
      fi
      sleep 1
  done

  if [ -z "$EVENT" ]; then
      logger "[custom.sh] hittade ingen Xbox 360-enhet, avbryter evsieve-start"
      exit 1
  fi

  for i in $(seq 1 10); do
      logger "[custom.sh] försöker starta evsieve på $EVENT (försök $i)"
      /usr/bin/evsieve \
          --input "$EVENT" grab \
          --map abs:x:-${DEADZONE}~${DEADZONE}     abs:x:0 \
          --map abs:y:-${DEADZONE}~${DEADZONE}     abs:y:0 \
          --map abs:rx:-${DEADZONE}~${DEADZONE}    abs:rx:0 \
          --map abs:ry:-${DEADZONE}~${DEADZONE}    abs:ry:0 \
          --output create-link="$LINKNAME" \
          >/var/log/evsieve-deadzone.log 2>&1 &
      sleep 2
      if ps | grep -q "[e]vsieve"; then
          logger "[custom.sh] evsieve startade korrekt på $EVENT"
          break
      else
          logger "[custom.sh] evsieve misslyckades (troligen busy), försöker igen..."
          sleep 3
      fi
  done
) & 

exit 0
