import QtQuick
import qs.Commons
import qs.Ui

// Bar button for the Quick Note panel. The panel itself lives in Panel.qml;
// this widget only owns the icon and forwards the open/close contract the
// shell uses for `omarchy-shell shell toggle momoledev.tot`.
BarWidget {
  id: root
  moduleName: "momoledev.tot"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.openFromHotkey() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    // Query string defeats the engine's component cache so a plugin
    // hot-reload picks up edits to Panel.qml too.
    source: Qt.resolvedUrl("Panel.qml") + "?v=" + Date.now()
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""  // nf-fa-sticky_note
    slotSize: Style.bar.statusSlot
    tooltipText: ""

    onPressed: function(b) {
      if (!panelLoader.item) return
      if (b === Qt.RightButton) panelLoader.item.openInEditor()
      else root.toggle()
    }
  }
}
