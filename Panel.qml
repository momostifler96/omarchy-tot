import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "I18n.js" as I18n

// Tot-style notes: ten colored tabs, each backed by a plain-text file in
// ~/.local/share/omarchy-tot/note-N.md. The current tab is shared through
// ~/.local/state/omarchy-tot/current so every monitor's bar instance (and the
// `tot-notes N` script) agrees on it.
Panel {
  id: root
  moduleName: "momoledev.tot"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property int noteCount: 10
  readonly property string home: Quickshell.env("HOME")
  readonly property string dataDir: home + "/.local/share/omarchy-tot"
  readonly property string stateDir: home + "/.local/state/omarchy-tot"
  readonly property string lang: I18n.resolve(setting("language", "en"), Qt.locale().name)
  function tr(key, n) { return I18n.tr(lang, key, n) }

  readonly property string syncBin: home + "/.local/bin/tot-sync"
  property var syncStatus: ({ state: "off", time: 0, message: "" })
  property real now: Date.now() / 1000
  readonly property string themeColorsPath: home + "/.local/state/omarchy/current/theme/colors.toml"

  property int currentTab: 0
  property var texts: ["", "", "", "", "", "", "", "", "", ""]
  property var lastWritten: ["", "", "", "", "", "", "", "", "", ""]
  property var cursorPositions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  property int pendingSaveTab: -1
  property bool settingEditor: false

  readonly property var fallbackPalette: [
    "#f38ba8", "#fab387", "#f9e2af", "#a6e3a1", "#94e2d5",
    "#89b4fa", "#cba6f7", "#f5c2e7", "#b4befe", "#9399b2"
  ]
  readonly property var paletteKeys: [
    "red", "orange", "yellow", "green", "cyan",
    "blue", "magenta", "brown", "light_foreground", "muted"
  ]
  property var tabPalette: fallbackPalette

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar && bar.fontFamily ? bar.fontFamily : Style.font.family
  readonly property color tabColor: tabPalette[currentTab] || Color.accent

  function notePath(i) { return dataDir + "/note-" + (i + 1) + ".md" }
  function tabLabel(i) { return i === 9 ? "0" : String(i + 1) }

  // ---- Lifecycle ----------------------------------------------------------

  function openFromHotkey() {
    root.controller.show()
    stateFile.reload()
    Qt.callLater(function() {
      if (!root.opened) return
      root.setCenterHoverRevealSuppressed(true)
      editor.forceActiveFocus()
    })
  }

  function open() { openFromHotkey() }

  function close() {
    flushSave()
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
  }

  // ---- Tabs ---------------------------------------------------------------

  function selectTab(i, persist) {
    i = ((i % noteCount) + noteCount) % noteCount
    if (i === currentTab && editor.text === texts[i]) return
    flushSave()
    var positions = cursorPositions.slice()
    positions[currentTab] = editor.cursorPosition
    cursorPositions = positions
    currentTab = i
    loadEditor()
    if (persist !== false) stateFile.setText(String(i + 1) + "\n")
  }

  function loadEditor() {
    settingEditor = true
    editor.text = texts[currentTab]
    editor.cursorPosition = Math.min(cursorPositions[currentTab] || 0, editor.length)
    settingEditor = false
  }

  // ---- Persistence --------------------------------------------------------

  function onEditorEdited() {
    if (settingEditor) return
    var next = texts.slice()
    next[currentTab] = editor.text
    texts = next
    pendingSaveTab = currentTab
    saveTimer.restart()
  }

  function flushSave() {
    saveTimer.stop()
    if (pendingSaveTab < 0) return
    var i = pendingSaveTab
    pendingSaveTab = -1
    var written = lastWritten.slice()
    written[i] = texts[i]
    lastWritten = written
    var view = noteFiles.objectAt(i)
    if (view) view.setText(texts[i])
  }

  function noteLoaded(i, content) {
    // Our own write echoing back through the watcher: nothing new.
    if (content === lastWritten[i]) return
    // Unsaved local typing wins over a concurrent external change.
    if (pendingSaveTab === i) return
    var written = lastWritten.slice()
    written[i] = content
    lastWritten = written
    var next = texts.slice()
    next[i] = content
    texts = next
    if (i === currentTab && editor.text !== content) {
      var pos = editor.cursorPosition
      settingEditor = true
      editor.text = content
      editor.cursorPosition = Math.min(pos, editor.length)
      settingEditor = false
    }
  }

  // ---- Actions ------------------------------------------------------------

  function copyNote() {
    Quickshell.clipboardText = texts[currentTab]
  }

  function openInEditor() {
    flushSave()
    root.close()
    Quickshell.execDetached(["omarchy-launch-editor", notePath(currentTab)])
  }

  // Cloud sync (tot-sync + rclone). Without a configured cloud, the shortcut
  // opens the setup wizard in a terminal instead.
  function syncNow() {
    flushSave()
    if (syncStatus.state === "off") {
      root.close()
      Quickshell.execDetached(["omarchy-launch-tui", "--app-id=org.omarchy.tot-sync", syncBin, "setup"])
      return
    }
    syncStatus = { state: "syncing", time: syncStatus.time, message: "" }
    Quickshell.execDetached([syncBin, "sync"])
  }

  function backupNow() {
    flushSave()
    Quickshell.execDetached([syncBin, "backup"])
  }

  function ago(t) {
    var d = Math.max(0, Math.round(now - t))
    if (d < 60) return tr("justNow")
    if (d < 3600) return tr("minAgo", Math.floor(d / 60))
    if (d < 86400) return tr("hourAgo", Math.floor(d / 3600))
    return tr("dayAgo", Math.floor(d / 86400))
  }

  readonly property string syncLabel: {
    var st = syncStatus.state
    if (st === "ok") return "\uf0c2  " + ago(syncStatus.time)
    if (st === "syncing") return "\uf021  " + tr("syncing")
    if (st === "error") return "\uf071  " + tr("syncError")
    return "\uf0c2  " + tr("cloudOff")
  }

  function digitIndex(event) {
    // Physical number row (evdev KEY_1..KEY_0 + 8), so AZERTY works too.
    var code = event.nativeScanCode
    if (code >= 10 && code <= 19) return code - 10
    if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) return event.key - Qt.Key_1
    if (event.key === Qt.Key_0) return 9
    return -1
  }

  function handleKey(event) {
    var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
    var alt = (event.modifiers & Qt.AltModifier) !== 0
    var shift = (event.modifiers & Qt.ShiftModifier) !== 0

    if (event.key === Qt.Key_Escape) { root.close(); return true }

    if (ctrl || alt) {
      var idx = digitIndex(event)
      if (idx >= 0) { selectTab(idx); return true }
    }
    if (ctrl && (event.key === Qt.Key_Tab || event.key === Qt.Key_PageDown)) {
      selectTab(currentTab + (shift ? -1 : 1)); return true
    }
    if (ctrl && (event.key === Qt.Key_Backtab || event.key === Qt.Key_PageUp)) {
      selectTab(currentTab - 1); return true
    }
    if (alt && (event.key === Qt.Key_Right || event.key === Qt.Key_Left)) {
      selectTab(currentTab + (event.key === Qt.Key_Right ? 1 : -1)); return true
    }
    if (ctrl && shift && event.key === Qt.Key_C) { copyNote(); return true }
    if (ctrl && event.key === Qt.Key_E) { openInEditor(); return true }
    if (ctrl && shift && event.key === Qt.Key_S) { syncNow(); return true }
    if (ctrl && event.key === Qt.Key_S) { flushSave(); return true }
    if (ctrl && event.key === Qt.Key_B) { backupNow(); return true }
    return false
  }

  // ---- Files --------------------------------------------------------------

  Instantiator {
    id: noteFiles
    model: root.noteCount
    delegate: FileView {
      required property int index
      path: root.notePath(index)
      watchChanges: true
      atomicWrites: true
      printErrors: false
      onFileChanged: reload()
      onLoaded: root.noteLoaded(index, text())
      // A deleted note file reads as an empty note.
      onLoadFailed: root.noteLoaded(index, "")
    }
  }

  FileView {
    id: stateFile
    path: root.stateDir + "/current"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var n = parseInt(String(text()).trim(), 10)
      if (n >= 1 && n <= root.noteCount && n - 1 !== root.currentTab) root.selectTab(n - 1, false)
    }
  }

  FileView {
    id: themeColors
    path: root.themeColorsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var values = {}
      var lines = String(text()).split("\n")
      for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(/^\s*([a-z_]+)\s*=\s*"(#[0-9a-fA-F]{6,8})"/)
        if (m) values[m[1]] = m[2]
      }
      var out = []
      for (var j = 0; j < root.paletteKeys.length; j++)
        out.push(values[root.paletteKeys[j]] || root.fallbackPalette[j])
      root.tabPalette = out
    }
  }

  // Theme switches repoint the current-theme symlink; the accent change is
  // the reliable signal to re-read the palette.
  Connections {
    target: Color
    function onAccentChanged() { themeColors.reload() }
  }

  FileView {
    id: syncFile
    path: root.stateDir + "/sync.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.syncStatus = JSON.parse(text()) } catch (e) {}
    }
  }

  Timer {
    interval: 30000
    repeat: true
    running: root.opened
    triggeredOnStart: true
    onTriggered: root.now = Date.now() / 1000
  }

  Process {
    running: true
    command: ["mkdir", "-p", root.dataDir, root.stateDir]
  }

  Timer {
    id: saveTimer
    interval: 400
    onTriggered: root.flushSave()
  }

  // ---- UI -----------------------------------------------------------------

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: editor
    contentWidth: panel.fittedContentWidth(Style.space(root.setting("width", 560)))
    contentHeight: panel.fittedContentHeight(Style.space(root.setting("height", 440)))

    Column {
      id: layout
      anchors.fill: parent
      spacing: Style.space(10)

      // Tab dots
      Item {
        id: header
        width: parent.width
        height: Style.space(30)

        Row {
          id: dots
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Repeater {
            model: root.noteCount

            Item {
              id: dot
              required property int index
              readonly property bool active: index === root.currentTab
              readonly property bool filled: String(root.texts[index] || "").trim() !== ""
              readonly property color tint: root.tabPalette[index] || root.fg
              width: Style.space(24)
              height: Style.space(30)

              Rectangle {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -Style.space(4)
                width: dot.active ? Style.space(18) : Style.space(14)
                height: width
                radius: width / 2
                color: dot.filled || dot.active ? dot.tint : "transparent"
                border.width: Math.max(1, Style.space(2))
                border.color: dot.tint
                opacity: dot.active || dotMouse.containsMouse ? 1.0 : 0.7
                Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -Style.space(2)
                text: root.tabLabel(dot.index)
                color: dot.active ? dot.tint : Qt.darker(root.fg, 1.8)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                id: dotMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.selectTab(dot.index)
                  editor.forceActiveFocus()
                }
              }
            }
          }
        }

        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.tr("note") + " " + root.tabLabel(root.currentTab)
          color: root.tabColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }
      }

      Rectangle {
        width: parent.width
        height: Math.max(1, Style.space(2))
        radius: height / 2
        color: root.tabColor
        opacity: 0.6
      }

      // Editor
      Flickable {
        id: flick
        width: parent.width
        height: parent.height - header.height - footer.height - Style.space(2) - layout.spacing * 3
        contentWidth: width
        contentHeight: editor.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        function ensureVisible(r) {
          if (contentY >= r.y) contentY = r.y
          else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height
        }

        TextEdit {
          id: editor
          width: flick.width
          height: Math.max(implicitHeight, flick.height)
          wrapMode: TextEdit.Wrap
          textFormat: TextEdit.PlainText
          selectByMouse: true
          persistentSelection: true
          color: root.fg
          selectionColor: Qt.rgba(root.tabColor.r, root.tabColor.g, root.tabColor.b, 0.45)
          selectedTextColor: root.fg
          font.family: root.fontFamily
          font.pixelSize: root.setting("fontSize", 14)
          tabStopDistance: font.pixelSize * 2
          onTextChanged: root.onEditorEdited()
          onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)

          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if (root.handleKey(event)) event.accepted = true
          }

          Text {
            visible: editor.length === 0
            text: root.tr("placeholder")
            color: Qt.darker(root.fg, 2.0)
            font: editor.font
          }
        }
      }

      // Footer
      Item {
        id: footer
        width: parent.width
        height: Style.space(16)

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - counts.width - syncText.width - Style.space(24)
          elide: Text.ElideRight
          text: root.tr("hints")
          color: Qt.darker(root.fg, 1.8)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          id: syncText
          anchors.right: counts.left
          anchors.rightMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          text: root.syncLabel
          color: root.syncStatus.state === "error" ? Color.urgent
            : syncMouse.containsMouse ? root.fg : Qt.darker(root.fg, 1.5)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption

          MouseArea {
            id: syncMouse
            anchors.fill: parent
            anchors.margins: -Style.space(4)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.syncNow()
          }
        }

        Text {
          id: counts
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          readonly property string body: root.texts[root.currentTab] || ""
          readonly property int words: body.trim() === "" ? 0 : body.trim().split(/\s+/).length
          text: I18n.count(root.lang, "word", "words", words) + " · " + I18n.count(root.lang, "char", "chars", body.length)
          color: Qt.darker(root.fg, 1.5)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
