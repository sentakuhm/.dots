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

            color: Colours.tPalette.m3surface
            surfaceFormat.opaque: false

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }

            implicitWidth: mando.implicitWidth
            implicitHeight: mando.implicitHeight

            minimumSize.width: contentItem.Tokens.sizes.mando.minWidth
            minimumSize.height: contentItem.Tokens.sizes.mando.minHeight

            contentItem.Config.screen: screen.name
            contentItem.Tokens.screen: screen.name

            title: Tr.tr("Mando — %1").arg(PageRegistry.pages[mando.nState.currentPageIdx].label)

            Mando {
                id: mando

                anchors.fill: parent
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
