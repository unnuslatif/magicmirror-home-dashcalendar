#!/usr/bin/env bash
# ==========================================================
# MagicMirror Home DashCalendar Setup
#
# Generates:
#   - ~/MagicMirror/css/custom.css      (from themes/custom.css.template)
#   - ~/MagicMirror/config/config.js    (from config.template.js)
#
# And installs / updates the MagicMirror modules this layout uses.
# ==========================================================
set -euo pipefail

# ----------------------------------------------------------
# Paths
# ----------------------------------------------------------
MM_DIR="${HOME}/MagicMirror"
MM_CONFIG_DIR="${MM_DIR}/config"
MM_MODULE_DIR="${MM_DIR}/modules"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CSS_TEMPLATE="${SCRIPT_DIR}/themes/custom.css.template"
CONFIG_TEMPLATE="${SCRIPT_DIR}/config.template.js"

# ----------------------------------------------------------
# Basic dependency checks
# ----------------------------------------------------------
if [[ ! -d "$MM_DIR" ]]; then
  echo "ERROR: MagicMirror directory not found at $MM_DIR"
  echo "Install MagicMirror first, then re-run this script."
  exit 1
fi

if ! command -v envsubst >/dev/null 2>&1; then
  echo "ERROR: 'envsubst' not found."
  echo "Install it with:  sudo apt install gettext"
  exit 1
fi

require_command() {
  local cmd="$1"
  local hint="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "WARNING: '$cmd' not found. ${hint}"
    return 1
  fi
  return 0
}

# ----------------------------------------------------------
# Third-party MagicMirror modules
# ----------------------------------------------------------
declare -A MODULES=(
  ["MMM-Remote-Control"]="https://github.com/Jopyth/MMM-Remote-Control.git"
  ["MMM-MonthlyCalendar"]="https://github.com/kolbyjack/MMM-MonthlyCalendar.git"
  ["MMM-OneCallWeather"]="https://github.com/KristjanESPERANTO/MMM-OneCallWeather.git"
  ["MMM-Wallpaper"]="https://github.com/kolbyjack/MMM-Wallpaper.git"
  ["MMM-Traffic"]="https://github.com/SamLewis0602/MMM-Traffic.git"
  ["MMM-PresenceScreenControl"]="https://github.com/rkorell/MMM-PresenceScreenControl.git"
  ["MMM-HomeAssistant"]="https://github.com/ambarusa/MMM-HomeAssistant.git"
)

install_modules() {
  echo
  echo "=== Installing / updating MagicMirror modules ==="
  mkdir -p "$MM_MODULE_DIR"
  cd "$MM_MODULE_DIR"

  for MODULE in "${!MODULES[@]}"; do
    REPO_URL="${MODULES[$MODULE]}"
    if [[ -d "$MODULE" ]]; then
      echo "→ $MODULE exists, pulling latest..."
      git -C "$MODULE" pull --ff-only || true
    else
      echo "→ Cloning $MODULE from $REPO_URL"
      git clone "$REPO_URL" "$MODULE"
    fi

    if [[ -f "$MODULE/package.json" ]]; then
      echo "   npm install in $MODULE..."
      (cd "$MODULE" && npm install >/dev/null 2>&1 || true)
    fi
  done
}

