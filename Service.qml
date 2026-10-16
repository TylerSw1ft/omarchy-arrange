import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons

// The visible half of Arrange. hypr/arrange.lua turns Super+A into a
// Hyprland submap called "arrange"; while it is active, this service outlines
// the active window and shows a card with the keys on top of it.
//
// The overlay is click-through and never takes keyboard focus, so every key
// still goes to Hyprland. Hyprland sends no event when a window is resized,
// so while the mode is on the window's geometry is refreshed over Hyprland's
// IPC a few times a second; when it is off, nothing runs.
Item {
  id: root
  width: 0
  height: 0
  visible: false

  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  readonly property string submap: "arrange"
  property bool active: false

  // Keys shown on the card, in reading order (two columns).
  readonly property var keys: [
    { key: "← → ↑ ↓", label: "Move" },
    { key: "⇧ + arrows", label: "Push edge" },
    { key: "T", label: "Float / tile" },
    { key: "F", label: "Full screen" },
    { key: "M", label: "Maximise" },
    { key: "S", label: "Switch split" },
    { key: "C", label: "Centre" },
    { key: "1 – 9", label: "To workspace" },
    { key: "Tab", label: "Next window" },
    { key: "Esc", label: "Done" }
  ]

  readonly property var toplevel: Hyprland.activeToplevel
  readonly property var win: toplevel && toplevel.lastIpcObject && toplevel.lastIpcObject.at
    ? toplevel.lastIpcObject : null
  readonly property var monitor: toplevel && toplevel.monitor ? toplevel.monitor : Hyprland.focusedMonitor
  readonly property var monitorIpc: monitor && monitor.lastIpcObject ? monitor.lastIpcObject : null

  readonly property var targetScreen: {
    var name = monitor ? monitor.name : ""
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++)
      if (screens[i].name === name) return screens[i]
    return screens.length > 0 ? screens[0] : null
  }

  // The active window's rectangle in its monitor's logical coordinates, or
  // an empty rect when there's no window to arrange.
  readonly property rect frame: {
    if (!win || !monitorIpc) return Qt.rect(0, 0, 0, 0)
    return Qt.rect(win.at[0] - monitorIpc.x, win.at[1] - monitorIpc.y, win.size[0], win.size[1])
  }
  readonly property bool hasWindow: frame.width > 0 && frame.height > 0

  function refresh() {
    Hyprland.refreshToplevels()
    Hyprland.refreshMonitors()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "submap") {
        root.active = event.data === root.submap
        if (root.active) root.refresh()
      } else if (root.active) {
        root.refresh()
      }
    }
  }

  Timer {
    interval: 120
    repeat: true
    running: root.active
    onTriggered: root.refresh()
  }

  PanelWindow {
    id: overlay
    // Kept mapped while fading out, so the card doesn't vanish abruptly.
    visible: root.targetScreen !== null && (root.active || content.opacity > 0)
    screen: root.targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "arrange-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {}

    Item {
      id: content
      anchors.fill: parent
      opacity: root.active ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

      // Outline around the active window.
      Rectangle {
        visible: root.hasWindow
        x: root.frame.x - 4
        y: root.frame.y - 4
        width: root.frame.width + 8
        height: root.frame.height + 8
        color: "transparent"
        border.color: Color.accent
        border.width: 3
        radius: Style.cornerRadius + 4

        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      }

      // Key card: centred on the window (or the screen), kept on screen.
      Rectangle {
        id: card
        readonly property real pad: Style.space(16)
        readonly property real centreX: root.hasWindow ? root.frame.x + root.frame.width / 2 : overlay.width / 2
        readonly property real centreY: root.hasWindow ? root.frame.y + root.frame.height / 2 : overlay.height / 2

        width: column.implicitWidth + pad * 2
        height: column.implicitHeight + pad * 2
        x: Math.max(8, Math.min(overlay.width - width - 8, centreX - width / 2))
        y: Math.max(8, Math.min(overlay.height - height - 8, centreY - height / 2))
        color: Color.background
        border.color: Color.accent
        border.width: 1
        radius: Style.cornerRadius

        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Column {
          id: column
          x: card.pad
          y: card.pad
          spacing: Style.space(12)

          Row {
            spacing: Style.space(8)
            Text {
              textFormat: Text.PlainText
              text: "ARRANGE"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.5
            }
            Text {
              textFormat: Text.PlainText
              text: !root.win ? "no window"
                : (root.win.floating ? "floating" : "tiled") + (root.win.class ? " · " + root.win.class : "")
              color: Color.foreground
              opacity: 0.6
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: Math.max(0, grid.implicitWidth - x)
            }
          }

          Grid {
            id: grid
            columns: 2
            columnSpacing: Style.space(18)
            rowSpacing: Style.space(7)

            Repeater {
              model: root.keys
              delegate: Row {
                required property var modelData
                spacing: Style.space(8)

                Rectangle {
                  width: Math.max(keyText.implicitWidth + Style.space(10), Style.space(22))
                  height: keyText.implicitHeight + Style.space(4)
                  radius: 4
                  color: "transparent"
                  border.color: Color.foreground
                  border.width: 1
                  opacity: 0.85
                  Text {
                    id: keyText
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: modelData.key
                    color: Color.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                  }
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: modelData.label
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
          }
        }
      }
    }
  }
}
