pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    property string name: ""
    property string province: ""
    property string country: ""
    property string lat: ""
    property string lon: ""

    // A manual location only takes effect once valid coordinates are set
    readonly property bool hasCoords: isCoordinate(lat) && isCoordinate(lon)
    readonly property bool isSet: name !== "" || province !== "" || country !== "" || lat !== "" || lon !== ""

    function isCoordinate(value: string): bool {
        return value.trim() !== "" && Number.isFinite(Number(value))
    }

    function save(): void {
        storage.setText(JSON.stringify({
            "name": name,
            "province": province,
            "country": country,
            "lat": lat,
            "lon": lon
        }, null, 2));
    }

    function clear(): void {
        name = "";
        province = "";
        country = "";
        lat = "";
        lon = "";
        save();
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.config}/weather-location.json`

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.name = data.name ?? "";
                root.province = data.province ?? "";
                root.country = data.country ?? "";
                root.lat = data.lat ?? "";
                root.lon = data.lon ?? "";
            } catch (error) {
                console.warn(lc, `Unable to parse weather location file: ${error}`);
            }
        }

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                // File absent or removed externally: fall back to automatic location
                if (root.isSet) {
                    name = "";
                    province = "";
                    country = "";
                    lat = "";
                    lon = "";
                }
                return;
            }
            console.warn(lc, `Unable to load weather location: ${err}`);
        }
    }

    LoggingCategory {
        id: lc

        name: "sentaku.qml.services.weatherlocation"
        defaultLogLevel: LoggingCategory.Info
    }
}
