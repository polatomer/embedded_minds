// SeizureGuidanceScreen.qml — Nöbet Acili
// 112 → nöbet videosu → "Nöbet bitti mi?" (yalnızca Evet) → koma pozisyonu
import QtQuick 2.15
import QtMultimedia

Item {
    id: root
    anchors.fill: parent

    property bool   active:               false
    property int    emergencyElapsedSec:  0
    property bool   tourniquetActive:     false
    property int    tourniquetElapsedSec: 0

    property string phase: "idle"
    // idle → call → seizure → seizure_popup → recovery → done

    property bool showSeizurePopup: false
    property bool showDone:         false

    signal backRequested()
    function handlePhysicalBack()   { root.backRequested() }
    function handlePhysicalRotate() {}
    function handlePhysicalPress()  {
        // Encoder basınca "Evet" seçeneği çalışsın
        if (root.showSeizurePopup) root.goRecovery()
    }

    function videoUrl(key) {
        return appBridge.mediaBaseUrl + "/seizure/" + key + ".mp4"
    }

    function playVideo(key) {
        videoPlayer.stop(); videoPlayer.source = ""
        videoPlayer.source = videoUrl(key)
        videoPlayer.play()
    }

    function goRecovery() {
        showSeizurePopup = false
        phase = "recovery"
        playVideo("video_recovery_position")
        try { appBridge.eventRecorder.logDecision("seizure", "Nöbet bitti mi?", "Evet, bitti") } catch(e) {}
    }

    onActiveChanged: {
        if (active) {
            phase = "call"; showSeizurePopup = false; showDone = false
            playVideo("video_call_112")
        } else {
            videoPlayer.stop(); videoPlayer.source = ""
            phase = "idle"; showSeizurePopup = false; showDone = false
        }
    }

    SoundEffect {
        id: popupVoice
        source: "qrc:/ui/assets/seizure/voice_q_seizure_ended.wav"
        volume: 1.0
    }

    MediaPlayer {
        id: videoPlayer
        audioOutput: AudioOutput { volume: 1.0 }
        videoOutput: videoOut

        onErrorOccurred: {
            // Video bulunamazsa fazı ilerlet
            if (!root.active) return
            switch (root.phase) {
            case "call":    root.phase = "seizure"; root.playVideo("video_seizure"); break
            case "seizure": root.phase = "seizure_popup"; root.showSeizurePopup = true; popupVoice.play(); break
            case "recovery":root.phase = "done"; root.showDone = true; break
            }
        }

        onMediaStatusChanged: {
            if (mediaStatus !== MediaPlayer.EndOfMedia || !root.active) return

            switch (root.phase) {
            case "call":
                root.phase = "seizure"
                root.playVideo("video_seizure")
                break
            case "seizure":
                // Nöbet videosu bitti → popup
                root.phase = "seizure_popup"
                root.showSeizurePopup = true
                popupVoice.play()
                break
            case "recovery":
                root.phase = "done"
                root.showDone = true
                break
            }
        }
    }

    // ── VİZÜEL ─────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: "#05070A" }

    SharedTopBar {
        id: topBar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        guideText: {
            switch (root.phase) {
            case "call":          return "112'yi Arayın"
            case "seizure":       return "Nöbet Sırasında Hastayı Koruyun"
            case "seizure_popup": return "Nöbet Sırasında Hastayı Koruyun"
            case "recovery":      return "Koma Pozisyonu"
            case "done":          return "Hasta İzleniyor"
            default:              return "Nöbet Acil Durumu"
            }
        }
        emergencyElapsedSec:  root.emergencyElapsedSec
        tourniquetActive:     root.tourniquetActive
        tourniquetElapsedSec: root.tourniquetElapsedSec
        onBackClicked:        root.backRequested()
    }

    VideoOutput {
        id: videoOut
        anchors.top: topBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        fillMode: VideoOutput.PreserveAspectCrop
    }

    // Tamamlandı
    Rectangle {
        anchors.top: topBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        visible: root.showDone; z: 6
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0D1A10" }
            GradientStop { position: 1.0; color: "#0A130C" }
        }
        Column { anchors.centerIn: parent; spacing: 24
            Rectangle { width: 110; height: 110; radius: 55; color: "#16A34A"; anchors.horizontalCenter: parent.horizontalCenter
                Text { anchors.centerIn: parent; text: "✓"; color: "white"; font.pixelSize: 56; font.bold: true } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Protokol Tamamlandı"
                color: "#FFFFFF"; font.pixelSize: 30; font.bold: true }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Hastayı izleyin, yardım geliyor"
                color: "#9CA3AF"; font.pixelSize: 20 }
            Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 20
                Rectangle { width: 220; height: 60; radius: 20; color: "#16A34A"
                    Text { anchors.centerIn: parent; text: "Ana Sayfa"; color: "#FFFFFF"; font.pixelSize: 20; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: appBridge.goHome() } }
            }
        }
    }

    // ── "Nöbet bitti mi?" popup — yalnızca Evet butonu ───────────────────
    Rectangle {
        anchors.top: topBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        visible: root.showSeizurePopup; color: "#7A000000"; z: 5

        Rectangle {
            width: 560; anchors.centerIn: parent
            height: sCol.implicitHeight + 60
            radius: 30; color: "#F8FAFC"; border.color: "#D7DEE6"; border.width: 2

            Column {
                id: sCol
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 30
                width: parent.width - 60; spacing: 32

                Text { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width
                    text: "Nöbet bitti mi?"
                    color: "#0F172A"; font.pixelSize: 30; font.bold: true
                    horizontalAlignment: Text.AlignHCenter }

                Text { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width
                    text: "Kasılmalar durdu ve vücut sakinleşti mi?"
                    color: "#475569"; font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }

                Rectangle {
                    width: 320; height: 110; radius: 26; color: "#16A34A"
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text { anchors.centerIn: parent; text: "Evet, Bitti"
                        color: "#FFFFFF"; font.pixelSize: 30; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: root.goRecovery() }
                }
            }
        }
    }
}
