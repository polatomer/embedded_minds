// SharedTopBar.qml
// Tüm yönlendirme ekranlarında kullanılan ortak üst şerit.
// 800 × 58 px — mevcut ekranlarla birebir aynı koyu tema.
//
// NABIZ: 45–135 bpm arası NORMAL (yeşil), dışı DÜŞÜK/YÜKSEK (kırmızı)  [ERC/AHA]
// SPO₂:  ≥ 90% NORMAL (yeşil), < 90% DÜŞÜK (kırmızı)                   [ERC/BTS]
// Sinyal kalitesi ≤ 50 → "Bağlantı yok"

import QtQuick 2.15

Item {
    id: root
    width:  parent.width
    height: 58

    // ── Dışarıdan set edilenler ──────────────────────────────────────────
    property string guideText:       ""
    property int    emergencyElapsedSec:  0
    property bool   tourniquetActive:     false
    property int    tourniquetElapsedSec: 0

    // Geri butonu için sinyal
    signal backClicked()

    // ── Vital hesapları ──────────────────────────────────────────────────
    readonly property var    vs:          appBridge.vitalSigns
    readonly property bool   fingerOn:    vs.fingerPresent
    readonly property bool   goodQuality: vs.signalQuality > 0.08
    readonly property bool   pulseOk:     fingerOn && goodQuality && vs.pulseDetected
    readonly property bool   spo2Ok:      fingerOn && goodQuality && vs.signalStable
    readonly property double bpm:         vs.heartRateBpm
    readonly property double spo2:        vs.spo2

    // Nabız normal aralık: 45–135
    readonly property bool pulseNormal: pulseOk && bpm >= 45 && bpm <= 135
    readonly property bool spo2Normal:  spo2Ok  && spo2 >= 90

    function fmtSec(s) {
        var m = Math.floor(s / 60); var sec = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (sec < 10 ? "0" : "") + sec
    }

    Rectangle {
        anchors.fill: parent
        color: "#141A20"

        // ── Geri butonu ──────────────────────────────────────────────────
        Rectangle {
            id: backBtn
            width: 54; height: 42; radius: 12
            anchors.left: parent.left; anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            color: "#1F2730"
            border.color: "#60A5FA"; border.width: 2

            Text { anchors.centerIn: parent; text: "‹"; color: "#FFFFFF"; font.pixelSize: 34; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: root.backClicked() }
        }

        // ── Orta: Teşhis / yönlendirme metni ────────────────────────────
        Text {
            anchors.left: backBtn.right; anchors.leftMargin: 10
            anchors.right: rightRow.left; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.guideText
            color: "#FFFFFF"; font.pixelSize: 18; font.bold: true
            elide: Text.ElideRight; maximumLineCount: 2
            wrapMode: Text.WordWrap
        }

        // ── Sağ grup: Acil süre + Turnike + Nabız + SpO₂ ─────────────────
        Row {
            id: rightRow
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // Acil Durum Süresi
            Rectangle {
                width: 106; height: 42; radius: 12
                color: "#1B232B"; border.color: "#2D3844"; border.width: 1

                Column {
                    anchors.centerIn: parent; spacing: 1
                    Text { anchors.horizontalCenter: parent.horizontalCenter
                        text: "ACİL"; color: "#9CA3AF"; font.pixelSize: 10; font.bold: true }
                    Text { anchors.horizontalCenter: parent.horizontalCenter
                        text: root.fmtSec(root.emergencyElapsedSec)
                        color: "#FFFFFF"; font.pixelSize: 18; font.bold: true }
                }
            }

            // Turnike Sayacı (sadece aktifse)
            Rectangle {
                visible: root.tourniquetActive
                width: 116; height: 42; radius: 12
                color: "#3B0000"
                border.color: root.tourniquetElapsedSec >= 120 ? "#FCA5A5" : "#DC2626"
                border.width: 2

                Column {
                    anchors.centerIn: parent; spacing: 1
                    Text { anchors.horizontalCenter: parent.horizontalCenter
                        text: "TURNİKE"; color: "#FCA5A5"; font.pixelSize: 10; font.bold: true }
                    Text { anchors.horizontalCenter: parent.horizontalCenter
                        text: root.fmtSec(root.tourniquetElapsedSec)
                        color: root.tourniquetElapsedSec >= 120 ? "#FCA5A5" : "#FF5A5A"
                        font.pixelSize: 18; font.bold: true }
                }

                SequentialAnimation on border.width {
                    running: root.tourniquetActive; loops: Animation.Infinite
                    NumberAnimation { from: 2; to: 3.5; duration: 700 }
                    NumberAnimation { from: 3.5; to: 2; duration: 700 }
                }
            }

            // Nabız
            Rectangle {
                width: 158; height: 42; radius: 12
                color: "#1B232B"
                border.color: !root.pulseOk ? "#2D3844"
                              : root.pulseNormal ? "#16A34A" : "#DC2626"
                border.width: root.pulseOk ? 2 : 1

                Row {
                    anchors.centerIn: parent; spacing: 8

                    Text {
                        text: "♥"
                        color: !root.pulseOk ? "#6B7280"
                               : root.pulseNormal ? "#4ADE80" : "#FF5A5A"
                        font.pixelSize: 22; font.bold: true

                        SequentialAnimation on opacity {
                            running: root.pulseOk && !root.pulseNormal
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.3; duration: 500 }
                            NumberAnimation { from: 0.3; to: 1.0; duration: 500 }
                        }
                    }

                    Text {
                        text: root.pulseOk ? Math.round(root.bpm) + " bpm" : "Bağlantı yok"
                        color: !root.pulseOk ? "#6B7280"
                               : root.pulseNormal ? "#FFFFFF" : "#FF5A5A"
                        font.pixelSize: root.pulseOk ? 22 : 14; font.bold: true
                    }
                }
            }

            // SpO₂
            Rectangle {
                width: 148; height: 42; radius: 12
                color: "#1B232B"
                border.color: !root.spo2Ok ? "#2D3844"
                              : root.spo2Normal ? "#16A34A" : "#DC2626"
                border.width: root.spo2Ok ? 2 : 1

                Row {
                    anchors.centerIn: parent; spacing: 8

                    Text {
                        text: "O₂"
                        color: !root.spo2Ok ? "#6B7280"
                               : root.spo2Normal ? "#67E8F9" : "#FF5A5A"
                        font.pixelSize: 20; font.bold: true

                        SequentialAnimation on opacity {
                            running: root.spo2Ok && !root.spo2Normal
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.3; duration: 600 }
                            NumberAnimation { from: 0.3; to: 1.0; duration: 600 }
                        }
                    }

                    Text {
                        text: root.spo2Ok ? Math.round(root.spo2) + "%" : "Bağlantı yok"
                        color: !root.spo2Ok ? "#6B7280"
                               : root.spo2Normal ? "#FFFFFF" : "#FF5A5A"
                        font.pixelSize: root.spo2Ok ? 22 : 14; font.bold: true
                    }
                }
            }
        }
    }
}