# ----------------------------------------------------------
# Theme selection (warm dark base + accent)
# ----------------------------------------------------------
choose_theme() {
 choose_theme() {
  echo
  echo "=== Theme selection ==="
  echo "For now, the default purple glass theme will be used."
  echo "(Additional color themes can be added in a future version.)"

  mkdir -p "${MM_DIR}/css"
  cp "$CSS_TEMPLATE" "${MM_DIR}/css/custom.css"
  echo "→ Copied CSS template to ${MM_DIR}/css/custom.css"
}

# ----------------------------------------------------------
# Presence & screen control configuration
# ----------------------------------------------------------
configure_presence() {
  echo
  echo "=== Presence & screen control ==="
  echo "Presence mode:"
  echo "1) PIR only (simple)"
  echo "2) PIR + MQTT (advanced)"
  echo "3) No sensor (always on, no screen control)"
  read -rp "Choose [1-3]: " PRES_MODE

  PSC_MODE=""
  PSC_MQTT_SERVER=""
  PSC_MQTT_TOPIC=""
  PSC_MQTT_PAYLOAD_FIELD=""
  PSC_ON_COMMAND=""
  PSC_OFF_COMMAND=""
  PSC_TIMEOUT=0
  PSC_MODULE_ENABLED="false"

  case "$PRES_MODE" in
    1)
      PSC_MODE="PIR"
      PSC_MODULE_ENABLED="true"
      ;;
    2)
      PSC_MODE="PIR_MQTT"
      PSC_MODULE_ENABLED="true"
      echo "MQTT settings for presence (advanced):"
      read -rp "MQTT server URL (e.g. mqtt://YOUR_MQTT_HOST:1883): " PSC_MQTT_SERVER
      read -rp "MQTT topic (e.g. sensor/mirror_presence): " PSC_MQTT_TOPIC
      PSC_MQTT_PAYLOAD_FIELD="presence"
      ;;
    3)
      echo "Presence sensing disabled. Screen will remain on."
      echo "Skipping screen control options."
      ;;
    *)
      PSC_MODE="PIR"
      PSC_MODULE_ENABLED="true"
      ;;
  esac

  if [[ "$PSC_MODULE_ENABLED" != "true" ]]; then
    export PSC_MODE PSC_MQTT_SERVER PSC_MQTT_TOPIC PSC_MQTT_PAYLOAD_FIELD
    export PSC_ON_COMMAND PSC_OFF_COMMAND PSC_TIMEOUT PSC_MODULE_ENABLED
    return
  fi

  echo
  echo "Screen control method for ON/OFF commands:"
  echo "1) HDMI-CEC (control TV via CEC)"
  echo "2) xrandr (control monitor output)"
  echo "3) None (no on/off commands)"
  read -rp "Choose [1-3]: " SCREEN_MODE

  echo
  echo "Use xscreensaver in the commands?"
  echo "Requires xscreensaver to be installed and configured."
  read -rp "Enable xscreensaver integration? [y/N]: " USE_SAVER

  case "$SCREEN_MODE" in
    1)
      if ! require_command "cec-client" "Install with: sudo apt install cec-utils"; then
        echo "Disabling CEC screen control due to missing dependency."
        SCREEN_MODE=3
      else
        if [[ "$USE_SAVER" =~ ^[Yy]$ ]]; then
          require_command "xscreensaver-command" "Install with: sudo apt install xscreensaver" || USE_SAVER="n"
        fi
        if [[ "$USE_SAVER" =~ ^[Yy]$ ]]; then
          PSC_ON_COMMAND="DISPLAY=:0 xscreensaver-command -deactivate -display :0; echo 'on 0' | cec-client -s -d 1"
          PSC_OFF_COMMAND="DISPLAY=:0 xscreensaver-command -activate -display :0"
        else
          PSC_ON_COMMAND="echo 'on 0' | cec-client -s -d 1"
          PSC_OFF_COMMAND="echo 'standby 0' | cec-client -s -d 1"
        fi
      fi
      ;;
    2)
      if ! require_command "xrandr" "Install with: sudo apt install x11-xserver-utils"; then
        echo "Disabling xrandr screen control due to missing dependency."
        SCREEN_MODE=3
      else
        if [[ "$USE_SAVER" =~ ^[Yy]$ ]]; then
          require_command "xscreensaver-command" "Install with: sudo apt install xscreensaver" || USE_SAVER="n"
        fi
        if [[ "$USE_SAVER" =~ ^[Yy]$ ]]; then
          PSC_ON_COMMAND="DISPLAY=:0 xscreensaver-command -deactivate -display :0; xrandr --output HDMI-1 --auto"
          PSC_OFF_COMMAND="DISPLAY=:0 xscreensaver-command -activate -display :0"
        else
          PSC_ON_COMMAND="DISPLAY=:0 xrandr --output HDMI-1 --auto"
          PSC_OFF_COMMAND="DISPLAY=:0 xrandr --output HDMI-1 --off"
        fi
      fi
      ;;
    *)
      PSC_ON_COMMAND=""
      PSC_OFF_COMMAND=""
      ;;
  esac

  echo
  echo "Time (seconds) after last motion before OFF / saver command runs."
  read -rp "Presence timeout [default 120]: " PSC_TIMEOUT
  PSC_TIMEOUT="${PSC_TIMEOUT:-120}"

  export PSC_MODE PSC_MQTT_SERVER PSC_MQTT_TOPIC PSC_MQTT_PAYLOAD_FIELD
  export PSC_ON_COMMAND PSC_OFF_COMMAND PSC_TIMEOUT PSC_MODULE_ENABLED
}

