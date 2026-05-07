import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    anchors.fill: parent

    property string screenTitle:    "Acil Değerlendirme"
    property string screenSubtitle: "Her soruyu dikkatle yanıtlayın"
    property string questionText:   ""
    property string questionHint:   ""   // ← YENİ: nasıl kontrol edileceği açıklaması
    property var    answersModel:   []
    property int    selectedAnswerIndex: 0

    signal backRequested()
    signal answerSelected(int answerIndex)

    readonly property color pageText:     "#14273B"
    readonly property color subText:      "#6C7E92"
    readonly property color lineColor:    "#D9E4F0"
    readonly property color cardBorder:   "#D8E3EF"
    readonly property color hintBg:       "#F0F6FF"
    readonly property color hintBorder:   "#C5D9F5"
    readonly property color hintText:     "#2D5A8E"

    readonly property color yesColor:     "#11B981"
    readonly property color yesSoft:      "#E8FBF4"
    readonly property color yesBorder:    "#A8E8D1"
    readonly property color noColor:      "#F2555A"
    readonly property color noSoft:       "#FFF1F1"
    readonly property color noBorder:     "#F2B7BA"
    readonly property color neutralColor: "#4C89F8"
    readonly property color neutralSoft:  "#EEF4FF"
    readonly property color neutralBorder:"#BDD3FF"

    function answerLabel(item) {
        if (item === undefined || item === null) return ""
        if (typeof item === "string") return item
        return item.text !== undefined ? item.text : ""
    }

    function answerImage(item) {
        if (item === undefined || item === null) return ""
        if (typeof item === "string") return ""
        return item.image !== undefined ? item.image : ""
    }

    function normalizedText(value) { return String(answerLabel(value)).toLowerCase() }
    function isYesText(value) { var t = normalizedText(value); return t.indexOf("evet") !== -1 || t.indexOf("yes") !== -1 }
    function isNoText(value)  { var t = normalizedText(value); return t.indexOf("hayır") !== -1 || t.indexOf("hayir") !== -1 || t.indexOf("no") !== -1 }

    function accentColor(value) { if (isYesText(value)) return yesColor;  if (isNoText(value)) return noColor;  return neutralColor }
    function softColor(value)   { if (isYesText(value)) return yesSoft;   if (isNoText(value)) return noSoft;   return neutralSoft  }
    function borderColor(value) { if (isYesText(value)) return yesBorder; if (isNoText(value)) return noBorder; return neutralBorder}
    function iconText(value)    { if (isYesText(value)) return "✓";       if (isNoText(value)) return "✕";      return "•"          }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // ── Üst başlık ────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                width: 54; height: 54; radius: 16
                color: "#FFFFFF"; border.width: 1; border.color: root.cardBorder

                Text { anchors.centerIn: parent; text: "‹"; color: root.pageText; font.pixelSize: 30; font.weight: Font.Medium }
                MouseArea { anchors.fill: parent; onClicked: root.backRequested() }
            }

            ColumnLayout {
                spacing: 0; Layout.alignment: Qt.AlignVCenter
                Text { text: root.screenTitle;    color: root.pageText; font.pixelSize: 24; font.weight: Font.DemiBold }
                Text { text: root.screenSubtitle; color: root.subText;  font.pixelSize: 12 }
            }

            Item { Layout.fillWidth: true }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.lineColor }

        // ── Soru metni ────────────────────────────────────────────────────
        Text {
            Layout.fillWidth: true
            text: root.questionText
            color: root.pageText
            font.pixelSize: 28
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        // ── Kontrol talimatı (hint) ───────────────────────────────────────
        // Yalnızca hint varsa gösterilir.
        Rectangle {
            Layout.fillWidth: true
            visible: root.questionHint !== ""
            height: hintText.implicitHeight + 20
            radius: 14
            color: root.hintBg
            border.color: root.hintBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Bilgi ikonu
                Rectangle {
                    width: 32; height: 32; radius: 16
                    color: "#DBEAFE"
                    Layout.alignment: Qt.AlignTop
                    Text { anchors.centerIn: parent; text: "ℹ"; color: "#1D4ED8"; font.pixelSize: 18; font.bold: true }
                }

                // Talimat metni
                Text {
                    id: hintText
                    Layout.fillWidth: true
                    text: root.questionHint
                    color: root.hintText
                    font.pixelSize: 16
                    wrapMode: Text.WordWrap
                    lineHeight: 1.4
                }
            }
        }

        // ── 2 seçenek — yatay tam ekran ───────────────────────────────────
        RowLayout {
            visible: root.answersModel.length === 2
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Repeater {
                model: root.answersModel

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 22
                    color: root.softColor(modelData)
                    border.width: index === root.selectedAnswerIndex ? 6 : 2
                    border.color: index === root.selectedAnswerIndex
                                  ? root.accentColor(modelData)
                                  : root.borderColor(modelData)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Image {
                                id: twoChoiceImage
                                anchors.fill: parent; anchors.margins: 6
                                source: root.answerImage(modelData)
                                fillMode: Image.PreserveAspectFit
                                visible: source !== "" && status === Image.Ready
                                smooth: true; mipmap: true
                            }

                            Rectangle {
                                visible: !twoChoiceImage.visible
                                anchors.centerIn: parent
                                width: 110; height: 110; radius: 28
                                color: "#FFFFFF"
                                border.width: 2; border.color: root.borderColor(modelData)

                                Text { anchors.centerIn: parent; text: root.iconText(modelData)
                                    color: root.accentColor(modelData); font.pixelSize: 64; font.weight: Font.Bold }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.answerLabel(modelData)
                            color: root.accentColor(modelData)
                            font.pixelSize: 34; font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                        }
                    }

                    MouseArea { anchors.fill: parent; onClicked: root.answerSelected(index) }
                }
            }
        }

        // ── 3+ seçenek — grid ─────────────────────────────────────────────
        GridLayout {
            visible: root.answersModel.length !== 2
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.answersModel.length >= 3 ? 3 : Math.max(1, root.answersModel.length)
            columnSpacing: 10; rowSpacing: 10

            Repeater {
                model: root.answersModel

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 150
                    radius: 18
                    color: root.softColor(modelData)
                    border.width: index === root.selectedAnswerIndex ? 5 : 2
                    border.color: index === root.selectedAnswerIndex
                                  ? root.accentColor(modelData)
                                  : root.borderColor(modelData)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Image {
                                id: multiChoiceImage
                                anchors.fill: parent; anchors.margins: 4
                                source: root.answerImage(modelData)
                                fillMode: Image.PreserveAspectFit
                                visible: source !== "" && status === Image.Ready
                                smooth: true; mipmap: true
                            }

                            Rectangle {
                                visible: !multiChoiceImage.visible
                                anchors.centerIn: parent
                                width: 64; height: 64; radius: 18
                                color: "#FFFFFF"
                                border.width: 2; border.color: root.borderColor(modelData)

                                Text { anchors.centerIn: parent; text: root.iconText(modelData)
                                    color: root.accentColor(modelData); font.pixelSize: 34; font.weight: Font.Bold }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.answerLabel(modelData)
                            color: root.pageText
                            font.pixelSize: 18; font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                        }
                    }

                    MouseArea { anchors.fill: parent; onClicked: root.answerSelected(index) }
                }
            }
        }
    }
}
