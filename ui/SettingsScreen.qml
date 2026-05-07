import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    anchors.fill: parent

    property string selectedLanguage: "tr"
    property string statusMessage: ""

    readonly property color pageText: "#14273B"
    readonly property color subText: "#6C7E92"
    readonly property color lineColor: "#D9E4F0"
    readonly property color cardBg: "#FFFFFF"
    readonly property color cardBorder: "#D8E3EF"
    readonly property color selectedBg: "#EDF4FF"
    readonly property color selectedBorder: "#76A6FF"
    readonly property color dangerText: "#F04E58"
    readonly property color dangerBorder: "#F3B2B7"
    readonly property color dangerBg: "#FFF5F5"

    readonly property bool dbDeleteEnabled: (
        appBridge
        && appBridge.eventRecorder
        && !appBridge.eventRecorder.recording
    )

    signal backRequested()
    signal languageSelected(string code)

    property int selectedControl: 0

    function handlePhysicalBack() {
        root.backRequested()
    }

    function handlePhysicalRotate(direction) {
        if (direction > 0)
            selectedControl = (selectedControl + 1) % 4
        else if (direction < 0)
            selectedControl = (selectedControl + 3) % 4
    }

    function handlePhysicalPress() {
        switch (selectedControl) {
        case 0:
            root.backRequested()
            break
        case 1:
            root.languageSelected("tr")
            break
        case 2:
            root.languageSelected("en")
            break
        case 3:
            if (root.dbDeleteEnabled)
                confirmDeleteDialog.open()
            break
        }
    }

    Dialog {
        id: confirmDeleteDialog
        modal: true
        focus: true
        width: 420
        anchors.centerIn: parent
        title: "Onay"

        standardButtons: Dialog.Yes | Dialog.No

        contentItem: Column {
            spacing: 10

            Text {
                text: "Tüm olay kayıtları ve video segmentleri silinecek."
                wrapMode: Text.WordWrap
                color: "#14273B"
                font.pixelSize: 16
            }

            Text {
                text: "Bu işlem geri alınamaz."
                wrapMode: Text.WordWrap
                color: "#F04E58"
                font.pixelSize: 14
                font.bold: true
            }
        }

        onAccepted: {
            const ok = appBridge.eventRecorder.deleteAllEvents()
            statusMessage = ok
                    ? "Veritabanı başarıyla silindi."
                    : "Veritabanı silinemedi. Aktif kayıt olabilir."
            resultDialog.open()
        }
    }

    Dialog {
        id: resultDialog
        modal: true
        focus: true
        width: 420
        anchors.centerIn: parent
        title: "Bilgi"

        standardButtons: Dialog.Ok

        contentItem: Text {
            text: root.statusMessage
            wrapMode: Text.WordWrap
            color: "#14273B"
            font.pixelSize: 15
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                width: 54
                height: 54
                radius: 16
                color: "#FFFFFF"
                border.width: root.selectedControl === 0 ? 3 : 1
                border.color: root.selectedControl === 0 ? root.selectedBorder : root.cardBorder

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: root.pageText
                    font.pixelSize: 30
                    font.weight: Font.Medium
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.backRequested()
                }
            }

            ColumnLayout {
                spacing: 0
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: "Ayarlar"
                    color: root.pageText
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Sistem yapılandırması"
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
            Layout.preferredHeight: 170
            radius: 20
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                Text {
                    text: "Dil Ayarı"
                    color: root.pageText
                    font.pixelSize: 22
                    font.weight: Font.Medium
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 14
                    color: root.selectedLanguage === "tr" ? root.selectedBg : "#FBFDFF"
                    border.width: root.selectedControl === 1 ? 3 : 1
                    border.color: root.selectedControl === 1 ? root.selectedBorder : (root.selectedLanguage === "tr" ? root.selectedBorder : root.cardBorder)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        text: "Türkçe"
                        color: root.pageText
                        font.pixelSize: 20
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.languageSelected("tr")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 14
                    color: root.selectedLanguage === "en" ? root.selectedBg : "#FBFDFF"
                    border.width: root.selectedControl === 2 ? 3 : 1
                    border.color: root.selectedControl === 2 ? root.selectedBorder : (root.selectedLanguage === "en" ? root.selectedBorder : root.cardBorder)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        text: "English"
                        color: root.pageText
                        font.pixelSize: 20
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.languageSelected("en")
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 20
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                Text {
                    text: "Veritabanı"
                    color: root.pageText
                    font.pixelSize: 22
                    font.weight: Font.Medium
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 14
                    color: root.dangerBg
                    border.width: root.selectedControl === 3 ? 3 : 1
                    border.color: root.selectedControl === 3 ? root.dangerText : root.dangerBorder
                    opacity: root.dbDeleteEnabled ? 1.0 : 0.45

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        text: "Veritabanını Sil"
                        color: root.dangerText
                        font.pixelSize: 18
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.dbDeleteEnabled
                        onClicked: confirmDeleteDialog.open()
                    }
                }

                Text {
                    visible: !root.dbDeleteEnabled
                    text: "Aktif kayıt sırasında silme işlemi kapalıdır."
                    color: root.subText
                    font.pixelSize: 12
                }
            }
        }
    }
}