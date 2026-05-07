import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    anchors.fill: parent

    property bool active: false
    property string selectedEventId: ""
    property var rec: appBridge.eventRecorder

    signal backRequested()
    signal eventOpened(string eventId)

    property int selectedRow: -1

    function handlePhysicalBack() {
        root.backRequested()
    }

    function handlePhysicalRotate(direction) {
        if (listModel.count <= 0)
            return

        if (direction > 0) {
            if (selectedRow < listModel.count - 1)
                selectedRow += 1
        } else if (direction < 0) {
            if (selectedRow > -1)
                selectedRow -= 1
        }

        if (selectedRow >= 0)
            listView.positionViewAtIndex(selectedRow, ListView.Contain)
    }

    function handlePhysicalPress() {
        if (selectedRow < 0) {
            root.backRequested()
            return
        }

        const item = listModel.get(selectedRow)
        if (item && item.id !== undefined) {
            root.selectedEventId = item.id
            root.eventOpened(item.id)
        }
    }

    function refresh() {
        listModel.clear()

        if (!rec)
            return

        var items = rec.listEvents()
        for (var i = 0; i < items.length; i++)
            listModel.append(items[i])

        selectedRow = listModel.count > 0 ? 0 : -1
    }

    onActiveChanged: {
        if (active)
            refresh()
    }

    Connections {
        target: rec
        function onEventsListChanged() {
            if (root.active)
                refresh()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#F8FBFF"
        z: -1
    }

    ListModel {
        id: listModel
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                width: 54
                height: 42
                radius: 12
                color: "#1F2730"
                border.color: root.selectedRow < 0 ? "#60A5FA" : "#2D3844"
                border.width: root.selectedRow < 0 ? 3 : 1

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: "#FFFFFF"
                    font.pixelSize: 30
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.backRequested()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: "Veri Kayıtları"
                    color: "#13283D"
                    font.pixelSize: 22
                    font.bold: true
                }

                Text {
                    text: listModel.count + " olay kaydı"
                    color: "#5B6B7C"
                    font.pixelSize: 12
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#D2DEEA"
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: listModel

            ScrollBar.vertical: ScrollBar {}

            delegate: Rectangle {
                width: listView.width
                height: 78
                radius: 16
                color: index === root.selectedRow ? "#EFF6FF" : "#FFFFFF"
                border.color: index === root.selectedRow ? "#60A5FA" : "#DCE7F3"
                border.width: index === root.selectedRow ? 3 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        width: 54
                        height: 54
                        radius: 14
                        color: "#FEE2E2"
                        border.color: "#FCA5A5"
                        border.width: 1
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: "⚠"
                            color: "#DC2626"
                            font.pixelSize: 26
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            text: date
                            color: "#13283D"
                            font.pixelSize: 17
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: (diagnosis && diagnosis !== "")
                                  ? diagnosis
                                  : "(Yönlendirme yok)"
                            color: "#5B6B7C"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "Süre: " + Math.floor(durationSec / 60) + "dk "
                                  + (durationSec % 60) + "sn · "
                                  + segments + " segment"
                            color: "#8094A8"
                            font.pixelSize: 11
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: "›"
                        color: "#8094A8"
                        font.pixelSize: 32
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selectedEventId = id
                        root.eventOpened(id)
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.8
                height: 140
                radius: 22
                color: "transparent"
                border.color: "#DCE7F3"
                border.width: 1
                visible: listModel.count === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "📋"
                        font.pixelSize: 40
                        color: "#8094A8"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Henüz kayıtlı acil durum yok"
                        color: "#5B6B7C"
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Bir acil durum başlatıldığında burada görünecek"
                        color: "#8094A8"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}