# ----------------------------------------------------------
# Optional modules toggles (Traffic, Home Assistant)
# ----------------------------------------------------------
configure_optional_modules() {
  echo
  echo "=== Optional modules ==="
  read -rp "Enable commute module (MMM-Traffic)? [y/N]: " ENABLE_TRAFFIC
  if [[ "$ENABLE_TRAFFIC" =~ ^[Yy]$ ]]; then
    ENABLE_TRAFFIC_MODULE="true"
  else
    ENABLE_TRAFFIC_MODULE="false"
  fi

  read -rp "Enable MMM-HomeAssistant integration? [y/N]: " ENABLE_HA
  if [[ "$ENABLE_HA" =~ ^[Yy]$ ]]; then
    ENABLE_HA_MODULE="true"
    echo "Home Assistant / MQTT settings (for MMM-HomeAssistant):"
    read -rp "MQTT server for HA (e.g. mqtt://localhost): " HA_MQTT_SERVER
    read -rp "MQTT port for HA [1883]: " HA_MQTT_PORT
    HA_MQTT_PORT="${HA_MQTT_PORT:-1883}"
  else
    ENABLE_HA_MODULE="false"
    HA_MQTT_SERVER=""
    HA_MQTT_PORT="1883"
  fi

  export ENABLE_TRAFFIC_MODULE ENABLE_HA_MODULE
  export HA_MQTT_SERVER HA_MQTT_PORT
}

