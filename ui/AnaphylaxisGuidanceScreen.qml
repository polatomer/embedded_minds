// AnaphylaxisGuidanceScreen.qml
// Tam custom Item — GuidanceVideoScreen extend etmiyor.
// video_call_112 → EpiPen popup → video_epi1 → 30sn bekleme → rahatladı mı?
//   → Evet: rahat pozisyon   → Hayır: video_epi2 → rahat pozisyon
// EpiPen yoksa: rahat pozisyon yazısı + sesi
import QtQuick 2.15
import QtMultimedia

Item {
    id: root
    anchors.fill: parent

    property bool   active:               false
    property int    emergencyElapsedSec:  0
    property bool   tourniquetActive:     false
    property int    tourniquetElapsedSec: 0

    // Aşamalar:
    // idle → call → epi_question → epi1 → wait → recovered_question
    //      → epi2 → comfort
    //      → no_epi_comfort   (EpiPen yoksa)
    property string phase:       "idle"
    property int    waitSeconds: 30

    property bool showEpiPopup:       false
    property bool showWaitScreen:     false
    property bool showRecoveredPopup: false
    property bool showComfort:        false

    signal backRequested()
    function handlePhysicalBack()   { root.backRequested() }
    function handlePhysicalRotate() {}
    function handlePhysicalPress()  {}

    // ── Sesli komut ──────────────────────────────────────────────────────────
    // showEpiPopup:       Evet=epi1  Hayır=no_epi_comfort
    // showRecoveredPopup: Evet=comfort  Hayır=epi2
    function voiceYes() {
        if (root.showEpiPopup)       { root.goPhase("epi1"); return }
        if (root.showRecoveredPopup) { root.goPhase("comfort") }
    }
    function voiceNo() {
        if (root.showEpiPopup)       { root.goPhase("no_epi_comfort"); return }
        if (root.showRecoveredPopup) { root.goPhase("epi2") }
    }


    function videoUrl(key) {
        var base = appBridge.mediaBaseUrl
        if (!base || base === "") return ""
        return base + "/anaphylaxis/" + key + ".mp4"
    }

    function playVideo(key) {
        videoPlayer.stop()
        videoPlayer.source = ""
        var src = videoUrl(key)
        if (!src || src === "") {
            // Video yoksa mevcut fazın sonuna geç
            Qt.callLater(handleVideoEnd)
            return
        }
        videoPlayer.source = src
        videoPlayer.play()
    }

    function handleVideoEnd() {
        switch (phase) {
        case "call":
            goPhase("epi_question")
            break
        case "epi1":
            goPhase("wait")
            break
        case "epi2":
            goPhase("comfort")
            break
        default:
            break
        }
    }

    function goPhase(p) {
        phase             = p
        showEpiPopup      = false
        showWaitScreen    = false
        showRecoveredPopup= false
        showComfort       = false
        waitTimer.stop()

        switch (p) {
        case "call":
            playVideo("video_call_112")
            break
        case "epi_question":
            videoPlayer.stop(); videoPlayer.source = ""
            showEpiPopup = true
            epiVoice.stop(); epiVoice.play()
            break
        case "epi1":
            playVideo("video_epi1")
            break
        case "wait":
            videoPlayer.stop(); videoPlayer.source = ""
            waitSeconds   = 30
            showWaitScreen = true
            waitVoice.stop(); waitVoice.play()
            waitTimer.start()
            break
        case "recovered_question":
            showRecoveredPopup = true
            recoveredVoice.stop(); recoveredVoice.play()
            break
        case "epi2":
            playVideo("video_epi2")
            break
        case "comfort":
        case "no_epi_comfort":
            videoPlayer.stop(); videoPlayer.source = ""
            showComfort = true
            comfortVoice.stop(); comfortVoice.play()
            break
        }
    }

    onActiveChanged: {
        if (active) {
            goPhase("call")
        } else {
            videoPlayer.stop(); videoPlayer.source = ""
            waitTimer.stop()
            phase = "idle"
            showEpiPopup = false; showWaitScreen = false
            showRecoveredPopup = false; showComfort = false
        }
    }

    Timer {
        id: waitTimer
        interval: 1000
        repeat:   true
        onTriggered: {
            root.waitSeconds--
            if (root.waitSeconds <= 0) {
                stop()
                root.goPhase("recovered_question")
            }
        }
    }

    SoundEffect { id: epiVoice;       source: "qrc:/ui/assets/anaphylaxis/voice_q_epi_available.wav"; volume: 1.0 }
    SoundEffect { id: waitVoice;      source: "qrc:/ui/assets/anaphylaxis/voice_q_wait.wav";           volume: 1.0 }
    SoundEffect { id: recoveredVoice; source: "qrc:/ui/assets/anaphylaxis/voice_q_recovered.wav";      volume: 1.0 }
    SoundEffect { id: comfortVoice;   source: "qrc:/ui/assets/anaphylaxis/voice_comfort_end.wav";      volume: 1.0 }
    SoundEffect { id: noEpiVoice;     source: "qrc:/ui/assets/anaphylaxis/voice_no_epi.wav";           volume: 1.0 }

    MediaPlayer {
        id: videoPlayer
        audioOutput: AudioOutput { volume: 1.0 }
        videoOutput: videoOut

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia && root.active)
                root.handleVideoEnd()
        }
        onErrorOccurred: {
            if (root.active) root.handleVideoEnd()
        }
    }

    // ── VİZÜEL ──────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: "#05070A" }

    SharedTopBar {
        id: topBar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        guideText: {
            switch (root.phase) {
            case "call":               return "112'yi Arayın — Anafilaksi Şüphesi"
            case "epi_question":       return "Epinefrin Oto-Enjektörü Kontrolü"
            case "epi1":               return "Epinefrin Enjektörünü Uygulayın"
            case "wait":               return "Hastayı Gözlemleyin"
            case "recovered_question": return "Hasta Değerlendirmesi"
            case "epi2":               return "İkinci Doz Epinefrin Uygulayın"
            case "comfort":
            case "no_epi_comfort":     return "Hastayı Rahat Pozisyona Getirin"
            default:                   return "Anafilaksi Protokolü"
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

    // ── 30 sn bekleme ekranı ─────────────────────────────────────────────
    Rectangle {
        anchors.top: topBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        visible: root.showWaitScreen; z: 5
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0D1A2E" }
            GradientStop { position: 1.0; color: "#091222" }
        }
        Column {
            anchors.centerIn: parent; spacing: 32
            Item {
                width: 200; height: 200; anchors.horizontalCenter: parent.horizontalCenter
                Rectangle { anchors.centerIn: parent; width: 200; height: 200; radius: 100
                    color: "transparent"; border.color: "#3B82F6"; border.width: 6 }
                Rectangle { anchors.centerIn: parent; width: 160; height: 160; radius: 80; color: "#1E3A5F"
                    Text { anchors.centerIn: parent; text: root.waitSeconds
                        color: "#FFFFFF"; font.pixelSize: 64; font.bold: true } }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter
                text: "Hastayı Gözlemleyin"; color: "#FFFFFF"; font.pixelSize: 32; font.bold: true }
            Text { anchors.horizontalCenter: parent.horizontalCenter
                text: "Solunum ve bilinç durumunu izleyin"; color: "#9CA3AF"; font.pixelSize: 18 }
        }
    }

    // ── Rahat pozisyon son mesajı ─────────────────────────────────────────
    Rectangle {
        anchors.top: topBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        visible: root.showComfort; z: 5
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0D1A10" }
            GradientStop { position: 1.0; color: "#0A130C" }
        }
        Column { anchors.centerIn: parent; spacing: 24
            Rectangle { width: 110; height: 110; radius: 55; color: "#16A34A"; anchors.horizontalCenter: parent.horizontalCenter
                Text { anchors.centerIn: parent; text: "✓"; color: "white"; font.pixelSize: 56; font.bold: true } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Hastayı Rahat Pozisyona Getirin"
                color: "#FFFFFF"; font.pixelSize: 30; font.bold: true }
            Text { anchors.horizontalCenter: parent.horizontalCenter
                text: "Solunumunu ve nabzını kontrol edin\nYetkilileri bekleyin"
                color: "#9CA3AF"; font.pixelSize: 20; horizontalAlignment: Text.AlignHCenter; lineHeight: 1.5 }
            Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 20; topPadding: 10
                Rectangle { width: 220; height: 60; radius: 20; color: "#16A34A"
                    Text { anchors.centerIn: parent; text: "Ana Sayfa"; color: "#FFFFFF"; font.pixelSize: 20; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: appBridge.goHome() } }
            }
        }
    }

    // ── EpiPen var mı? popup ──────────────────────────────────────────────
    Rectangle {
        anchors.top: topBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        visible: root.showEpiPopup; color: "#7A000000"; z: 8

        Rectangle {
            width: 660; anchors.centerIn: parent
            height: epiCol.implicitHeight + 60
            radius: 30; color: "#F8FAFC"; border.color: "#D7DEE6"; border.width: 2

            Column {
                id: epiCol
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 30
                width: parent.width - 60; spacing: 28

                Text { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width
                    text: "Hastada Epinefrin oto-enjektörü (EpiPen) mevcut mu?"
                    color: "#0F172A"; font.pixelSize: 26; font.bold: true
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }

                Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 20
                    Rectangle { width: 280; height: 110; radius: 26; color: "#16A34A"
                        Text { anchors.centerIn: parent; text: "Evet, Mevcut"; color: "#FFFFFF"; font.pixelSize: 28; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: root.goPhase("epi1") } }
                    Rectangle { width: 280; height: 110; radius: 26; color: "#DC2626"
                        Text { anchors.centerIn: parent; text: "Hayır / Bilmiyorum"; color: "#FFFFFF"; font.pixelSize: 28; font.bold: true }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                noEpiVoice.play()
                                root.goPhase("no_epi_comfort")
                            }
                        } }
                }
            }
        }
    }

    // ── Hasta rahatladı mı? popup ─────────────────────────────────────────
    Rectangle {
        anchors.top: topBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        visible: root.showRecoveredPopup; color: "#7A000000"; z: 8

        Rectangle {
            width: 660; anchors.centerIn: parent
            height: recCol.implicitHeight + 60
            radius: 30; color: "#F8FAFC"; border.color: "#D7DEE6"; border.width: 2

            Column {
                id: recCol
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 30
                width: parent.width - 60; spacing: 28

                Text { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width
                    text: "Hasta rahatladı mı?"
                    color: "#0F172A"; font.pixelSize: 30; font.bold: true
                    horizontalAlignment: Text.AlignHCenter }

                Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 20
                    Rectangle { width: 280; height: 110; radius: 26; color: "#16A34A"
                        Text { anchors.centerIn: parent; text: "Evet, Rahatladı"; color: "#FFFFFF"; font.pixelSize: 28; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: root.goPhase("comfort") } }
                    Rectangle { width: 280; height: 110; radius: 26; color: "#DC2626"
                        Text { anchors.centerIn: parent; text: "Hayır, Rahatlamadı"; color: "#FFFFFF"; font.pixelSize: 28; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: root.goPhase("epi2") } }
                }
            }
        }
    }
}
