import QtQuick
import Quickshell
import Sentaku.State
import qs.daemons

// Background behaviour behind the quick menu. Created ONCE (on the primary screen) by
// components/UtilitiesSlot.qml, never per screen:
//   - Keep awake  -> daemons/IdleInhibit.qml (Wayland idle inhibitor + `qs ipc` target idleInhibitor)
//   - Game mode   -> daemons/GameMode.qml   (applies/restores Hyprland options + target gameMode)
//   - Do not disturb: the quick toggle follows, and drives, your NotifStore's `dnd`.
Scope {
    id: root

    // Senta's NotifStore (has a bool `dnd`).
    required property var notifs

    IdleInhibit {}
    GameMode {}

    FontLoader {
        source: Quickshell.shellPath("assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf")
    }

    // Senta's own state is the source of truth at startup: PersistentState survives
    // restarts, and a forgotten "do not disturb" after a reboot would silently hide notifications.
    Component.onCompleted: PersistentState.doNotDisturb = root.notifs.dnd

    Connections {
        function onDoNotDisturbChanged(): void {
            if (root.notifs.dnd !== PersistentState.doNotDisturb)
                root.notifs.dnd = PersistentState.doNotDisturb;
        }

        target: PersistentState
    }

    Connections {
        function onDndChanged(): void {
            if (PersistentState.doNotDisturb !== root.notifs.dnd)
                PersistentState.doNotDisturb = root.notifs.dnd;
        }

        target: root.notifs
    }
}