# ----------------------------------------------------------
# Wallpaper source selection (MMM-Wallpaper)
# ----------------------------------------------------------
configure_wallpaper_source() {
  echo "=== MMM-Wallpaper source ==="
  echo "Choose where your photos / art come from:"
  echo " 1) iCloud shared album"
  echo " 2) Bing daily wallpapers (default)"
  echo " 3) Local folder on this machine"
  echo " 4) Reddit subreddit"
  echo " 5) Reddit multireddit (/user/.../m/...)"
  echo " 6) FireTV wallpapers"
  echo " 7) Chromecast wallpapers"
  echo " 8) NASA APOD (standard resolution)"
  echo " 9) NASA APOD (high resolution)"
  echo "10) NASA image search (nasa:<search term>)"
  echo "11) Flickr API (flickr-api:<source>)"
  echo "12) MetMuseum collection (metmuseum:department,highlight,q)"
  echo "13) Lightroom album (lightroom:user.myportfolio.com/album)"
  echo "14) Synology Moments album"
  echo "15) URL (http(s)://...)"
  echo "16) Custom raw source string (advanced)"
  echo "17) Google Photos (via local sync folder)"
  read -rp "Choose [1-17]: " WP_CHOICE

  WALLPAPER_SOURCE=""
  WALLPAPER_NASA_API_KEY=""
  WALLPAPER_FLICKR_API_KEY=""
  WALLPAPER_RECURSE_LOCAL="false"

  case "$WP_CHOICE" in
    1)
      echo
      read -rp "iCloud album ID (the part after 'icloud.com/sharedalbum/#' -- the letters and numbers only): " ICLOUD_ALBUM
      WALLPAPER_SOURCE="icloud:${ICLOUD_ALBUM}"
      ;;
    3)
      echo
      read -rp "Local folder path (e.g. /home/pi/Pictures): " LOCAL_PATH
      WALLPAPER_SOURCE="local:${LOCAL_PATH}"
      read -rp "Recurse into subdirectories as well? [y/N]: " RECURSE
      if [[ "$RECURSE" =~ ^[Yy]$ ]]; then
        WALLPAPER_RECURSE_LOCAL="true"
      fi
      ;;
    4)
      echo
      read -rp "Subreddit name (without /r/, e.g. wallpapers): " SUB
      WALLPAPER_SOURCE="/r/${SUB}"
      ;;
    5)
      echo
      read -rp "Full multireddit path (e.g. /user/NAME/m/multi): " MULTI
      WALLPAPER_SOURCE="${MULTI}"
      ;;
    6)
      WALLPAPER_SOURCE="firetv"
      ;;
    7)
      WALLPAPER_SOURCE="chromecast"
      ;;
    8)
      WALLPAPER_SOURCE="apod"
      echo
      read -rp "NASA API key (required for APOD): " WALLPAPER_NASA_API_KEY
      ;;
    9)
      WALLPAPER_SOURCE="apodhd"
      echo
      read -rp "NASA API key (required for APOD HD): " WALLPAPER_NASA_API_KEY
      ;;
    10)
      echo
      read -rp "NASA image search term (e.g. nebula, mars): " NASA_TERM
      WALLPAPER_SOURCE="nasa:${NASA_TERM}"
      read -rp "NASA API key (required for nasa:<search term>): " WALLPAPER_NASA_API_KEY
      ;;
    11)
      echo
      echo "Flickr source examples:"
      echo "  publicPhotos"
      echo "  tags/cat,dog/all"
      echo "  photos/username"
      echo "  photos/username/favorites"
      echo "  photos/username/albums/ALBUM_ID"
      echo "  groups/groupname"
      read -rp "Flickr source (see 'https://github.com/kolbyjack/MMM-Wallpaper'): " FLICKR_SRC
      WALLPAPER_SOURCE="flickr-api:${FLICKR_SRC}"
      read -rp "Flickr API key (required): " WALLPAPER_FLICKR_API_KEY
      ;;
    12)
      echo
      read -rp "MetMuseum department ID (number, or *): " MET_DEPT
      read -rp "Highlight only? (true/false or *): " MET_HIGHLIGHT
      read -rp "Search term (artist, culture, or *): " MET_Q
      MET_DEPT="${MET_DEPT:-*}"
      MET_HIGHLIGHT="${MET_HIGHLIGHT:-*}"
      MET_Q="${MET_Q:-*}"
      WALLPAPER_SOURCE="metmuseum:${MET_DEPT},${MET_HIGHLIGHT},${MET_Q}"
      ;;
    13)
      echo
      read -rp "Lightroom album path (user.myportfolio.com/album): " LR_PATH
      WALLPAPER_SOURCE="lightroom:${LR_PATH}"
      ;;
    14)
      echo
      read -rp "Synology Moments album URL: " SYNO_URL
      WALLPAPER_SOURCE="synology-moments:${SYNO_URL}"
      ;;
    15)
      echo
      read -rp "URL (http(s)://...): " WP_URL
      WALLPAPER_SOURCE="${WP_URL}"
      ;;
    16)
      echo
      echo "Enter the raw MMM-Wallpaper source string, e.g.:"
      echo "  apod"
      echo "  apodhd"
      echo "  flickr-api:publicPhotos"
      echo "  metmuseum:11,true,*"
      echo "  nasa:moon"
      echo "  /r/wallpapers"
      echo "  local:/home/pi/Pictures"
      read -rp "Source: " RAW_SOURCE
      WALLPAPER_SOURCE="${RAW_SOURCE}"
      ;;
    17)
      echo
      echo "Google Photos is not directly supported by MMM-Wallpaper."
      echo "You can sync an album to a local folder and point MMM-Wallpaper at it."
      read -rp "Local folder path with synced Google Photos (e.g. /home/pi/GooglePhotos): " GP_PATH
      WALLPAPER_SOURCE="local:${GP_PATH}"
      read -rp "Recurse into subdirectories as well? [y/N]: " RECURSE
      if [[ "$RECURSE" =~ ^[Yy]$ ]]; then
        WALLPAPER_RECURSE_LOCAL="true"
      fi
      ;;
    2|*)
      WALLPAPER_SOURCE="bing"
      ;;
  esac

  export WALLPAPER_SOURCE WALLPAPER_NASA_API_KEY WALLPAPER_FLICKR_API_KEY WALLPAPER_RECURSE_LOCAL
}

