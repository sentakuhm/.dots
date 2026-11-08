import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification service, modelled on Caelestia's Notifs service.
//
// It owns the NotificationServer (org.freedesktop.Notifications) and wraps
// every incoming notification in a small `Notif` object that
//   - caches the content, so a card can still animate out after the app has
//     closed the notification,
//   - runs the toast timer (paused while hovered),
//   - knows whether it is currently shown as a floating toast (`popup`).
// Toasts expire into the notification center; they are only removed for good
// when the user dismisses them or the app closes them.
Scope {
    id: root

    property bool dnd: false
    // All notifications, newest first.
    property var all: []
    // Notifications currently shown as toasts.
    readonly property var popups: all.filter(n => n.popup)
    readonly property int count: all.length
    // Distinct app names (group keys) in order of their newest notification.
    readonly property var appNames: {
        const seen = ({})
        const out = []
        for (const n of all) {
            if (!seen[n.group]) {
                seen[n.group] = true
                out.push(n.group)
            }
        }
        return out
    }
    // Ticks every 30 s so relative timestamps ("5m") stay fresh.
    property var now: new Date()

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    function timeAgo(time, now): string {
        const s = Math.max(0, Math.floor((now - time) / 1000))
        if (s < 60) return "now"
        const m = Math.floor(s / 60)
        if (m < 60) return m + "m"
        const h = Math.floor(m / 60)
        if (h < 24) return h + "h"
        return Math.floor(h / 24) + "d"
    }

    // Resolve an icon name or path from the sender to something an Image can load.
    function iconPath(name): string {
        if (!name) return ""
        if (name.startsWith("/") || name.startsWith("file:") || name.startsWith("image:")) return name
        return Quickshell.iconPath(name, true)
    }

    function receive(n): void {
        n.tracked = true

        // An app updating an existing notification: refresh it and show it again.
        const existing = root.all.find(w => w.notification === n)
        if (existing) {
            existing.sync()
            existing.popup = !root.dnd
            return
        }

        const w = notifComp.createObject(root, { notification: n, store: root })
        // Notifications carried over a hot reload (lastGeneration) are not re-announced.
        w.popup = !root.dnd && !n.lastGeneration
        root.all = [w, ...root.all]
    }

    function remove(notif): void {
        root.all = root.all.filter(n => n !== notif)
        notif.dispose()
    }

    function clearAll(): void {
        for (const n of root.all.slice()) n.close()
    }

    function clearGroup(name): void {
        for (const n of root.all.filter(n => n.group === name)) n.close()
    }

    function hidePopups(): void {
        for (const n of root.all) n.popup = false
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        imageSupported: true
        inlineReplySupported: true
        persistenceSupported: true

        onNotification: notification => root.receive(notification)
    }

    Component {
        id: notifComp
        Notif {}
    }

    component Notif: QtObject {
        id: notif

        property var notification: null
        property var store: null

        // Shown as a floating toast right now?
        property bool popup: false
        // Pointer is over its toast (pauses the timer).
        property bool hovered: false
        property bool disposed: false
        readonly property var time: new Date()

        // Cached content (kept after the sender closes the notification).
        property int nid: -1
        property string summary: ""
        property string body: ""
        property string appName: ""
        property string appIcon: ""
        property string image: ""
        property bool critical: false
        property real expireTimeout: 0
        property bool hasInlineReply: false
        property string inlineReplyPlaceholder: ""
        property var actions: []
        readonly property string group: appName.length > 0 ? appName : "Other"

        onNotificationChanged: sync()

        function sync(): void {
            const n = notification
            if (!n) return
            nid = n.id
            summary = n.summary || ""
            body = n.body || ""
            appName = n.appName || n.desktopEntry || ""
            appIcon = n.appIcon || ""
            image = n.image || ""
            critical = n.urgency === NotificationUrgency.Critical
            expireTimeout = n.expireTimeout || 0
            hasInlineReply = n.hasInlineReply || false
            inlineReplyPlaceholder = n.inlineReplyPlaceholder || ""
            const list = []
            const src = n.actions
            if (src) for (let i = 0; i < src.length; i++) list.push(src[i])
            actions = list
        }

        // Dismiss for good: tell the sender and drop it from the center.
        function close(): void {
            const n = notification
            if (n) {
                try { n.dismiss() } catch (e) {}
            }
            if (store) store.remove(notif)
        }

        function reply(text): void {
            const n = notification
            if (n) {
                try { n.sendInlineReply(text) } catch (e) {}
            }
        }

        // Called once it has left the list; the delay lets its card finish
        // sliding out before the cached content disappears.
        function dispose(): void {
            if (disposed) return
            disposed = true
            popup = false
            reaper.start()
        }

        readonly property Timer timer: Timer {
            // Critical notifications stay until dismissed, unless the sender set a timeout.
            running: notif.popup && !notif.hovered && !(notif.critical && notif.expireTimeout <= 0)
            // Quickshell reports small timeouts in seconds; treat < 100 as seconds.
            interval: notif.expireTimeout <= 0 ? 5000
                    : (notif.expireTimeout < 100 ? notif.expireTimeout * 1000 : notif.expireTimeout)
            onTriggered: notif.popup = false
        }

        readonly property Timer reaper: Timer {
            interval: 1500
            onTriggered: notif.destroy()
        }

        readonly property Connections conn: Connections {
            target: notif.notification
            ignoreUnknownSignals: true

            function onSummaryChanged(): void { notif.sync() }
            function onBodyChanged(): void { notif.sync() }
            function onAppNameChanged(): void { notif.sync() }
            function onAppIconChanged(): void { notif.sync() }
            function onImageChanged(): void { notif.sync() }
            function onUrgencyChanged(): void { notif.sync() }
            function onActionsChanged(): void { notif.sync() }
            function onClosed(): void { if (notif.store) notif.store.remove(notif) }
        }
    }
}
