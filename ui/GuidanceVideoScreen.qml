// GuidanceVideoScreen.qml — v4
// stepActionTriggered sinyali eklendi — action:"escalate_leg" gibi özel geçişler için.
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtMultimedia

Item {
    id: root
    anchors.fill: parent
    clip: true

    property bool   active:         false
    property string scenarioFolder: ""
    property var    steps:          []

    property int  emergencyElapsedSec:  0
    property bool tourniquetActive:     false
    property int  tourniquetElapsedSec: 0
    property int  selectedOption:       0
    property int  currentStepIdx:       -1
    property bool showPopup:            false
    property bool isCompleted:          false
    property bool voiceAckPending:      false
    property bool showVideoError:       false
    property string videoErrorMessage:  ""

    signal backRequested()
    signal tourniquetActivated()
    signal stepActionTriggered(string action)   // ← YENİ

    readonly property var currentStep:
        (currentStepIdx >= 0 && currentStepIdx < steps.length)
        ? steps[currentStepIdx] : null

    readonly property string currentGuideText:
        currentStep ? currentStep.guideText
                    : (isCompleted ? "Protokol Tamamlandı" : "Hazırlanıyor...")

    function handlePhysicalBack()              { root.backRequested() }
    function handlePhysicalRotate(direction) {
        if (!showPopup || !currentStep || !currentStep.popup) return
        var count = currentStep.popup.options.length
        if (count < 2) return
        if (direction > 0)      selectedOption = Math.min(selectedOption + 1, count - 1)
        else if (direction < 0) selectedOption = Math.max(selectedOption - 1, 0)
    }
    function handlePhysicalPress() { if (showPopup) chooseOption(selectedOption) }

    function clearVideoError() { showVideoError = false; videoErrorMessage = "" }

    function videoUrl(key) {
        var base = appBridge.mediaBaseUrl
        if (!base || !key || key === "") return ""
        return base + "/" + root.scenarioFolder + "/" + key + ".mp4"
    }
    function voiceUrl(cue) {
        if (!cue || cue === "") return ""
        return "qrc:/ui/assets/" + root.scenarioFolder + "/voice_" + cue + ".wav"
    }
    function stopVideo() { videoPlayer.stop(); videoPlayer.source = "" }
    function stopVoice() { voiceAckPending = false; voicePlayer.stop(); voicePlayer.source = "" }

    function playVideo(key) {
        var src = videoUrl(key)
        clearVideoError(); stopVoice()
        videoPlayer.stop(); videoPlayer.source = ""
        if (!src || src === "") { showVideoError = true; videoErrorMessage = "Video bulunamadı: " + key; return }
        videoPlayer.source = src; videoPlayer.play()
    }
    function playVoice(cue) {
        var src = voiceUrl(cue)
        voicePlayer.stop(); voicePlayer.source = ""
        if (!src || src === "") { voiceAckPending = false; return }
        voicePlayer.source = src; voiceAckPending = true; voicePlayer.play()
    }

    function findStepIdx(stepId) {
        for (var i = 0; i < steps.length; i++)
            if (steps[i].id === stepId) return i
        return -1
    }

    function startStep(idx) {
        if (idx < 0 || idx >= steps.length) { isCompleted = true; return }
        currentStepIdx = idx; showPopup = false; selectedOption = 0; clearVideoError()
        var key = steps[idx].videoKey
        if (key === undefined || key === null || key === "") { Qt.callLater(onVideoEnd); return }
        playVideo(key)
    }

    function onVideoEnd() {
        clearVideoError()
        if (!currentStep || isCompleted) return
        if (currentStep.popup) {
            showPopup = true; selectedOption = 0
            playVoice(currentStep.popup.voiceCue || "")
        } else if (currentStep.autoNext && currentStep.autoNext !== "") {
            if (currentStep.autoNext === "complete") { isCompleted = true; return }
            var idx = findStepIdx(currentStep.autoNext)
            startStep(idx >= 0 ? idx : currentStepIdx + 1)
        } else {
            isCompleted = true
        }
    }

    function chooseOption(optIdx) {
        if (!currentStep || !currentStep.popup) return
        var opt = currentStep.popup.options[optIdx]
        if (!opt) return

        try { appBridge.eventRecorder.logDecision(root.scenarioFolder, currentStep.popup.question, opt.text) } catch(e) {}

        // Özel eylemler
        if (opt.action === "tourniquet")    { root.tourniquetActivated() }
        if (opt.action === "cpr")           { showPopup = false; stopVoice(); appBridge.navigateToCpr(); return }

        // Özel geçiş eylemleri — ekrana özgü
        if (opt.action && opt.action !== "tourniquet" && opt.action !== "cpr") {
            showPopup = false; stopVoice(); clearVideoError()
            root.stepActionTriggered(opt.action)
            return
        }

        showPopup = false; stopVoice(); clearVideoError()

        if (!opt.nextStepId || opt.nextStepId === "complete") { isCompleted = true; return }
        var idx2 = findStepIdx(opt.nextStepId)
        startStep(idx2 >= 0 ? idx2 : currentStepIdx + 1)
    }

    function restart() {
        isCompleted = false; showPopup = false; currentStepIdx = -1; selectedOption = 0
        clearVideoError(); stopVideo(); stopVoice(); startStep(0)
    }

    onActiveChanged: {
        if (active) {
            isCompleted = false; showPopup = false; currentStepIdx = -1; selectedOption = 0
            clearVideoError(); startStep(0)
        } else {
            stopVideo(); stopVoice(); clearVideoError()
            showPopup = false; isCompleted = false; currentStepIdx = -1
        }
    }

    MediaPlayer {
        id: videoPlayer
        audioOutput: AudioOutput { volume: 1.0 }
        videoOutput: videoOut

        onMediaStatusChanged: function(mediaStatus) {
            if (mediaStatus === MediaPlayer.EndOfMedia) root.onVideoEnd()
        }
        onErrorOccurred: function(error, errorString) {
            // Video bulunamazsa akış durmasın, bir sonraki adıma geç
            root.clearVideoError()
            if (root.active) root.onVideoEnd()
        }
    }

    MediaPlayer {
        id: voicePlayer
        audioOutput: AudioOutput { volume: 1.0 }

        onPlaybackStateChanged: function(state) {
            if (state === MediaPlayer.StoppedState && root.voiceAckPending)
                root.voiceAckPending = false
        }
        onErrorOccurred: function(error, errorString) {
            root.voiceAckPending = false
        }
    }

    Rectangle { anchors.fill: parent; color: "#05070A" }

    SharedTopBar {
        id: topBar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        guideText:            root.currentGuideText
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

    // Video hata overlay
    Rectangle {
        anchors.top: topBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        visible: root.showVideoError && !root.isCompleted; color: "#CC000000"; z: 6
        Rectangle {
            width: 680; anchors.centerIn: parent; height: errC.implicitHeight + 40
            radius: 28; color: "#F8FAFC"; border.color: "#DC2626"; border.width: 2
            Column { id: errC; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 24; width: parent.width - 48; spacing: 18
                Text { width: parent.width; text: "Video açılamadı"; color: "#991B1B"; font.pixelSize: 30; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                Text { width: parent.width; text: root.videoErrorMessage; color: "#334155"; font.pixelSize: 18; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter }
                Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 16
                    Rectangle { width: 220; height: 58; radius: 18; color: "#1D4ED8"
                        Text { anchors.centerIn: parent; text: "Videoyu Atla"; color: "white"; font.pixelSize: 20; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: root.onVideoEnd() } }
                    Rectangle { width: 220; height: 58; radius: 18; color: "#16A34A"
                        Text { anchors.centerIn: parent; text: "Ana Sayfa"; color: "white"; font.pixelSize: 20; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: appBridge.goHome() } }
                }
            }
        }
    }

    // Tamamlandı
    Rectangle {
        anchors.top: topBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        visible: root.isCompleted; z: 4
        gradient: Gradient { GradientStop { position: 0.0; color: "#0D1A10" } GradientStop { position: 1.0; color: "#0A130C" } }
        Column { anchors.centerIn: parent; spacing: 24
            Rectangle { width: 110; height: 110; radius: 55; color: "#16A34A"; anchors.horizontalCenter: parent.horizontalCenter
                Text { anchors.centerIn: parent; text: "✓"; color: "white"; font.pixelSize: 56; font.bold: true } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Protokol Tamamlandı"; color: "#FFFFFF"; font.pixelSize: 30; font.bold: true }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "112 ekibini bekleyin ve hastayı izleyin"; color: "#9CA3AF"; font.pixelSize: 18 }
            Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 20
                Rectangle { width: 220; height: 60; radius: 20; color: "#1F2937"; border.color: "#334155"; border.width: 1
                    Text { anchors.centerIn: parent; text: "Yeniden Başlat"; color: "#FFFFFF"; font.pixelSize: 20; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: root.restart() } }
                Rectangle { width: 220; height: 60; radius: 20; color: "#16A34A"
                    Text { anchors.centerIn: parent; text: "Ana Sayfa"; color: "#FFFFFF"; font.pixelSize: 20; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: appBridge.goHome() } }
            }
        }
    }

    // Popup
    Rectangle {
        anchors.top: topBar.bottom; anchors.left: parent.left
        anchors.right: parent.right; anchors.bottom: parent.bottom
        visible: root.showPopup; color: "#7A000000"; z: 8
        onVisibleChanged: { if (!visible) root.stopVoice(); else root.selectedOption = 0 }
        Rectangle {
            width: 680; anchors.centerIn: parent; height: popC.implicitHeight + 60
            radius: 30; color: "#F8FAFC"; border.color: "#D7DEE6"; border.width: 2
            Column {
                id: popC; anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 30; width: parent.width - 60; spacing: 28
                Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 8; visible: root.voiceAckPending
                    Rectangle { width: 12; height: 12; radius: 6; color: "#3B82F6"
                        SequentialAnimation on opacity { running: root.voiceAckPending; loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.2; duration: 500 }
                            NumberAnimation { from: 0.2; to: 1.0; duration: 500 } } }
                    Text { text: "Ses çalınıyor..."; color: "#3B82F6"; font.pixelSize: 14 }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width
                    text: (root.currentStep && root.currentStep.popup) ? root.currentStep.popup.question : ""
                    color: "#0F172A"; font.pixelSize: 28; font.bold: true
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
                Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 20
                    Repeater {
                        model: (root.currentStep && root.currentStep.popup) ? root.currentStep.popup.options : []
                        Rectangle {
                            width: 280; height: 110; radius: 26
                            color: index === 0 ? "#16A34A" : "#DC2626"
                            border.color: root.selectedOption === index ? "#0F172A" : "transparent"; border.width: root.selectedOption === index ? 4 : 0
                            Text { anchors.centerIn: parent; width: parent.width - 24; text: modelData.text
                                color: "#FFFFFF"; font.pixelSize: 30; font.bold: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
                            MouseArea { anchors.fill: parent; onClicked: root.chooseOption(index) }
                        }
                    }
                }
            }
        }
    }
}