# ----------------------------------------------------------
# Weather / calendar / wallpaper / traffic inputs
# ----------------------------------------------------------
configure_apis() {
  echo
  echo "=== Weather / calendar / wallpaper / traffic ==="

  read -rp "Latitude (for weather): " LATITUDE
  read -rp "Longitude (for weather): " LONGITUDE
  read -rp "OpenWeather One Call API key: " OWM_API_KEY

  echo
  echo "Calendar URLs (iCloud, Google, etc.)"
  read -rp "Primary calendar URL (required, webcal/https): " CAL_URL_1
  read -rp "Second calendar URL (optional, Enter to skip): " CAL_URL_2
  read -rp "Third calendar URL (optional, Enter to skip): " CAL_URL_3

  echo
  echo "Monthly calendar view mode:"
  echo "1) Current month (default)"
  echo "2) Rolling 4-week view"
  read -rp "Choose [1-2]: " CAL_VIEW_CHOICE
  case "$CAL_VIEW_CHOICE" in
    2) CAL_VIEW_MODE="fourWeeks" ;;
    *) CAL_VIEW_MODE="currentMonth" ;;
  esac

  echo
  configure_wallpaper_source

  read -rp "Wallpaper slide interval in seconds [15]: " WALLPAPER_INTERVAL_SEC
  WALLPAPER_INTERVAL_SEC="${WALLPAPER_INTERVAL_SEC:-15}"
  WALLPAPER_INTERVAL_MS=$((WALLPAPER_INTERVAL_SEC * 1000))

  echo
  if [[ "$ENABLE_TRAFFIC_MODULE" == "true" ]]; then
    read -rp "Mapbox API token (for MMM-Traffic): " MAPBOX_TOKEN
    read -rp "Origin coords (lon,lat) (e.g. -117.918972,33.812145): " ORIGIN_COORDS
    read -rp "Destination coords (lon,lat): " DESTINATION_COORDS
    read -rp "Destination label (e.g. Work, School, etc): " DEST_NAME
  else
    MAPBOX_TOKEN=""
    ORIGIN_COORDS=""
    DESTINATION_COORDS=""
    DEST_NAME=""
  fi

  export LATITUDE LONGITUDE OWM_API_KEY
  export CAL_URL_1 CAL_URL_2 CAL_URL_3 CAL_VIEW_MODE
  export WALLPAPER_INTERVAL_MS
  export MAPBOX_TOKEN ORIGIN_COORDS DESTINATION_COORDS DEST_NAME
}

# ----------------------------------------------------------
# Build calendar block snippet
# ----------------------------------------------------------
build_calendar_block() {
  local pieces=()

  if [[ -n "${CAL_URL_1:-}" ]]; then
    pieces+=("{
          symbol: \"calendar-check\",
          url: \"${CAL_URL_1}\"
        }")
  fi

  if [[ -n "${CAL_URL_2:-}" ]]; then
    pieces+=("{
          symbol: \"calendar\",
          url: \"${CAL_URL_2}\"
        }")
  fi

  if [[ -n "${CAL_URL_3:-}" ]]; then
    pieces+=("{
          symbol: \"calendar\",
          url: \"${CAL_URL_3}\"
        }")
  fi

  local joined=""
  local first=1
  for entry in "${pieces[@]}"; do
    if [[ $first -eq 1 ]]; then
      joined="$entry"
      first=0
    else
      joined="${joined},
        ${entry}"
    fi
  done

  CALENDAR_BLOCK="$joined"
  export CALENDAR_BLOCK
}

