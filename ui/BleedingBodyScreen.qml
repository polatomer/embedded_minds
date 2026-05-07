// BleedingBodyScreen.qml — Vücut Kanaması (Hafif + Ağır tek ekran)
// 112 → gövde kanama videosu → Tekrar Dinle / Devam butonları
// Devam: "Basıya devam edin, hastayı takip edin, yetkilileri bekleyin"
import QtQuick 2.15
import QtMultimedia

Item {
    id: root
    anchors.fill: parent

    property bool   active:               false
    property int    emergencyElapsedSec:  0
    property bool   tourniquetActive:     false
    property int    tourniquetElapsedSec: 0

    property bool showChoice:   false   // Tekrar / Devam butonları
    property bool showFinalMsg: false   // Son mesaj ekranı
    property int  currentVideo: 0       // 0=112, 1=gövde kanama

    signal backRequested()

    function handlePhysicalBack()   { root.backRequested() }
    function handlePhysicalRotate() {}
    function handlePhysicalPress()  {}

    function playVideo112() {
        currentVideo = 0
        videoPlayer.stop(); videoPlayer.source = ""
        var src = appBridge.mediaBaseUrl + "/bleeding_body/video_call_112.mp4"
        videoPlayer.source = src; videoPlayer.play()
    }

    function playVideoBody() {
        currentVideo = 1
        videoPlayer.stop(); videoPlayer.source = ""
        var src = appBridge.mediaBaseUrl + "/bleeding_body/video_body_bleeding.mp4"
        videoPlayer.source = src; videoPlayer.play()
    }

    function showFinal() {
        showChoice   = false
        showFinalMsg = true
        finalVoice.stop(); finalVoice.play()
        try { appBridge.eventRecorder.logDecision( "bleeding_body", "Devam seçildi", "son_mesaj_gosterildi" ) } catch(e) {}
    }

    onActiveChanged: {
        if (active) {
            showChoice = false; showFinalMsg = false; currentVideo = 0
            playVideo112()
        } else {
            videoPlayer.stop(); videoPlayer.source = ""
            finalVoice.stop()
            showChoice = false; showFinalMsg = false
        }
    }

    SoundEffect {
        id: finalVoice
        source: "qrc:/ui/assets/bleeding_body/voice_final_msg.wav"
        volume: 1.0
    }

    MediaPlayer {
        id: videoPlayer
        audioOutput: AudioOutput { volume: 1.0 }
        videoOutput: videoOut

        onMediaStatusChanged: {
            if (mediaStatus !== MediaPlayer.EndOfMedia) return
            if (root.currentVideo === 0) {
                // 112 bitti → gövde kanama videosu
                root.playVideoBody()
            } else {
                // Gövde kanama videosu bitti → buton seçimi
                root.showChoice = true
            }
        }
    }

    // ── VİZÜEL ─────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: "#05070A" }

    SharedTopBar {
        id: topBar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        guideText:            "Vücut Kanaması"
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

    // ── Tekrar / Devam seçim ekranı ─────────────────────────────────────
    Rectangle {
        anchors.top: topBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        visible: root.showChoice
        color: "#7A000000"; z: 5

        Row {
            anchors.centerIn: parent; spacing: 30

            Rectangle {
                width: 280; height: 120; radius: 26; color: "#1D4ED8"
                Text { anchors.centerIn: parent; text: "Tekrar İzle"
                    color: "#FFFFFF"; font.pixelSize: 30; font.bold: true }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.showChoice = false
                        root.playVideoBody()
                    }
                }
            }

            Rectangle {
                width: 280; height: 120; radius: 26; color: "#16A34A"
                Text { anchors.centerIn: parent; text: "Devam"
                    color: "#FFFFFF"; font.pixelSize: 30; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: root.showFinal() }
            }
        }
    }

    // ── Son mesaj ekranı ─────────────────────────────────────────────────
    Rectangle {
        anchors.top: topBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        visible: root.showFinalMsg
        z: 6
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0E1A2B" }
            GradientStop { position: 1.0; color: "#0B1422" }
        }

        Column {
            anchors.centerIn: parent; spacing: 28

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Basıya devam edin"
                color: "#FFFFFF"; font.pixelSize: 34; font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Hastanın durumunu takip edin"
                color: "#9CA3AF"; font.pixelSize: 24
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Yetkilileri bekleyin"
                color: "#9CA3AF"; font.pixelSize: 24
            }
        }
    }
}
