// RespiratoryFailureGuidanceScreen.qml — Solunum Yetmezliği / Boğulma
// video_call_112 → boğuluyor mu? → Evet: sırta vurma → soru → Heimlich → döngü
//                                 → Hayır: koma pozisyonu
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
    property bool showChokingPopup: false
    property bool showBackPopup:    false
    property bool showSidePopup:    false
    property bool showComfort:      false

    signal backRequested()
    function handlePhysicalBack()   { root.backRequested() }
    function handlePhysicalRotate() {}
    function handlePhysicalPress()  {}

    // ── Sesli komut ──────────────────────────────────────────────────────────
    // showChokingPopup: Evet=back_blows  Hayır=recovery
    // showBackPopup:    Evet=recovery    Hayır=heimlich
    function voiceYes() {
        if (root.showChokingPopup) { root.goPhase("back_blows"); return }
        if (root.showBackPopup)    { root.goPhase("recovery") }
    }
    function voiceNo() {
        if (root.showChokingPopup) { root.goPhase("recovery"); return }
        if (root.showBackPopup)    { root.goPhase("heimlich") }
    }


    function videoUrl(key) {
        return appBridge.mediaBaseUrl + "/respiratory/" + key + ".mp4"
    }

    function playVideo(key) {
        videoPlayer.stop()
        videoPlayer.source = ""
        videoPlayer.source = videoUrl(key)
        videoPlayer.play()
    }

    function goPhase(p) {
        phase            = p
        showChokingPopup = false
        showBackPopup    = false
        showSidePopup    = false
        showComfort      = false

        switch (p) {
        case "call":
            playVideo("video_call_112")
            break
        case "choking_question":
            showChokingPopup = true
            chokingVoice.stop()
            chokingVoice.play()
            break
        case "back_blows":
            playVideo("video_back_blows")
            break
        case "back_question":
            showBackPopup = true
            backQuestionVoice.stop()
            backQuestionVoice.play()
            break
        case "heimlich":
            playVideo("video_heimlich")
            break
        case "heimlich_loop":
            showSidePopup = true
            playVideo("video_heimlich")
            break
        case "recovery":
            showSidePopup = false
            playVideo("video_recovery_position")
            break
        case "comfort":
            videoPlayer.stop()
            showComfort = true
            comfortVoice.stop()
            comfortVoice.play()
            break
        }
    }

    onActiveChanged: {
        if (active) {
            goPhase("call")
        } else {
            videoPlayer.stop()
            videoPlayer.source = ""
            phase = "idle"
            showChokingPopup = false
            showBackPopup    = false
            showSidePopup    = false
            showComfort      = false
        }
    }

    SoundEffect { id: chokingVoice;      source: "qrc:/ui/assets/respiratory/voice_q_choking.wav";     volume: 1.0 }
    SoundEffect { id: backQuestionVoice; source: "qrc:/ui/assets/respiratory/voice_q_back_result.wav"; volume: 1.0 }
    SoundEffect { id: comfortVoice;      source: "qrc:/ui/assets/respiratory/voice_comfort.wav";        volume: 1.0 }

    MediaPlayer {
        id: videoPlayer
        audioOutput: AudioOutput { volume: 1.0 }
        videoOutput: videoOut

        onMediaStatusChanged: {
            if (mediaStatus !== MediaPlayer.EndOfMedia || !root.active) return

            switch (root.phase) {
            case "call":
                root.goPhase("choking_question")
                break
            case "back_blows":
                root.goPhase("back_question")
                break
            case "heimlich":
                root.goPhase("heimlich_loop")
                break
            case "heimlich_loop":
                // Döngü — popup açıkken video tekrar oyna
                videoPlayer.stop()
                videoPlayer.source = ""
                videoPlayer.source = root.videoUrl("video_heimlich")
                videoPlayer.play()
                break
            case "recovery":
                root.goPhase("comfort")
                break
            }
        }

        onErrorOccurred: {
            if (root.active) root.goPhase("comfort")
        }
    }

    // ── VİZÜEL ──────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: "#05070A" }

    SharedTopBar {
        id: topBar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        guideText: {
            switch (root.phase) {
            case "call":          return "112'yi Arayın"
            case "back_blows":    return "Sırtına 5 Kez Vurun"
            case "heimlich":
            case "heimlich_loop": return "Heimlich Manevrası"
            case "recovery":      return "Koma Pozisyonu"
            case "comfort":       return "Hastayı İzleyin"
            default:              return "Boğulma / Solunum Acili"
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

    // Rahat pozisyon son ekranı
    Rectangle {
        anchors.top: topBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        visible: root.showComfort; z: 6
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0D1A10" }
            GradientStop { position: 1.0; color: "#0A130C" }
        }
        Column {
            anchors.centerIn: parent; spacing: 24
            Rectangle {
                width: 110; height: 110; radius: 55; color: "#16A34A"
                anchors.horizontalCenter: parent.horizontalCenter
                Text { anchors.centerIn: parent; text: "✓"; color: "white"; font.pixelSize: 56; font.bold: true }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Hastayı Rahat Pozisyona Getirin"
                color: "#FFFFFF"; font.pixelSize: 30; font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Solunumunu ve nabzını kontrol edin\nYetkilileri bekleyin"
                color: "#9CA3AF"; font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter; lineHeight: 1.5
            }
        }
    }

    // "Hasta boğuluyor mu?" popup
    Rectangle {
        anchors.top: topBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        visible: root.showChokingPopup; color: "#7A000000"; z: 5

        Rectangle {
            width: 660; anchors.centerIn: parent
            height: cCol.implicitHeight + 60
            radius: 30; color: "#F8FAFC"; border.color: "#D7DEE6"; border.width: 2

            Column {
                id: cCol
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 30
                width: parent.width - 60; spacing: 28

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter; width: parent.width
                    text: "Hasta boğulur gibi mi yapıyor?\n(Soluk alamıyor, konuşamıyor, öksüremiyor)"
                    color: "#0F172A"; font.pixelSize: 26; font.bold: true
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 20
                    Rectangle {
                        width: 280; height: 110; radius: 26; color: "#16A34A"
                        Text { anchors.centerIn: parent; text: "Evet, Boğuluyor"; color: "#FFFFFF"; font.pixelSize: 28; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: root.goPhase("back_blows") }
                    }
                    Rectangle {
                        width: 280; height: 110; radius: 26; color: "#1D4ED8"
                        Text { anchors.centerIn: parent; text: "Hayır, Boğulmuyor"; color: "#FFFFFF"; font.pixelSize: 28; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: root.goPhase("recovery") }
                    }
                }
            }
        }
    }

    // "Rahatladı mı?" popup (sırt vuruşu sonrası)
    Rectangle {
        anchors.top: topBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        visible: root.showBackPopup; color: "#7A000000"; z: 5

        Rectangle {
            width: 660; anchors.centerIn: parent
            height: bCol.implicitHeight + 60
            radius: 30; color: "#F8FAFC"; border.color: "#D7DEE6"; border.width: 2

            Column {
                id: bCol
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 30
                width: parent.width - 60; spacing: 28

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter; width: parent.width
                    text: "Hasta rahatladı mı?\n(Nefes alıyor veya öksürebiliyor)"
                    color: "#0F172A"; font.pixelSize: 26; font.bold: true
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 20
                    Rectangle {
                        width: 280; height: 110; radius: 26; color: "#16A34A"
                        Text { anchors.centerIn: parent; text: "Evet, Rahatladı"; color: "#FFFFFF"; font.pixelSize: 28; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: root.goPhase("recovery") }
                    }
                    Rectangle {
                        width: 280; height: 110; radius: 26; color: "#DC2626"
                        Text { anchors.centerIn: parent; text: "Hayır, Devam Ediyor"; color: "#FFFFFF"; font.pixelSize: 28; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: root.goPhase("heimlich") }
                    }
                }
            }
        }
    }

    // Döngü içi sağ popup — sadece "Düzeldi" butonu
    Rectangle {
        anchors.top:    topBar.bottom
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        width: 260
        visible: root.showSidePopup; z: 7
        color: "transparent"

        Rectangle {
            anchors.centerIn: parent
            width: 230; height: 200; radius: 24
            color: "#F8FAFC"; border.color: "#D7DEE6"; border.width: 2

            Column {
                anchors.centerIn: parent; spacing: 16
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter; width: 190
                    text: "Hasta düzeldi mi?"
                    color: "#0F172A"; font.pixelSize: 20; font.bold: true
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                }
                Rectangle {
                    width: 190; height: 80; radius: 20; color: "#16A34A"
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text { anchors.centerIn: parent; text: "Evet, Düzeldi"; color: "#FFFFFF"; font.pixelSize: 22; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: root.goPhase("recovery") }
                }
            }
        }
    }
}
