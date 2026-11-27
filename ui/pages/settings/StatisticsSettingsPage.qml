pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import illuminate.ui

SettingsPage {
    id: root
    heading: "Statistics"
    subtitle: "Resource usage, browser memory footprint, and disk cache limits."

    property real totalMemory: 0
    property real mainProcessMemory: 0
    property real rendererMemory: 0
    property real historyBytes: 0
    property real diskCacheBytes: 0

    function formatBytes(bytes) {
        if (bytes <= 0)
            return "0 MB";
        const mb = bytes / (1024 * 1024);
        if (mb >= 1024)
            return (mb / 1024).toFixed(2) + " GB";
        if (mb < 1)
            return (bytes / 1024).toFixed(1) + " KB";
        return mb.toFixed(mb >= 100 ? 0 : 1) + " MB";
    }

    function refreshStats() {
        const snap = MemoryMonitor.snapshot();
        root.totalMemory = snap.total || 0;
        let mainBytes = 0;
        let rendBytes = 0;
        const procs = snap.processes || [];
        for (let i = 0; i < procs.length; ++i) {
            const p = procs[i];
            if (p.self)
                mainBytes += p.bytes;
            else
                rendBytes += p.bytes;
        }
        root.mainProcessMemory = mainBytes;
        root.rendererMemory = rendBytes;
        root.historyBytes = MemoryMonitor.historySizeBytes();
        root.diskCacheBytes = MemoryMonitor.diskCacheSizeBytes();
    }

    Component.onCompleted: root.refreshStats()

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.refreshStats()
    }

    SectionHeader {
        text: "Memory footprint"
    }

    SettingsCard {
        SettingItem {
            topDivider: false
            title: "Total browser memory"
            description: "Total physical memory in use across all browser processes."

            Text {
                text: root.formatBytes(root.totalMemory)
                color: Theme.text
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeM; weight: Font.Medium }
            }
        }

        SettingItem {
            title: "Main process"
            description: "Memory footprint of the browser application window and UI."

            Text {
                text: root.formatBytes(root.mainProcessMemory)
                color: Theme.textMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeM }
            }
        }

        SettingItem {
            title: "Web tabs & renderers"
            description: "Memory consumed by active web pages, backgrounds and extensions."

            Text {
                text: root.formatBytes(root.rendererMemory)
                color: Theme.textMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeM }
            }
        }
    }

    SectionHeader {
        Layout.topMargin: 12
        text: "Storage & cache"
    }

    SettingsCard {
        SettingItem {
            topDivider: false
            title: "History memory & disk usage"
            description: "Storage consumed by browsing history databases across all spaces."

            Text {
                text: root.formatBytes(root.historyBytes)
                color: Theme.text
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeM; weight: Font.Medium }
            }
        }

        SettingItem {
            title: "Current disk cache"
            description: "Local storage used for cached web documents, images and assets."

            Text {
                text: root.formatBytes(root.diskCacheBytes)
                color: Theme.textMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSizeM }
            }
        }

        SettingItem {
            title: "Max disk cache size"
            description: "Upper limit on local disk cache. Changes take effect on browser restart."

            SettingCombo {
                id: cacheSizeCombo
                implicitWidth: 170
                model: [
                    { name: "Auto (" + SystemInfo.httpCacheLimitMB + " MB)", value: 0 },
                    { name: "256 MB", value: 256 },
                    { name: "512 MB", value: 512 },
                    { name: "1 GB", value: 1024 },
                    { name: "2 GB", value: 2048 },
                    { name: "4 GB", value: 4096 },
                    { name: "8 GB", value: 8192 }
                ]
                textRole: "name"
                valueRole: "value"
                value: Prefs.maxDiskCacheSize
                onActivated: Prefs.maxDiskCacheSize = cacheSizeCombo.currentValue
            }
        }
    }

    Footnote {
        Layout.topMargin: 4
        text: "Physical memory and storage footprints are updated live."
    }
}
