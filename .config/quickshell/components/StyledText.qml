pragma ComponentBehavior: Bound

import QtQuick
import Sentaku.Config
import qs.services

Text {
    id: root

    property bool animate: false

    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    color: Colours.palette.m3onSurface
    font: Tokens.font.body.small

    // Native text is rasterised at its unscaled size, so it goes soft when an ancestor scales it
    // (the dashboard and quick menu are scaled down, see shell.qml `bottomPanelScale`). Scalable
    // rendering stays crisp, so use it for text that sits inside a scaled item.
    Component.onCompleted: {
        let s = 1;
        for (let p = root.parent; p; p = p.parent)
            s *= p.scale;
        if (Math.abs(s - 1) > 0.01)
            root.renderType = Text.QtRendering;
    }

    Behavior on color {
        CAnim {}
    }

    Behavior on text {
        enabled: root.animate

        SequentialAnimation {
            Anim {
                target: root
                property: "opacity"
                to: 0
                type: Anim.FastEffects
            }
            PropertyAction {}
            Anim {
                target: root
                property: "opacity"
                to: 1
                type: Anim.DefaultEffects
            }
        }
    }
}
