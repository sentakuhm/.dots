pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Sentaku
import Sentaku.Config
import Sentaku.I18n
import qs.components
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.dashboard as Dashboard

// The dashboard (tabs: Dashboard / Media / Performance / Weather), rising from
// the bottom frame.
//
// Adapted from `modules/dashboard/Wrapper.qml` (kept next to it, unused; GPL-3.0,
// see LICENSE and NOTICE). The differences from that wrapper:
//   - it slides in from the bottom (bottomMargin) instead of the top (topMargin),
//   - it draws its own background (BottomSurface) instead of relying on an
//     external border that the original wrapper was designed to hang from,
//   - it reserves `topPad` above the content, which the original gets from that
//     border, so the tabs keep exactly the same padding.
// Everything inside (`Dashboard.Content` and all the tabs) is used as-is.
Item {
    id: root

    required property ScreenState screenState
    // Concave foot radius where the panel blends into the frame.
    property real fillet: 14
    // Thickness of the frame strip the panel sits on.
    property real foot: 3

    // Verbatim from upstream Wrapper.qml.
    readonly property FileDialog facePicker: FileDialog {
        title: Tr.tr("Select a profile picture")
        filterLabel: Tr.tr("Image files")
        filters: Images.validImageExtensions
        onAccepted: path => {
            if (CUtils.copyFile(Qt.resolvedUrl(path), Qt.resolvedUrl(Paths.face)))
                // TRANSLATORS: %1 = a file path
                Quickshell.execDetached(["notify-send", "-a", "sentaku-shell", "-u", "low", "-h", `STRING:image-path:${path}`, Tr.tr("Profile picture changed"), Tr.tr("Profile picture changed to %1").arg(Paths.shortenHome(path))]);
            else
                // TRANSLATORS: %1 = a file path
                Quickshell.execDetached(["notify-send", "-a", "sentaku-shell", "-u", "critical", Tr.tr("Unable to change profile picture"), Tr.tr("Failed to change profile picture to %1").arg(Paths.shortenHome(path))]);
        }
    }

    readonly property real nonAnimHeight: (content.item as Dashboard.Content)?.nonAnimHeight ?? 0
    readonly property bool shouldBeActive: screenState.dashboard && Config.dashboard.enabled
    property real offsetScale: shouldBeActive ? 0 : 1
    property color surfaceColour: Colours.tPalette.m3surface

    // Upstream hangs the panel from the border (Config.border.thickness px) and
    // the tabs compensate for it, so keep that gap above the content.
    readonly property real topPad: Config.border.thickness

    visible: offsetScale < 1
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale
    implicitWidth: (content.implicitWidth || 854) + fillet * 2 // 854: hard coded fallback for first open (as upstream)
    implicitHeight: topPad + content.implicitHeight + foot
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on surfaceColour {
        CAnim {}
    }

    BottomSurface {
        anchors.fill: parent

        color: root.surfaceColour
        radius: Tokens.rounding.extraLarge
        fillet: root.fillet
        foot: root.foot
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.topMargin: root.topPad
        anchors.horizontalCenter: parent.horizontalCenter

        active: root.shouldBeActive || root.visible

        sourceComponent: Dashboard.Content {
            screenState: root.screenState
            facePicker: root.facePicker
        }
    }
}
