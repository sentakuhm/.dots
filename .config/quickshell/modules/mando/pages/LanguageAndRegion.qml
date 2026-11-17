import QtQuick
import QtQuick.Layouts
import Quickshell
import Sentaku.Config
import Sentaku.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.mando.common

PageBase {
    id: root

    // Temperature units (there must be one for each value of the TemperatureUnit enum)
    readonly property list<MenuItem> tempItems: [
        MenuItem {
            text: Tr.tr("Auto")
            value: TemperatureUnit.Auto
        },
        MenuItem {
            text: Tr.tr("°C")
            value: TemperatureUnit.Celsius
        },
        MenuItem {
            text: Tr.tr("°F")
            value: TemperatureUnit.Fahrenheit
        },
        MenuItem {
            text: Tr.tr("K")
            value: TemperatureUnit.Kelvin
        }
    ]

    // Data size units (there must be one for each value of the DataUnit enum)
    readonly property list<MenuItem> dataItems: [
        MenuItem {
            text: Tr.tr("Binary (KiB, MiB)")
            value: DataUnit.Binary
        },
        MenuItem {
            text: Tr.tr("Decimal (KB, MB)")
            value: DataUnit.Decimal
        }
    ]

    // Clock formats (there must be one for each value of the ClockFormat enum)
    readonly property list<MenuItem> clockItems: [
        MenuItem {
            text: Tr.tr("Auto")
            value: ClockFormat.Auto
        },
        MenuItem {
            text: Tr.tr("12-hour")
            value: ClockFormat.TwelveHour
        },
        MenuItem {
            text: Tr.tr("24-hour")
            value: ClockFormat.TwentyFourHour
        }
    ]

    title: Tr.tr("Language & region")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Language
        SectionHeader {
            first: true
            text: Tr.tr("Language")
        }

        SelectRow {
            first: true
            last: true
            label: Tr.tr("UI language")
            subtext: Tr.tr("The language used in the shell UI")
            active: menuItems.find(i => i.modelData === Tr.language) ?? autoLang
            onSelected: item => {
                Tr.language = item.modelData ?? ""; // qmllint disable missing-property
            }

            menuItems: [autoLang, ...langItems.instances]

            MenuItem {
                id: autoLang

                text: Tr.tr("Auto")
            }

            Variants {
                id: langItems

                model: Tr.supportedLanguages

                MenuItem {
                    required property string modelData

                    text: {
                        const locale = Qt.locale(modelData);
                        return locale.name === "C" ? modelData : locale.nativeLanguageName || locale.name;
                    }
                }
            }
        }

        // Weather
        SectionHeader {
            text: Tr.tr("Weather")
        }

        // Manual location (used instead of the automatic IP-based one)
        TextFieldRow {
            first: true
            label: Tr.tr("Name")
            subtext: Tr.tr("City name shown on the dashboard")
            placeholderText: Tr.tr("e.g. Warsaw")
            value: WeatherLocation.name
            onEditingFinished: value => {
                WeatherLocation.name = value.trim();
                WeatherLocation.save();
            }
        }

        TextFieldRow {
            label: Tr.tr("Province")
            subtext: Tr.tr("Province or state shown under the city name")
            value: WeatherLocation.province
            onEditingFinished: value => {
                WeatherLocation.province = value.trim();
                WeatherLocation.save();
            }
        }

        TextFieldRow {
            label: Tr.tr("Country")
            subtext: Tr.tr("Country shown under the city name")
            value: WeatherLocation.country
            onEditingFinished: value => {
                WeatherLocation.country = value.trim();
                WeatherLocation.save();
            }
        }

        TextFieldRow {
            label: Tr.tr("Lat (Latitude)")
            subtext: Tr.tr("Latitude in degrees, -90 to 90")
            placeholderText: "52.2297"
            smallField: true
            validate: /^-?\d+(\.\d+)?$/
            errorText: Tr.tr("Latitude must be a number between -90 and 90")
            value: WeatherLocation.lat
            onEditingFinished: value => {
                if (!field.valid)
                    return;
                const num = Number(value);
                if (num < -90 || num > 90)
                    return;
                WeatherLocation.lat = value.trim();
                WeatherLocation.save();
            }
        }

        TextFieldRow {
            label: Tr.tr("Lon (Longitude)")
            subtext: Tr.tr("Longitude in degrees, -180 to 180")
            placeholderText: "21.0122"
            smallField: true
            validate: /^-?\d+(\.\d+)?$/
            errorText: Tr.tr("Longitude must be a number between -180 and 180")
            value: WeatherLocation.lon
            onEditingFinished: value => {
                if (!field.valid)
                    return;
                const num = Number(value);
                if (num < -180 || num > 180)
                    return;
                WeatherLocation.lon = value.trim();
                WeatherLocation.save();
            }
        }

        RowButton {
            last: true
            icon: "my_location"
            text: Tr.tr("Use automatic location")
            subtext: Tr.tr("Clear the manual location and detect it from the IP address")
            disabled: !WeatherLocation.isSet
            onClicked: WeatherLocation.clear()
        }

        // Units
        SectionHeader {
            text: Tr.tr("Units")
        }

        SelectRow {
            first: true
            label: Tr.tr("Temperature")
            subtext: Tr.tr("Units for weather temperatures")
            menuItems: root.tempItems
            active: root.tempItems.find(i => i.value === GlobalConfig.services.weatherUnits)
            onSelected: item => GlobalConfig.services.weatherUnits = item.value
        }

        SelectRow {
            label: Tr.tr("System temperatures")
            subtext: Tr.tr("Units for CPU and GPU temperatures")
            menuItems: root.tempItems
            active: root.tempItems.find(i => i.value === GlobalConfig.services.sensorUnits)
            onSelected: item => GlobalConfig.services.sensorUnits = item.value
        }

        SelectRow {
            last: true
            label: Tr.tr("Data sizes")
            subtext: Tr.tr("Units for data sizes and network speeds")
            menuItems: root.dataItems
            active: root.dataItems.find(i => i.value === GlobalConfig.services.dataUnits)
            onSelected: item => GlobalConfig.services.dataUnits = item.value
        }

        // Time & date
        SectionHeader {
            text: Tr.tr("Time & date")
        }

        SelectRow {
            first: true
            last: true
            label: Tr.tr("Clock format")
            subtext: Tr.tr("How times are shown across the shell")
            menuOnTop: true
            menuItems: root.clockItems
            active: root.clockItems.find(i => i.value === GlobalConfig.services.clockFormat)
            onSelected: item => GlobalConfig.services.clockFormat = item.value
        }
    }
}
