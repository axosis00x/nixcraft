pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Shared weather for the desktop widget and the dashboard: one wttr.in
// request every five minutes (it rate-limits).
Singleton {
    id: root

    property string tempC: ""
    property string conditionText: ""
    property int weatherCode: 0
    property string feelsLikeC: ""
    property string humidity: ""
    property string windKmph: ""
    property string highC: ""
    property string lowC: ""
    property string location: ""
    property bool isStale: false
    readonly property bool available: tempC !== ""

    function isNight() {
        var h = new Date().getHours();
        return h < 6 || h >= 18;
    }

    function iconGlyph(code) {
        if (code === 113)
            return isNight() ? "clear_night" : "wb_sunny";
        if (code === 116)
            return isNight() ? "partly_cloudy_night" : "partly_cloudy_day";
        if ([119, 122, 143, 248, 260].includes(code))
            return "cloud";
        if ([176, 179, 182, 185, 200, 263, 266, 293, 296, 299, 302, 305, 308, 311, 314, 317, 320, 353, 356, 359, 386, 389].includes(code))
            return "rainy";
        if ([227, 230, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377, 392, 395].includes(code))
            return "weather_snowy";
        return "cloud";
    }

    function refresh() {
        weatherProcess.running = true;
    }

    // Persistent last-known-good reading, survives quickshell/session restarts.
    FileView {
        id: cacheFile
        path: Quickshell.cachePath("desktop-weather-cache.json")
        watchChanges: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: cache
            property string tempC: ""
            property string conditionText: ""
            property int weatherCode: 0
            property string feelsLikeC: ""
            property string humidity: ""
            property string windKmph: ""
            property string highC: ""
            property string lowC: ""
            property string location: ""

            onTempCChanged: {
                if (root.tempC === "" && cache.tempC !== "") {
                    root.tempC = cache.tempC;
                    root.conditionText = cache.conditionText;
                    root.weatherCode = cache.weatherCode;
                    root.feelsLikeC = cache.feelsLikeC;
                    root.humidity = cache.humidity;
                    root.windKmph = cache.windKmph;
                    root.highC = cache.highC;
                    root.lowC = cache.lowC;
                    root.location = cache.location;
                    root.isStale = true;
                }
            }
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: weatherProcess
        command: ["curl", "-s", "--max-time", "8", "https://wttr.in/?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text);
                    var current = data.current_condition[0];
                    var today = data.weather && data.weather[0];
                    var area = data.nearest_area && data.nearest_area[0];
                    root.tempC = current.temp_C;
                    root.conditionText = current.weatherDesc[0].value.trim();
                    root.weatherCode = parseInt(current.weatherCode);
                    root.feelsLikeC = current.FeelsLikeC || "";
                    root.humidity = current.humidity || "";
                    root.windKmph = current.windspeedKmph || "";
                    root.highC = today ? today.maxtempC : "";
                    root.lowC = today ? today.mintempC : "";
                    root.location = area && area.areaName ? area.areaName[0].value : "";
                    root.isStale = false;

                    cache.tempC = root.tempC;
                    cache.conditionText = root.conditionText;
                    cache.weatherCode = root.weatherCode;
                    cache.feelsLikeC = root.feelsLikeC;
                    cache.humidity = root.humidity;
                    cache.windKmph = root.windKmph;
                    cache.highC = root.highC;
                    cache.lowC = root.lowC;
                    cache.location = root.location;
                } catch (e) {
                    // Transient network/parse failure — keep showing the
                    // last good reading (live or cached) instead of blanking out.
                }
            }
        }
    }
}
