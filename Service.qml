import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons

// While Hyprland's "arrange" submap (hypr/arrange.lua) is active, outline the
// active window and show a card with the keys next to it. The overlay is
// click-through and never takes keyboard focus, so the keys keep going to
// Hyprland. Geometry is polled from hyprctl while the mode is on, since
// Hyprland reports no event when a window is resized.
Item {
  id: root
  width: 0
  height: 0
  visible: false

  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  property bool active: false
  // Active window and its monitor, from hyprctl.
  property var win: null
  property var mon: null

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

  // Window rectangle in the monitor's own logical coordinates.
  readonly property rect frame: {
    if (!win || !mon || !win.at || !win.size) return Qt.rect(0, 0, 0, 0)
    return Qt.rect(win.at[0] - mon.x, win.at[1] - mon.y, win.size[0], win.size[1])
  }

  readonly property var targetScreen: {
    if (!mon) return null
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++)
      if (screens[i].name === mon.name) return screens[i]
    return null
  }

  function refresh() {
    if (!probe.running) probe.running = true
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "submap") {
        root.active = event.data === "arrange"
        if (root.active) root.refresh()
        else { root.win = null; root.mon = null }
      } else if (root.active && (event.name === "activewindowv2" || event.name === "movewindowv2"
                 || event.name === "changefloatingmode" || event.name === "fullscreen")) {
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

  Process {
    id: probe
    command: ["bash", "-c", "hyprctl -j activewindow | jq -c . ; hyprctl -j monitors | jq -c ."]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = text.split("\n")
        try {
          var w = JSON.parse(lines[0])
          var monitors = JSON.parse(lines[1])
          if (!w || !w.address) { root.win = null; return }
          for (var i = 0; i < monitors.length; i++) {
            if (monitors[i].id === w.monitor) {
              root.mon = monitors[i]
              break
            }
          }
          root.win = w
        } catch (e) {
          root.win = null
        }
      }
    }
  }

  PanelWindow {
    id: overlay
    visible: root.active && root.targetScreen !== null
    screen: root.targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "arrange-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {}

    // Outline around the active window.
    Rectangle {
      id: outline
      visible: root.win !== null
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

    // Key card, centred on the window and kept on screen.
    Rectangle {
      id: card
      readonly property real pad: Style.space(16)
      width: grid.implicitWidth + pad * 2
      height: header.implicitHeight + grid.implicitHeight + pad * 2 + Style.space(10)
      x: Math.max(8, Math.min(overlay.width - width - 8, root.frame.x + (root.frame.width - width) / 2))
      y: Math.max(8, Math.min(overlay.height - height - 8, root.frame.y + (root.frame.height - height) / 2))
      color: Color.background
      opacity: 0.96
      border.color: Color.accent
      border.width: 1
      radius: Style.cornerRadius

      Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

      Column {
        anchors.fill: parent
        anchors.margins: card.pad
        spacing: Style.space(10)

        Row {
          id: header
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
            text: root.win ? (root.win.floating ? "floating · " : "tiled · ") + (root.win.class || "") : "no window"
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
          columnSpacing: Style.space(12)
          rowSpacing: Style.space(6)

          Repeater {
            model: root.keys
            delegate: Item {
              required property var modelData
              required property int index
              implicitWidth: keyCap.implicitWidth + Style.space(8) + label.implicitWidth
              implicitHeight: Math.max(keyCap.implicitHeight, label.implicitHeight)

              Rectangle {
                id: keyCap
                implicitWidth: Math.max(keyText.implicitWidth + Style.space(10), Style.space(22))
                implicitHeight: keyText.implicitHeight + Style.space(4)
                width: implicitWidth
                height: implicitHeight
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
                id: label
                anchors.left: keyCap.right
                anchors.leftMargin: Style.space(8)
                anchors.verticalCenter: keyCap.verticalCenter
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
