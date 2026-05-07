import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    anchors.fill: parent

    signal startRequested()
    signal manualRequested()
    signal settingsRequested()
    signal recordsRequested()

    property int selectedAction: 0

    function handlePhysicalBack() {
    }

    function handlePhysicalRotate(direction) {
        if (direction > 0)
            selectedAction = (selectedAction + 1) % 4
        else if (direction < 0)
            selectedAction = (selectedAction + 3) % 4
    }

    function handlePhysicalPress() {
        switch (selectedAction) {
        case 0:
            root.startRequested()
            break
        case 1:
            root.manualRequested()
            break
        case 2:
            root.recordsRequested()
            break
        case 3:
            root.settingsRequested()
            break
        }
    }

    readonly property color pageText: "#13283D"
    readonly property color subText: "#667B91"
    readonly property color lineColor: "#D2DEEA"

    readonly property color cardBg: "#FFFFFF"
    readonly property color cardBorder: "#C8D7E6"

    readonly property color iconShellBg: "#F3F7FB"
    readonly property color iconShellBorder: "#C8D7E6"

    readonly property color manualInnerBg: "#DCEBFF"
    readonly property color manualInnerBorder: "#A6C7FF"
    readonly property color manualIcon: "#245FCE"

    readonly property color settingsInnerBg: "#E2EAF3"
    readonly property color settingsInnerBorder: "#BCCBDB"
    readonly property color settingsIcon: "#4B6074"

    readonly property color recordsInnerBg: "#FEE4D6"
    readonly property color recordsInnerBorder: "#FDB894"
    readonly property color recordsIcon: "#C2410C"

    readonly property color redA: "#FF5C66"
    readonly property color redB: "#F13E49"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                width: 54
                height: 54
                radius: 16
                color: "#FF545D"
                border.width: 1
                border.color: "#FF8C93"

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 15
                    color: "#FFFFFF"
                    opacity: 0.08
                }

                Text {
                    anchors.centerIn: parent
                    text: "⚠"
                    color: "white"
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                }
            }

            ColumnLayout {
                spacing: 0
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: "Akıllı Sağlık Çantası"
                    color: root.pageText
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Acil müdahale ve değerlendirme sistemi"
                    color: root.subText
                    font.pixelSize: 12
                }
            }

            Item { Layout.fillWidth: true }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.lineColor
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 130
            radius: 24
            border.width: root.selectedAction === 0 ? 3 : 1
            border.color: root.selectedAction === 0 ? "#FFFFFF" : "#FF8C93"
            scale: root.selectedAction === 0 ? 1.01 : 1.0

            gradient: Gradient {
                GradientStop { position: 0.0; color: root.redA }
                GradientStop { position: 1.0; color: root.redB }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 23
                color: "#FFFFFF"
                opacity: 0.05
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 18

                Rectangle {
                    width: 80
                    height: 80
                    radius: 22
                    color: "#FFFFFF"
                    opacity: 0.16
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 8
                        radius: 16
                        color: "#FFFFFF"
                        opacity: 0.10
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "⚠"
                        color: "white"
                        font.pixelSize: 38
                        font.weight: Font.Bold
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        text: "Acil Durumu Başlat"
                        color: "white"
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "Acil değerlendirme protokolünü etkinleştir"
                        color: "#FFF0F1"
                        font.pixelSize: 14
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.startRequested()
            }
        }

        // ── 3 kart: Manuel | Veri Kayıtları | Ayarlar ───────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // Manuel Ölçüm
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 20
                color: root.cardBg
                border.width: root.selectedAction === 1 ? 3 : 1
                border.color: root.selectedAction === 1 ? root.manualIcon : root.cardBorder
                scale: root.selectedAction === 1 ? 1.02 : 1.0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Rectangle {
                        width: 52
                        height: 52
                        radius: 16
                        color: root.manualInnerBg
                        border.width: 1
                        border.color: root.manualInnerBorder
                        Layout.alignment: Qt.AlignHCenter

                        Text {
                            anchors.centerIn: parent
                            text: "∿"
                            color: root.manualIcon
                            font.pixelSize: 26
                            font.weight: Font.Bold
                        }
                    }

                    Text {
                        text: "Manuel Ölçüm"
                        color: root.pageText
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Sensör dışı\ndeğerlendirme"
                        color: root.subText
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.manualRequested()
                }
            }

            // Veri Kayıtları
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 20
                color: root.cardBg
                border.width: root.selectedAction === 2 ? 3 : 1
                border.color: root.selectedAction === 2 ? root.recordsIcon : root.cardBorder
                scale: root.selectedAction === 2 ? 1.02 : 1.0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Rectangle {
                        width: 52
                        height: 52
                        radius: 16
                        color: root.recordsInnerBg
                        border.width: 1
                        border.color: root.recordsInnerBorder
                        Layout.alignment: Qt.AlignHCenter

                        Text {
                            anchors.centerIn: parent
                            text: "📋"
                            color: root.recordsIcon
                            font.pixelSize: 24
                        }
                    }

                    Text {
                        text: "Veri Kayıtları"
                        color: root.pageText
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Geçmiş olayları\ngörüntüle"
                        color: root.subText
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.recordsRequested()
                }
            }

            // Ayarlar
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 20
                color: root.cardBg
                border.width: root.selectedAction === 3 ? 3 : 1
                border.color: root.selectedAction === 3 ? root.settingsIcon : root.cardBorder
                scale: root.selectedAction === 3 ? 1.02 : 1.0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Rectangle {
                        width: 52
                        height: 52
                        radius: 16
                        color: root.settingsInnerBg
                        border.width: 1
                        border.color: root.settingsInnerBorder
                        Layout.alignment: Qt.AlignHCenter

                        Text {
                            anchors.centerIn: parent
                            text: "⚙"
                            color: root.settingsIcon
                            font.pixelSize: 24
                            font.weight: Font.DemiBold
                        }
                    }

                    Text {
                        text: "Ayarlar"
                        color: root.pageText
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Dil ve sistem\nseçenekleri"
                        color: root.subText
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.settingsRequested()
                }
            }
        }
    }
}