# ----------------------------------------------------------
# Build optional module JS snippets
# ----------------------------------------------------------
build_optional_module_blocks() {
  MODULE_TRAFFIC_BLOCK=""
  if [[ "$ENABLE_TRAFFIC_MODULE" == "true" ]]; then
    MODULE_TRAFFIC_BLOCK=$(cat <<EOF

    ,{
      module: "MMM-Traffic",
      position: "bottom_left",
      config: {
        accessToken: "${MAPBOX_TOKEN}",
        mode: "driving",
        originCoords: "${ORIGIN_COORDS}",
        destinationCoords: "${DESTINATION_COORDS}",
        firstLine: "{duration} mins to ${DEST_NAME}",
        secondLine: "via {route}"
      }
    }
EOF
)
  fi

  MODULE_HA_BLOCK=""
  if [[ "$ENABLE_HA_MODULE" == "true" ]]; then
    MODULE_HA_BLOCK=$(cat <<EOF

    ,{
      module: "MMM-HomeAssistant",
      config: {
        mqttServer: "${HA_MQTT_SERVER}",
        mqttPort: ${HA_MQTT_PORT},
        deviceName: "My MagicMirror",
        autodiscoveryTopic: "homeassistant",
        brightnessControl: true,
        moduleControl: true,
        pm2ProcessName: "MagicMirror"
      }
    }
EOF
)
  fi

  export MODULE_TRAFFIC_BLOCK MODULE_HA_BLOCK
}

# ----------------------------------------------------------
# Build presence module block
# ----------------------------------------------------------
build_presence_block() {
  PSC_MODULE_BLOCK=""
  if [[ "${PSC_MODULE_ENABLED:-false}" == "true" && -n "${PSC_MODE:-}" ]]; then
    PSC_MODULE_BLOCK=$(cat <<EOF

    ,{
      module: "MMM-PresenceScreenControl",
      position: "bottom_bar",
      config: {
        mode: "${PSC_MODE}",
        pirGPIO: 4,
        mqttServer: "${PSC_MQTT_SERVER}",
        mqttTopic: "${PSC_MQTT_TOPIC}",
        mqttPayloadOccupancyField: "${PSC_MQTT_PAYLOAD_FIELD}",
        onCommand: \`${PSC_ON_COMMAND}\`,
        offCommand: \`${PSC_OFF_COMMAND}\`,
        counterTimeout: ${PSC_TIMEOUT},
        autoDimmer: true,
        autoDimmerTimeout: 10,
        showPresenceStatus: false,
        showCounter: false,
        debug: "simple"
      }
    }
EOF
)
  fi
  export PSC_MODULE_BLOCK
}

# ----------------------------------------------------------
# Generate config.js from config.template.js
# ----------------------------------------------------------
generate_config() {
  echo
  echo "=== Writing MagicMirror config.js from template ==="
  mkdir -p "$MM_CONFIG_DIR"
  DEST_CONFIG="${MM_CONFIG_DIR}/config.js"

  if [[ -f "$DEST_CONFIG" ]]; then
    cp "$DEST_CONFIG" "${DEST_CONFIG}.bak.$(date +%s)"
    echo "→ Backed up existing config to ${DEST_CONFIG}.bak.*"
  fi

  envsubst < "$CONFIG_TEMPLATE" > "$DEST_CONFIG"
  echo "→ Wrote config to $DEST_CONFIG"
}

# ----------------------------------------------------------
# Main
# ----------------------------------------------------------
echo "==============================================="
echo " MagicMirror Home DashCalendar Setup by Unnus"
echo "==============================================="

install_modules
choose_theme
configure_presence
configure_optional_modules
configure_apis
build_calendar_block
build_optional_module_blocks
build_presence_block
generate_config

echo
echo "Setup complete!"
echo "Start MagicMirror with e.g.:"
echo "  cd \"$MM_DIR\" && npm start"
echo "or (if using pm2):"
echo "  pm2 restart MagicMirror"
