pragma Singleton

import QtQuick
import Quickshell
import Sentaku.Config
import Sentaku.I18n
import qs.components
import qs.services
import qs.modules.mando

Singleton {
    id: root

    // Scale of the whole settings UI (1 = original size). Set from the quick menu host, which gets
    // it from shell.qml `bottomPanelScale`, so Mando is scaled together with the quick menu and
    // the dashboard no matter where it is opened from.
    property real uiScale: 1

    function create(parent: Item, props: var, initialPage = -1): void {
        const p = props === undefined ? {} : props;
        p.initialPage = initialPage;
        mandoComp.createObject(parent ?? dummy, p);
    }

    QtObject {
        id: dummy
    }

    Component {
        id: mandoComp

        FloatingWindow {
            id: win

            // Index of the page to start on (PageRegistry.pages order); -1 = default.
            property int initialPage: -1
            // The settings UI is laid out at its normal size and scaled to fit the window, so the
            // window and everything in it shrink together (and resizing still reflows the content).
            readonly property real uiScale: Math.max(0.4, Math.min(1.25, root.uiScale))

            color: Colours.tPalette.m3surface
            surfaceFormat.opaque: false

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }

            implicitWidth: Math.round(mando.implicitWidth * uiScale)
            implicitHeight: Math.round(mando.implicitHeight * uiScale)

            minimumSize.width: Math.round(contentItem.Tokens.sizes.mando.minWidth * uiScale)
            minimumSize.height: Math.round(contentItem.Tokens.sizes.mando.minHeight * uiScale)

            contentItem.Config.screen: screen.name
            contentItem.Tokens.screen: screen.name

            title: Tr.tr("Mando — %1").arg(PageRegistry.pages[mando.nState.currentPageIdx].label)

            Mando {
                id: mando

                // Laid out at the unscaled size, then scaled down from the top-left corner to fill the window.
                width: parent.width / win.uiScale
                height: parent.height / win.uiScale
                scale: win.uiScale
                transformOrigin: Item.TopLeft
                nState.screen: win.screen
                nState.isWindow: true
                Component.onCompleted: {
                    if (win.initialPage >= 0)
                        nState.currentPageIdx = win.initialPage;
                }
                onClose: win.destroy()
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
