pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Sentaku.Config
import Sentaku.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: GlobalConfig.services.smartScheme ? [] : ["--no-smart"]
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")
    readonly property string hyprlockConfPath: `${Quickshell.env("XDG_CONFIG_HOME") || `${Paths.home}/.config`}/hypr/hyprlock.conf`

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property bool previewColourLock
    property bool pendingPreviewClear

    // Persisted next to the wallpaper path; mirrors the current wallpaper
    // into the hyprlock config so the lock screen shows the same wallpaper.
    property bool hyprlockSync: false

    function getCategoryFor(w: FileSystemEntry): string {
        let category = w.parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category;
    }

    function setRandom(): void {
        const walls = list;
        if (walls.length > 0)
            setWallpaper(walls[Math.floor(Math.random() * walls.length)].path);
    }

    // Set and persist the wallpaper. The WallpaperBackground window follows
    // `current` (bound to `actualCurrent`), so no external process is needed.
    function setWallpaper(path: string): void {
        actualCurrent = path;
        stateFile.setText(path);
        applyHyprlockSync();
    }

    // Hyprlock reads its config only when it starts, so updating the
    // background path here makes the next lock screen show the shell's
    // current wallpaper. Rewrites the first non-commented `path` key of the
    // first `background { }` block, leaving the rest of the config intact.
    function applyHyprlockSync(): void {
        if (!hyprlockSync || !actualCurrent)
            return;
        const conf = hyprlockConf.text();
        if (!conf || conf.length === 0)
            return;

        const bg = /background\s*\{[\s\S]*?\}/.exec(conf);
        if (!bg)
            return;
        const block = bg[0];
        const key = /^[ \t]*path[ \t]*=[^\n]*/m.exec(block);
        const indent = key ? key[0].match(/^[ \t]*/)[0] : "  ";
        const pathLine = `${indent}path = ${actualCurrent}`;
        const updated = key
            ? block.slice(0, key.index) + pathLine + block.slice(key.index + key[0].length)
            : block.replace("}", `\n${pathLine}\n}`);
        hyprlockConf.setText(conf.slice(0, bg.index) + updated + conf.slice(bg.index + block.length));
    }

    onHyprlockSyncChanged: {
        syncFile.setText(hyprlockSync ? "true" : "false");
        applyHyprlockSync();
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;

        if (Colours.scheme === "dynamic")
            getPreviewColoursProc.running = true;
    }

    function stopPreview(): void {
        showPreview = false;
        if (previewColourLock)
            pendingPreviewClear = true;
        else
            Colours.showPreview = false;
    }

    onPreviewColourLockChanged: {
        if (!previewColourLock && pendingPreviewClear)
            Colours.showPreview = false;
    }

    list: wallpapers.entries
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        target: "wallpaper"
    }

    FileView {
        id: stateFile

        path: root.currentNamePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        // Restored on every shell start: WallpaperBackground follows
        // `current`, so the saved wallpaper comes back after a reboot.
        onLoaded: {
            let wall = text().trim();
            if (!wall)
                wall = root.fallback;
            root.actualCurrent = wall;
            root.previewColourLock = false;
            root.applyHyprlockSync();
        }
        onLoadFailed: {
            root.actualCurrent = root.fallback;
            root.previewColourLock = false;
            root.applyHyprlockSync();
        }
    }

    FileView {
        id: syncFile

        path: `${Paths.state}/wallpaper/hyprlock-sync`
        printErrors: false
        onLoaded: root.hyprlockSync = text().trim() === "true"
        onLoadFailed: root.hyprlockSync = false
    }

    FileView {
        id: hyprlockConf

        path: root.hyprlockConfPath
        printErrors: false
        // Whichever of the state file, sync flag or config loads last wins:
        // each onLoaded re-runs the sync once all pieces are in place.
        onLoaded: root.applyHyprlockSync()
        onLoadFailed: {}
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Images | FileSystemModel.Videos
    }

    Process {
        id: getPreviewColoursProc

        command: ["sentaku", "wallpaper", "-p", root.previewPath, ...root.smartArg]
        stdout: StdioCollector {
            onStreamFinished: {
                // The sentaku CLI may be absent; ignore empty/invalid output instead of crashing
                // JSON.parse in Colours.load().
                if (text && text.trimStart().startsWith("{")) {
                    Colours.load(text, true);
                    Colours.showPreview = true;
                }
            }
        }
    }
}
