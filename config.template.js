/**************************************************************
 * MagicMirror Home DashCalendar - Config Template
 *
 * This file is processed by the setup script using envsubst.
 * Any ${VAR_NAME} placeholders are replaced by the installer.
 *
 * Always-on modules:
 *   - MMM-Remote-Control
 *   - clock
 *   - calendar (data source)
 *   - MMM-MonthlyCalendar
 *   - MMM-OneCallWeather
 *   - MMM-Wallpaper
 *
 * Optional modules (inserted as env blocks):
 *   - ${MODULE_TRAFFIC_BLOCK}
 *   - ${PSC_MODULE_BLOCK}
 *   - ${MODULE_HA_BLOCK}
 **************************************************************/

let config = {
  /************************************************************
   * Server / network
   ************************************************************/
  address: "localhost",
  port: 8080,
  basePath: "/",
  ipWhitelist: ["127.0.0.1", "::ffff:127.0.0.1", "::1"],

  useHttps: false,
  httpsPrivateKey: "",
  httpsCertificate: "",

  /************************************************************
   * General display settings
   ************************************************************/
  language: "en",
  locale: "en-US",
  logLevel: ["INFO", "LOG", "WARN", "ERROR"],
  timeFormat: 12,
  units: "imperial",

  /************************************************************
   * Modules
   ************************************************************/
  modules: [

    /**********************************************************
     * Remote control UI / API
     **********************************************************/
    {
      module: "MMM-Remote-Control",
      config: {
        showModuleApiMenu: false,
        customMenu: "custom_menu.json"
      }
    },

    /**********************************************************
     * Clock
     **********************************************************/
    {
      module: "clock",
      position: "top_left",
      config: {
        displaySeconds: false,
        showPeriodUpper: true
      }
    },

    /**********************************************************
     * Base calendar (feeds MMM-MonthlyCalendar)
     *
     * The setup script injects one or more calendars using
     * the ${CALENDAR_BLOCK} placeholder.
     **********************************************************/
    {
      module: "calendar",
      header: "",
      config: {
        broadcastEvents: true,
        broadcastPastEvents: true,
        maximumEntries: 1000,
        calendars: [
          ${CALENDAR_BLOCK}
        ]
      }
    },

    /**********************************************************
     * Monthly calendar grid
     *
     * CAL_VIEW_MODE is set by the setup script:
     *   - "currentMonth"
     *   - "fourWeeks"
     **********************************************************/
    {
      module: "MMM-MonthlyCalendar",
      position: "middle_center",
      config: {
        mode: "${CAL_VIEW_MODE}",
        displaySymbol: true,
        firstDayOfWeek: "sunday"
      }
    },

    /**********************************************************
     * Weather — MMM-OneCallWeather
     *
     * LATITUDE / LONGITUDE / OWM_API_KEY come from the script.
     **********************************************************/
    {
      module: "MMM-OneCallWeather",
      position: "top_left",
      classes: "leftWeather",
      header: "",
      config: {
        latitude: "${LATITUDE}",
        longitude: "${LONGITUDE}",
        apikey: "${OWM_API_KEY}",

        // Use One Call 3.0 API
        apiVersion: "3.0",

        // Match MagicMirror units + US-style wind
        units: "imperial",
        windUnits: "mph",

        // Icons: animated 9a set
        iconset: "9a",
        iconsetFormat: "svg",

        // Layout / behavior
        showCurrent: true,
        showForecast: true,
        arrangement: "vertical",     // forecast under current conditions
        forecastLayout: "columns",   // days as columns
        roundTemp: true,
        tableClass: "small",
        colored: true
      }
    },

    /**********************************************************
     * Wallpaper / photo slideshow — MMM-Wallpaper
     *
     * WALLPAPER_SOURCE is a full source string, e.g.:
     *   - "icloud:ALBUM_ID"
     *   - "bing"
     *   - "local:/home/pi/Pictures"
     *   - "/r/wallpapers"
     *
     * WALLPAPER_INTERVAL_MS is the slide interval in ms.
     **********************************************************/
    {
      module: "MMM-Wallpaper",
      position: "bottom_left",
      config: {
        source: "${WALLPAPER_SOURCE}",
        slideInterval: ${WALLPAPER_INTERVAL_MS}, // e.g. 15000 for 15s
        maximumEntries: 50,
        shuffle: true,
        crossfade: false,
        size: "contain",
        fillRegion: false,
        width: "350px",
        height: "350px"
      }
    },

    /**********************************************************
     * Optional modules (injected by setup script)
     *
     * Each block is either:
     *   - an empty string (disabled), or
     *   - starts with ",{" and contains the full module config
     *
     * This allows the script to completely omit the module
     * from the final config when the user chooses "no".
     **********************************************************/

    ${MODULE_TRAFFIC_BLOCK}
    ${PSC_MODULE_BLOCK}
    ${MODULE_HA_BLOCK}

  ]
};

if (typeof module !== "undefined") {
  module.exports = config;
}
