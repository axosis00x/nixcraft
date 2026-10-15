import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette
import "../../components/material"

Scope {
    id: root
    property var expandedGroups: ({})
    // Keep a local, immutable copy of each notification. Some web apps update a
    // single notification id for every new message, which otherwise replaces the
    // previous message in NotificationServer.trackedNotifications.
    property var notificationHistory: []
    property int nextHistoryId: 0

    function isExpanded(appName) {
        return !!expandedGroups[appName];
    }

    function toggleGroup(appName) {
        var copy = Object.assign({}, expandedGroups);
        copy[appName] = !copy[appName];
        expandedGroups = copy;
    }

    function buildGroups() {
        var list = notificationHistory;
        var groups = [];
        var index = {};
        // notificationHistory is newest first, so keep the newest item at the
        // front of every app group as well.
        for (var i = 0; i < list.length; i++) {
            var n = list[i];
            var key = n.appName || "Notifications";
            if (index[key] === undefined) {
                index[key] = groups.length;
                groups.push({
                    appName: key,
                    items: [n]
                });
            } else {
                groups[index[key]].items.push(n);
            }
        }
        return groups;
    }

    readonly property var groupedNotifications: buildGroups()
    property bool doNotDisturb: false
    property var toastNotification: null
    readonly property var rawNotifications: server.trackedNotifications.values
    readonly property var notifications: notificationHistory
    readonly property int count: notifications.length

    function scrub(text) {
        return (text || "").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"");
    }

    function notificationIcon(notification) {
        if (!notification)
            return "";
        // History records (they have a historyId) hold the image URL from
        // when they arrived. Quickshell's image://qsimage handles die with
        // the notification (or a reload), so take the live one's current
        // handle if it's still around, and otherwise fall back to the icon
        // instead of re-requesting a dead handle on every redraw.
        if (notification.historyId !== undefined) {
            var live = liveNotification(notification);
            if (live && live.image)
                return live.image;
            if (notification.image && String(notification.image).indexOf("image://qsimage") !== 0)
                return notification.image;
        } else if (notification.image) {
            return notification.image;
        }
        if (notification.appIcon)
            return Quickshell.iconPath(notification.appIcon, true);
        return "";
    }

    function remember(notification) {
        if (!notification)
            return;
        var records = notificationHistory.slice();
        // A replacement uses the same id. Preserve its old text, but make only
        // the newest record eligible to dismiss the live system notification.
        for (var i = 0; i < records.length; i++) {
            if (records[i].notificationId === notification.id)
                records[i].live = false;
        }

        records.unshift({
            historyId: ++nextHistoryId,
            notificationId: notification.id,
            appName: notification.appName || "Notifications",
            appIcon: notification.appIcon || "",
            image: notification.image || "",
            summary: notification.summary || "Notification",
            body: notification.body || "",
            urgency: notification.urgency,
            resident: notification.resident,
            receivedAt: Date.now(),
            live: true
        });

        // Bound the local history so a busy chat cannot grow the control center
        // without limit. Keep the most recent 20 messages per application.
        var perApp = {};
        records = records.filter(record => {
            var count = (perApp[record.appName] || 0) + 1;
            perApp[record.appName] = count;
            return count <= 20;
        }).slice(0, 120);
        notificationHistory = records;
    }

    function dismissRecord(record) {
        if (!record)
            return;
        notificationHistory = notificationHistory.filter(item => item.historyId !== record.historyId);
        var notification = liveNotification(record);
        if (notification)
            notification.dismiss();
    }

    // Keep live QObject values out of notificationHistory. History is passed to
    // ListView as a JS model; placing actions/QObjects in it can crash Qt while
    // it converts the nested notification-action sequence.
    function liveNotification(record) {
        if (!record || !record.live)
            return null;
        for (var i = 0; i < rawNotifications.length; i++) {
            if (rawNotifications[i].id === record.notificationId)
                return rawNotifications[i];
        }
        return null;
    }

    function clearAll() {
        toastTimer.stop();
        toastVisible = false;
        toastNotification = null;
        notificationHistory = [];

        var items = rawNotifications.slice();
        for (var i = 0; i < items.length; i++)
            items[i].dismiss();
    }

    function hideToast() {
        toastTimer.stop();
        toastVisible = false;
        toastNotification = null;
    }

    // A destroyed notification object reads back as null — never show an
    // empty popup for it.
    onToastNotificationChanged: if (!toastNotification)
        toastVisible = false

    function toggleDnd() {
        root.doNotDisturb = !root.doNotDisturb;
    }

    onDoNotDisturbChanged: {
        if (doNotDisturb)
            toastVisible = false;
    }

    function setDnd(enabled) {
        root.doNotDisturb = enabled;
        toastVisible = false;
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: true
        actionsSupported: true
        actionIconsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        inlineReplySupported: true

        onNotification: notification => {
            notification.tracked = true;
            root.remember(notification);
            root.toastNotification = notification;
            // If the sender closes or replaces it (or it expires) while the
            // popup is up, hide the popup instead of leaving an empty card.
            notification.closed.connect(() => {
                if (root.toastNotification === notification)
                    root.hideToast();
            });

            if (!root.doNotDisturb) {
                root.toastVisible = true;
                toastTimer.restart();
            }
        }
    }

    IpcHandler {
        target: "notifications"
        function clear(): void {
            root.clearAll();
        }
        function toggleDnd(): void {
            root.toggleDnd();
        }
        function setDnd(enabled: bool): void {
            root.setDnd(enabled);
        }
    }

    // The popup itself is drawn by the central notch (NotificationPeek in
    // components/overlay); this only decides when it's up. Hovering it
    // holds it open.
    property bool toastVisible: false

    function holdToast(held) {
        if (held)
            toastTimer.stop();
        else if (toastVisible)
            toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: root.toastNotification && root.toastNotification.urgency === NotificationUrgency.Critical ? 9000 : 4800
        onTriggered: root.toastVisible = false
    }
}
