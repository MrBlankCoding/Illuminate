import QtCore
import QtQuick
import QtQuick.Dialogs
import illuminate.ui

Item {
    id: root
    required property var activeWebView

    property var pendingPrintView: null
    property string pendingSavePdfPath: ""

    function printActivePage() {
        const wv = root.activeWebView;
        if (!wv)
            return;
        // Use Chromium's print dialog on every platform.
        wv.print();
    }

    function openSystemPrintFor(view) {
        if (view)
            view.print();
    }

    function savePdfActivePage() {
        requestSavePdf(root.activeWebView);
    }

    function sameLocalPath(a, b) {
        const strip = s => String(s)
            .replace(/^file:\/\/localhost/, "")
            .replace(/^file:\/\//, "")
            .replace(/^file:/, "");
        return strip(a) === strip(b);
    }

    function onPdfPrintingFinished(filePath, success) {
        if (root.pendingSavePdfPath !== ""
            && root.sameLocalPath(filePath, root.pendingSavePdfPath)) {
            root.pendingSavePdfPath = "";
            if (success)
                Logger.info("BrowserWindow", "Saved PDF to " + filePath);
            else
                Logger.error("BrowserWindow", "Save PDF failed: " + filePath);
        }
    }

    function toLocalPath(value) {
        const s = String(value);
        if (!s.startsWith("file:"))
            return s;
        let p = s.slice("file://".length);
        if (p.startsWith("localhost"))
            p = p.slice("localhost".length);
        if ((p.startsWith("/C:/") || p.startsWith("/c:/")) && p.length > 3)
            p = p.slice(1);
        return p;
    }

    function requestSavePdf(view) {
        if (!view)
            return;
        root.pendingPrintView = view;
        printFileDialog.currentFile = "file://" + suggestedSavePath();
        printFileDialog.open();
    }

    function suggestedSavePath() {
        let base = (Browser.activeTitle || "page").replace(/[^\w\- ]+/g, " ").trim() || "page";
        const downloads = root.toLocalPath(StandardPaths.writableLocation(StandardPaths.DownloadLocation));
        return downloads + "/" + base + ".pdf";
    }

    FileDialog {
        id: printFileDialog
        title: "Save PDF"
        fileMode: FileDialog.SaveFile
        nameFilters: ["PDF file (*.pdf)"]
        defaultSuffix: "pdf"
        onAccepted: {
            const view = root.pendingPrintView;
            const path = root.toLocalPath(printFileDialog.selectedFile);
            if (!view) {
                Logger.warning("BrowserWindow", "Save PDF: no tab to save");
                return;
            }
            root.pendingSavePdfPath = path;
            view.printToPdf(path);
        }
    }
}
