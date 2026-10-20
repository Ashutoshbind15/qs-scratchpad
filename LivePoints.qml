import QtQuick
import QtWebEngine
import QtWebChannel
import Quickshell
import ScratchpadWeb

FocusScope {
    id: panel
    required property var colors
    property var entries: []
    property var shortcuts: []
    property int documentId: 0
    property int currentPoint: 0
    property bool showControls: true
    property bool loaded: false
    property bool focusPending: false
    property bool endPending: false
    property bool editDiagramPending: false
    property int lastEditId: 0
    readonly property var browser: webLoader.item
    signal pointEdited(int index, string text)
    signal pointFocused(int index)
    signal actionRequested(string action)
    signal removeRequested(int index)
    signal moveRequested(int index, int offset)
    signal diagramInserted(string text)

    function addDiagram() {
        if (!loaded) return;
        webLoader.forceActiveFocus();
        browser.runJavaScript("window.scratchpad.addDiagram()");
    }
    function editDiagram() {
        editDiagramPending = true;
        focusContent();
    }

    function focusContent() {
        focusPending = true;
        webLoader.forceActiveFocus();
        sync.restart();
    }
    function ensureCursorVisible() {
        if (loaded) browser.runJavaScript("window.scratchpad?.ensureCursorVisible()");
    }
    function focusEnd() {
        endPending = true;
        focusContent();
    }
    function sendState() {
        if (!loaded) return;
        bridge.stateChanged(JSON.stringify({
            documentId, entries, currentPoint, showControls, shortcuts, lastEditId,
            focus: focusPending, end: endPending, editDiagram: editDiagramPending,
            palette: {
                background: String(colors.background), surface: String(colors.surface),
                foreground: String(colors.foreground), accent: String(colors.accent),
                border: String(colors.border), muted: String(colors.muted),
                code: String(colors.codeBackground), selection: String(colors.textSelection),
                selectedText: String(colors.selectedText), fontSize: colors.fontSize
            }
        }));
        focusPending = false;
        endPending = false;
        editDiagramPending = false;
    }
    onEntriesChanged: sync.restart()
    onCurrentPointChanged: sync.restart()
    onDocumentIdChanged: { lastEditId = 0; editDiagramPending = false; sync.restart(); }
    onShowControlsChanged: sync.restart()
    Connections {
        target: panel.colors
        function onValuesChanged() { sync.restart(); }
        function onFontSizeChanged() { sync.restart(); }
    }
    Timer { id: sync; interval: 0; onTriggered: panel.sendState() }
    WebChannel {
        id: channel
        registeredObjects: [bridge]
    }
    QtObject {
        id: bridge
        WebChannel.id: "scratchpad"
        signal stateChanged(string state)
        function receive(raw: string): void {
            const message = JSON.parse(raw);
            if (message.type === "ready") {
                panel.loaded = true;
                panel.sendState();
                return;
            }
            if (message.documentId !== panel.documentId) return;
            const index = message.id === undefined ? message.index
                : panel.entries.findIndex(entry => entry.id === message.id);
            if (["input", "focus", "remove", "move"].includes(message.type) && (index < 0 || index >= panel.entries.length)) return;
            switch (message.type) {
            case "input":
                panel.lastEditId = message.editId;
                panel.pointEdited(index, message.text);
                break;
            case "focus": panel.pointFocused(index); break;
            case "action": panel.actionRequested(message.action); break;
            case "remove": panel.removeRequested(index); break;
            case "move": panel.moveRequested(index, message.offset); break;
            case "insertDiagram": panel.diagramInserted(message.text); break;
            case "link":
                if (/^(https?:|mailto:)/i.test(message.url)) Qt.openUrlExternally(message.url);
                break;
            }
        }
    }
    // Creating a view with an unpatched program name aborts the whole process
    // (see native/plugin.cpp), so a module built for another Qt shows a notice.
    Loader {
        id: webLoader
        anchors.fill: parent
        focus: true
        active: WebSupport.available
        sourceComponent: WebEngineView {
            focus: true
            url: "file://" + Quickshell.shellPath("editor/index.html")
            backgroundColor: panel.colors.background
            webChannel: channel
            settings.localContentCanAccessRemoteUrls: false
            settings.javascriptCanAccessClipboard: true
            onNavigationRequested: request => {
                if (String(request.url).split("#")[0] !== "file://" + Quickshell.shellPath("editor/index.html"))
                    request.action = WebEngineView.IgnoreRequest;
            }
            onJavaScriptConsoleMessage: (level, message) => {
                if (level === WebEngineView.ErrorMessageLevel) console.warn("Markdown editor:", message);
            }
            // A killed or crashed renderer leaves a blank view. The reloaded
            // page asks for the current points again; only unsent keys are lost.
            onRenderProcessTerminated: (status, exitCode) => {
                console.warn("Markdown editor renderer ended (status " + status + ", code " + exitCode + "); reloading");
                panel.loaded = false;
                Qt.callLater(() => { if (webLoader.item) webLoader.item.reload(); });
            }
        }
    }
    Text {
        anchors.fill: parent
        visible: !WebSupport.available
        text: "The Markdown editor was built for a different Qt version. Run "
              + Quickshell.shellPath("toggle") + " restart to rebuild it."
        color: panel.colors.muted
        font.pixelSize: panel.colors.px(13)
        wrapMode: Text.Wrap
    }
}
