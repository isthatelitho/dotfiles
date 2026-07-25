import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PanelWindow {
    id: root

    readonly property string wallDir: Quickshell.env("HOME") + "/Pictures/walls"
    readonly property string tiledPrefix: wallDir + "/tiled/"
    readonly property string helperScript: Quickshell.env("HOME") + "/.config/niri/scripts/wallpaper-selector.sh"
    readonly property string logFile: Quickshell.env("HOME") + "/.cache/rofi-wallpaper/quickshell-apply.log"

    property string activePath: ""
    property string activeName: ""
    property string view: "normal"

    // Noctalia colors — regenerated automatically whenever the colorscheme
    // changes, see ~/.config/noctalia/templates/quickshell-colors.qml
    readonly property Colors colors: Colors {}

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    focusable: true
    color: colors.alpha(colors.mShadow, 0.95)

    Shortcut {
        sequence: "Escape"
        onActivated: Qt.quit()
    }

    Shortcut {
        sequence: "Alt+T"
        onActivated: root.toggleView()
    }

    function toggleView() {
        root.view = (root.view === "normal") ? "tiled" : "normal"
        root.filterModel(searchBox.text)
        viewToast.pop()
    }

    NumberAnimation {
        id: carouselScrollAnim
        target: carousel
        property: "contentX"
        duration: 320
        easing.type: Easing.OutCubic
    }

    function scrollCarousel(direction) {
        var maxX = Math.max(0, carousel.contentWidth - carousel.width)
        var step = carousel.width * 0.90
        var dest = Math.max(0, Math.min(carousel.contentX + direction * step, maxX))
        carouselScrollAnim.to = dest
        carouselScrollAnim.restart()
    }

    // Spawns a process completely detached from Quickshell's process lifecycle
    function applyWallpaper(path) {
        if (!path) return

        // Single-quote-escape both paths so filenames with spaces/quotes/apostrophes
        // don't break the command, and make sure the target dir for the log exists.
        function shQuote(s) {
            return "'" + s.replace(/'/g, "'\\''") + "'"
        }

        var cmd = "mkdir -p " + shQuote(root.logFile.substring(0, root.logFile.lastIndexOf("/")))
            + " && { echo \"---- $(date '+%F %T') ----\"; "
            + "bash " + shQuote(root.helperScript) + " " + shQuote(path) + "; "
            + "echo \"exit code: $?\"; } >> " + shQuote(root.logFile) + " 2>&1"

        Quickshell.execDetached(["bash", "-c", cmd])
    }

    Process {
        id: listProc
        command: ["find", root.wallDir, "-type", "f"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var files = text.trim().split("\n")
                wallModel.clear()
                for (var i = 0; i < files.length; i++) {
                    if (files[i] && files[i].match(/\.(jpg|jpeg|png|webp|gif|mp4|mkv|webm)$/i)) {
                        var filename = files[i].substring(files[i].lastIndexOf('/') + 1)
                        var tiled = files[i].indexOf(root.tiledPrefix) === 0
                        wallModel.append({ "path": files[i], "title": filename, "tiled": tiled })
                    }
                }
                root.filterModel("")
            }
        }
    }

    ListModel { id: wallModel }
    ListModel { id: filteredModel }

    function filterModel(query) {
        filteredModel.clear()
        for (var i = 0; i < wallModel.count; i++) {
            var item = wallModel.get(i)
            var matchesView = item.tiled === (root.view === "tiled")
            var matchesQuery = (query === "" || item.title.toLowerCase().indexOf(query.toLowerCase()) !== -1)
            if (matchesView && matchesQuery) {
                filteredModel.append(item)
            }
        }
        if (filteredModel.count > 0) {
            root.activePath = filteredModel.get(0).path
            root.activeName = filteredModel.get(0).title
        } else {
            root.activePath = ""
            root.activeName = ""
        }
    }

    Component.onCompleted: filterModel("")

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 36
        spacing: 20

        // --- HEADER BAR WITH PULSING ACCENT ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Rectangle {
                Layout.preferredWidth: 200
                Layout.preferredHeight: 46
                color: colors.alpha(colors.mSurface, 0.87)
                border.color: colors.mPrimary
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16

                    Text {
                        text: root.view === "tiled" ? "TILED" : "NORMAL"
                        color: colors.mPrimary
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Alt+T"
                        color: colors.alpha(colors.mOnSurfaceVariant, 0.55)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleView()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                color: colors.alpha(colors.mSurface, 0.6)
                border.color: colors.alpha(colors.mOutline, 0.8)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16

                    TextField {
                        id: searchBox
                        Layout.fillWidth: true
                        placeholderText: "Type to filter wallpapers..."
                        placeholderTextColor: colors.alpha(colors.mOnSurfaceVariant, 0.55)
                        color: colors.mOnSurface
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        background: null
                        focus: true

                        onTextChanged: root.filterModel(text)
                    }
                }
            }
        }

        // --- HERO DISPLAY WITH SOFT LIGHT SHEEN & NEON BORDER ---
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Downsampled hardware blur ambient aura
            Image {
                anchors.centerIn: parent
                width: heroFrame.width * 1.25
                height: heroFrame.height * 1.25
                source: root.activePath ? "file://" + root.activePath : ""
                fillMode: Image.PreserveAspectCrop
                opacity: 0.35
                smooth: true
                asynchronous: true

                sourceSize.width: 32
                sourceSize.height: 18
            }

            Rectangle {
                id: heroFrame
                anchors.centerIn: parent
                width: Math.min(parent.width * 0.75, parent.height * 16 / 9)
                height: width * 9 / 16
                color: colors.alpha(colors.mSurfaceVariant, 0.4)
                border.width: 2
                clip: true

                // Pulsing Border Color Animation — cycles through the M3 accent triad
                SequentialAnimation on border.color {
                    loops: Animation.Infinite
                    ColorAnimation { to: colors.mPrimary; duration: 2000 }
                    ColorAnimation { to: colors.mSecondary; duration: 2000 }
                    ColorAnimation { to: colors.mTertiary; duration: 2000 }
                }

                Image {
                    id: heroImg
                    anchors.fill: parent
                    anchors.margins: 4
                    source: root.activePath ? "file://" + root.activePath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true

                    sourceSize.width: 1280
                    sourceSize.height: 720

                    Behavior on source {
                        SequentialAnimation {
                            NumberAnimation { target: heroImg; property: "opacity"; to: 0.1; duration: 100 }
                            PropertyAction { target: heroImg; property: "source" }
                            NumberAnimation { target: heroImg; property: "opacity"; to: 1.0; duration: 250; easing.type: Easing.OutQuad }
                        }
                    }
                }

                // Subtle diagonal light sheen — a soft, blurred-edge band that
                // slowly sweeps across the preview every few seconds, then rests.
                Rectangle {
                    id: sheen
                    width: heroFrame.width * 0.35
                    height: heroFrame.height * 2
                    rotation: 20
                    x: -width
                    y: -heroFrame.height * 0.5
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: colors.alpha(colors.mOnSurface, 0.0) }
                        GradientStop { position: 0.5; color: colors.alpha(colors.mOnSurface, 0.08) }
                        GradientStop { position: 1.0; color: colors.alpha(colors.mOnSurface, 0.0) }
                    }

                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        PauseAnimation { duration: 3200 }
                        NumberAnimation {
                            to: heroFrame.width + sheen.width
                            duration: 1400
                            easing.type: Easing.InOutQuad
                        }
                        PropertyAction { value: -sheen.width }
                    }
                }

                // Active Info Banner Overlay
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 48
                    color: colors.alpha(colors.mSurface, 0.94)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14

                        Text {
                            text: "PREVIEW: " + root.activeName
                            color: colors.mOnSurface
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "[ CLICK TO APPLY ]"
                            color: colors.mPrimary
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }
                }
            }
        }

        // --- CAROUSEL WITH DIRECT MOUSE WHEEL SCROLLING ---
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 360

            ListView {
                id: carousel
                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: 16
                clip: false

                model: filteredModel

                delegate: WallpaperCard {
                    filePath: model.path
                    fileName: model.title
                    isActive: root.activePath === model.path
                    colors: root.colors

                    onHovered: {
                        root.activePath = model.path
                        root.activeName = model.title
                    }

                    onClicked: {
                        root.applyWallpaper(model.path)
                    }
                }

                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
            }

            // Transparent overlay dedicated to wheel scrolling. A WheelHandler
            // attached directly to the ListView can be starved of wheel events
            // by the hover-enabled MouseArea inside each WallpaperCard delegate,
            // so instead we use a plain MouseArea on top: acceptedButtons:
            // Qt.NoButton and hoverEnabled: false make it fully transparent to
            // clicks/hover (they pass straight through to the cards beneath),
            // while onWheel still reliably fires no matter what's underneath.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: false
                onWheel: (wheel) => {
                    var delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                    var maxX = Math.max(0, carousel.contentWidth - carousel.width)
                    carousel.contentX = Math.max(0, Math.min(carousel.contentX - delta, maxX))
                    wheel.accepted = true
                }
            }

            // Prev/next direction buttons, floating over the carousel edges.
            Rectangle {
                id: prevBtn
                width: 44
                height: 44
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                color: prevArea.containsMouse ? colors.alpha(colors.mSurface, 0.8) : colors.alpha(colors.mSurface, 0.54)
                border.color: colors.alpha(colors.mOutline, 0.8)
                border.width: 1
                z: 50

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -1
                    text: "‹"
                    color: colors.mOnSurface
                    font.pixelSize: 24
                    font.bold: true
                }

                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.scrollCarousel(-1)
                }
            }

            Rectangle {
                id: nextBtn
                width: 44
                height: 44
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                color: nextArea.containsMouse ? colors.alpha(colors.mSurface, 0.8) : colors.alpha(colors.mSurface, 0.54)
                border.color: colors.alpha(colors.mOutline, 0.8)
                border.width: 1
                z: 50

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 1
                    text: "›"
                    color: colors.mOnSurface
                    font.pixelSize: 24
                    font.bold: true
                }

                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.scrollCarousel(1)
                }
            }
        }
    }

    // --- BIG VIEW-SWITCH TOAST ---
    // Floats above everything, centered on screen. pop() jumps it in with a
    // spring, holds briefly, then fades/shrinks back out.
    Rectangle {
        id: viewToast
        anchors.centerIn: parent
        z: 1000
        width: toastCol.implicitWidth + 100
        height: toastCol.implicitHeight + 56
        radius: 0
        color: colors.alpha(colors.mSurface, 0.9)
        border.width: 2
        border.color: root.view === "tiled" ? colors.mSecondary : colors.mPrimary
        opacity: 0
        scale: 0.8

        Behavior on border.color { ColorAnimation { duration: 250 } }

        function pop() {
            hideTimer.stop()
            opacity = 1
            scale = 1
            hideTimer.start()
        }

        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }
        }

        Timer {
            id: hideTimer
            interval: 750
            onTriggered: {
                viewToast.opacity = 0
                viewToast.scale = 0.8
            }
        }

        Column {
            id: toastCol
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.view === "tiled" ? "TILED" : "NORMAL"
                color: colors.mOnSurface
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 34
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: filteredModel.count + (filteredModel.count === 1 ? " wallpaper" : " wallpapers")
                color: root.view === "tiled" ? colors.mSecondary : colors.mTertiary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
            }
        }
    }
}
