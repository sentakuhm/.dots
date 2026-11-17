import QtQuick
import Quickshell
import Quickshell.Wayland
import Sentaku.Config
import qs.services

import "../Theme.js" as Theme

// Wallpaper: a full-screen image drawn by the shell itself, on the bottom
// layer behind everything else (frame, bar, panels).
//
// It follows `Wallpapers.current`, so picking a wallpaper anywhere in the
// shell updates it live, and the saved selection (the Wallpapers state
// file) is restored on every shell start, so it survives a reboot.
PanelWindow {
    id: root

    required property var targetScreen

    screen: targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    Config.screen: targetScreen.name
    visible: Config.background.wallpaperEnabled

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "senta-wallpaper"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Shown while the image is loading or if it fails, so the desktop
    // never goes fully blank.
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Image {
        anchors.fill: parent
        source: Wallpapers.current
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        visible: status === Image.Ready
    }
}
