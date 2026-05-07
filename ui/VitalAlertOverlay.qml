import QtQuick 2.15
import QtMultimedia

Item {
    id: root
    anchors.fill: parent
    z: 9999

    property bool monitoringActive: false

    signal navigateToCpr()
    signal navigateToRespiratory()

    property bool overlayVisible: false
    property string alertType: "pulse"
    property int pulseCount: 0
    property int spo2Count: 0

    readonly property var vs: appBridge.vitalSigns

    function pulseInDanger() {
        if (!vs.fingerPresent || vs.signalQuality <= 0.08 || !vs.pulseDetected)
            return false
        return vs.heartRateBpm < 45 || vs.heartRateBpm > 135
    }

    function spo2InDanger() {
        if (!vs.fingerPresent || vs.signalQuality <= 0.08 || !vs.signalStable)
            return false
        return vs.spo2 < 90
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.monitoringActive && !root.overlayVisible

        onTriggered: {
            var pd = root.pulseInDanger()
            var sd = root.spo2InDanger()

            if (!pd) {
                root.pulseCount = 0
            } else {
                root.pulseCount++
                if (root.pulseCount >= 10) {
                    root.trigger("pulse")
                    return
                }
            }

            if (!sd) {
                root.spo2Count = 0
            } else {
                root.spo2Count++
                if (root.spo2Count >= 10) {
                    root.trigger("spo2")
                    return
                }
            }
        }
    }

    function trigger(type) {
        var finalType = (pulseInDanger() && spo2InDanger()) ? "pulse" : type
        alertType = finalType
        overlayVisible = true
        pulseCount = 0
        spo2Count = 0

        try { appBridge.eventRecorder.logDecision( "vital_alert", finalType === "pulse" ? "Nabız kritik aralıkta" : "SpO2 kritik aralıkta", "10_saniye_alarm_tetiklendi" ) } catch(e) {}

        alertVoice.stop()
        alertVoice.play()
    }

    function dismiss() {
        overlayVisible = false
    }

    function proceed() {
        overlayVisible = false

        try { appBridge.eventRecorder.logDecision( "vital_alert_action", alertType === "pulse" ? "CPR ekranina gecis" : "Solunum ekranina gecis", "kullanici_onayladi" ) } catch(e) {}

        if (alertType === "pulse")
            root.navigateToCpr()
        else
            root.navigateToRespiratory()
    }

    SoundEffect {
        id: alertVoice
        source: "qrc:/ui/assets/shared/voice_vital_alert.wav"
        volume: 1.0
    }

    Rectangle {
        anchors.fill: parent
        visible: root.overlayVisible
        color: "#CC000000"

        Rectangle {
            anchors.centerIn: parent
            width: 200
            height: 200
            radius: 100
            color: root.alertType === "pulse" ? "#500000" : "#001A3B"
            opacity: 0.5

            SequentialAnimation on scale {
                running: root.overlayVisible
                loops: Animation.Infinite

                NumberAnimation { from: 0.8; to: 1.4; duration: 1200 }
                NumberAnimation { from: 1.4; to: 0.8; duration: 0 }
            }
        }

        Rectangle {
            width: 680
            height: alertContent.implicitHeight + 60
            anchors.centerIn: parent
            radius: 30
            color: "#F8FAFC"
            border.color: "#D7DEE6"
            border.width: 2

            Column {
                id: alertContent
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 30
                width: parent.width - 60
                spacing: 24

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.alertType === "pulse" ? "⚠ Kritik Nabız Uyarısı" : "⚠ Düşük Oksijen Saturasyonu"
                    color: root.alertType === "pulse" ? "#DC2626" : "#0891B2"
                    font.pixelSize: 24
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Nabız: " + Math.round(root.vs.heartRateBpm || 0) + " atım/dk   ·   "
                          + "SpO2: " + Math.round(root.vs.spo2 || 0) + "%   ·   "
                          + "Sinyal: %" + Math.round((root.vs.signalQuality || 0) * 100)
                    color: "#475569"
                    font.pixelSize: 16
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    text: root.alertType === "pulse"
                          ? "Sensör 10 saniyedir kritik nabız değeri algılıyor.\n\nHastanın nabzını ve solunumunu hemen fiziksel olarak kontrol edin."
                          : "Sensör 10 saniyedir düşük oksijen saturasyonu algılıyor (SpO2 < %90).\n\nHastanın hava yolunu açık tutun ve solunumunu değerlendirin."
                    color: "#1E293B"
                    font.pixelSize: 18
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    text: root.alertType === "pulse"
                          ? "Hastanın nabzı ve solunumu var mı?"
                          : "Hastanın solunumu yeterli görünüyor mu?"
                    color: "#0F172A"
                    font.pixelSize: 26
                    font.bold: true
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 20

                    Rectangle {
                        width: 280
                        height: 100
                        radius: 26
                        color: root.alertType === "pulse" ? "#DC2626" : "#0891B2"

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.alertType === "pulse" ? "Nabız ve Solunum Yok" : "Solunum Yetersiz"
                                color: "#FFFFFF"
                                font.pixelSize: 22
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.alertType === "pulse" ? "CPR Ekranına Geç" : "Solunum Protokolü"
                                color: "#B3FFFFFF"
                                font.pixelSize: 14
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.proceed()
                        }
                    }

                    Rectangle {
                        width: 280
                        height: 100
                        radius: 26
                        color: "#1E293B"
                        border.color: "#334155"
                        border.width: 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.alertType === "pulse" ? "Nabız ve Solunum Var" : "Solunum Yeterli"
                                color: "#FFFFFF"
                                font.pixelSize: 22
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Mevcut Protokole Devam Et"
                                color: "#99FFFFFF"
                                font.pixelSize: 14
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.dismiss()
                        }
                    }
                }
            }
        }
    }
}
