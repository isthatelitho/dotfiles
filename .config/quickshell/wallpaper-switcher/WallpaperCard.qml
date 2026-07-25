import QtQuick
import QtQuick.Controls

Item {
    id: card

    property string filePath: ""
    property string fileName: ""
    property bool isActive: false
    // Passed down from shell.qml's root.colors (Noctalia-generated palette)
    property var colors: null
    signal clicked()
    signal hovered()

    width: isActive ? 220 : 125
    height: 350

    // Elastic Spring Scale & Width Animations
    Behavior on width {
        NumberAnimation {
            duration: 350
            easing.type: Easing.OutBack
            easing.overshoot: 1.5
        }
    }

    // Dynamic Skew Angle Transition
    transform: Rotation {
        origin.x: card.width / 2
        origin.y: card.height / 2
        angle: card.isActive ? 0 : -8
        Behavior on angle { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 4

        Rectangle {
            id: frame
            anchors.fill: parent
            color: card.isActive ? card.colors.alpha(card.colors.mPrimary, 0.2) : card.colors.alpha(card.colors.mOnSurface, 0.07)
            border.color: card.isActive ? card.colors.mPrimary : card.colors.alpha(card.colors.mOutline, 0.8)
            border.width: card.isActive ? 2 : 1

            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }

            Column {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 8

                Item {
                    width: parent.width
                    height: parent.height - label.height - 8
                    clip: true

                    Image {
                        id: img
                        anchors.fill: parent
                        source: card.filePath ? "file://" + card.filePath : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true

                        sourceSize.width: 300
                        sourceSize.height: 500

                        scale: card.isActive ? 1.15 : 1.0
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                    }

                    // Top Active Neon Indicator Strip
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: card.isActive ? 4 : 0
                        color: card.colors.mPrimary
                        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                    }
                }

                Text {
                    id: label
                    width: parent.width
                    text: card.fileName
                    color: card.isActive ? card.colors.mOnSurface : card.colors.alpha(card.colors.mOnSurfaceVariant, 0.55)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.bold: card.isActive
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: card.hovered()
                onClicked: card.clicked()
            }
        }
    }
}
