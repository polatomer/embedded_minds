import QtQuick 2.15
import QtQuick.Controls 2.15
import QtMultimedia

Item {
    id: root
    anchors.fill: parent
    clip: true

    property bool active: false
    property string diagnosisText: ""
    property var cpr: appBridge.cprController

    property int emergencyElapsedSec: 0
    property bool tourniquetActive: false
    property int tourniquetElapsedSec: 0

    property int selectedDecision: 0
    property bool showPulseCheckPopup: false
    property bool pulseCheckDone: false
    property bool showVideoError: false
    property string videoErrorMessage: ""

    signal backRequested()
    signal restartRequested()

    function handlePhysicalBack() {
        root.backRequested()
    }

    function handlePhysicalRotate(direction) {
        if (root.showPulseCheckPopup) {
            if (direction !== 0)
                selectedDecision = (selectedDecision === 0) ? 1 : 0
            return
        }

        if (!cpr.showDecision || direction === 0)
            return

        selectedDecision = (selectedDecision === 0) ? 1 : 0
    }

    function handlePhysicalPress() {
        if (root.showPulseCheckPopup) {
            if (selectedDecision === 0)
                onPulsePresent()
            else
                onPulseAbsent()
            return
        }

        if (!cpr.showDecision)
            return

        if (selectedDecision === 0)
            cpr.choosePrimary()
        else
            cpr.chooseSecondary()
    }

    function clearVideoError() {
        showVideoError = false
        videoErrorMessage = ""
    }

    function pulseIsNormal() {
        var vs = appBridge.vitalSigns
        if (!vs.fingerPresent || !vs.pulseDetected)
            return false
        if (vs.signalQuality <= 50)
            return false
        var bpm = vs.heartRateBpm
        return bpm >= 45 && bpm <= 135
    }

    function handleVideoCompleted() {
        clearVideoError()

        if (cpr.videoKey === "call112") {
            onCall112VideoEnd()
            return
        }

        cpr.videoFinished()
    }

    function onCall112VideoEnd() {
        if (pulseCheckDone) {
            cpr.videoFinished()
            return
        }

        pulseCheckDone = true

        if (pulseIsNormal()) {
            root.showPulseCheckPopup = true
            selectedDecision = 0
            pulseCheckVoice.stop()
            pulseCheckVoice.play()
            try { appBridge.eventRecorder.logDecision( "cpr", "Nabız kontrol popup gösterildi", "nabiz_normal_gorunuyor" ) } catch(e) {}
        } else {
            cpr.videoFinished()
        }
    }

    function onPulsePresent() {
        try { appBridge.eventRecorder.logDecision( "cpr", "Nabız ve solunum var mı?", "Evet, nabız ve solunum var" ) } catch(e) {}

        root.showPulseCheckPopup = false
        pulseCheckVoice.stop()
        stopAllVoices()
        stopVideo()
        cpr.stop()
        appBridge.restartQuestionsKeepRecording()
    }

    function onPulseAbsent() {
        try { appBridge.eventRecorder.logDecision( "cpr", "Nabız ve solunum var mı?", "Hayır, nabız ve solunum yok" ) } catch(e) {}

        root.showPulseCheckPopup = false
        pulseCheckVoice.stop()
        cpr.videoFinished()
    }

    function videoSourceForKey(key) {
        var base = appBridge.mediaBaseUrl
        if (!base || base === "")
            return ""

        switch (key) {
        case "call112":
            return base + "/cpr/video_112.mp4"
        case "intro":
            return base + "/cpr/video_intro.mp4"
        case "loop":
            return base + "/cpr/video_cpr_loop.mp4"
        case "recovery":
            return base + "/cpr/video_recovery.mp4"
        default:
            return ""
        }
    }

    function stopAllVoices() {
        questionVoice.stop()
        speedUpVoice.stop()
        slowDownVoice.stop()
    }

    function playVoiceCue(cue) {
        stopAllVoices()

        switch (cue) {
        case "question":
            questionVoice.play()
            break
        case "speed_up":
            speedUpVoice.play()
            break
        case "slow_down":
            slowDownVoice.play()
            break
        default:
            break
        }
    }

    function stopVideo() {
        videoPlayer.stop()
        videoPlayer.source = ""
    }

    function playCurrentVideo() {
        var source = videoSourceForKey(cpr.videoKey)
        clearVideoError()

        if (!source || source === "") {
            showVideoError = true
            videoErrorMessage = "CPR video yolu üretilemedi"
            return
        }

        console.log("CPR video:", source)
        stopAllVoices()
        videoPlayer.stop()
        videoPlayer.source = ""
        videoPlayer.source = source
        videoPlayer.play()
    }

    onActiveChanged: {
        if (active) {
            pulseCheckDone = false
            showPulseCheckPopup = false
            selectedDecision = 0
            clearVideoError()
            cpr.start()
        } else {
            showPulseCheckPopup = false
            pulseCheckDone = false
            clearVideoError()
            stopAllVoices()
            pulseCheckVoice.stop()
            stopVideo()
            cpr.stop()
        }
    }

    Connections {
        target: cpr

        function onVideoSerialChanged() {
            root.playCurrentVideo()
        }

        function onVoiceSerialChanged() {
            root.playVoiceCue(cpr.voiceCue)
        }
    }

    SoundEffect {
        id: pulseCheckVoice
        source: "qrc:/ui/assets/cpr/voice_pulse_check.wav"
        volume: 1.0
    }

    SoundEffect {
        id: questionVoice
        source: "qrc:/ui/assets/cpr/voice_question.wav"
        volume: 1.0
    }

    SoundEffect {
        id: speedUpVoice
        source: "qrc:/ui/assets/cpr/voice_speed_up.wav"
        volume: 1.0
    }

    SoundEffect {
        id: slowDownVoice
        source: "qrc:/ui/assets/cpr/voice_slow_down.wav"
        volume: 1.0
    }

    MediaPlayer {
        id: videoPlayer
        audioOutput: AudioOutput { volume: 1.0 }
        videoOutput: videoOutput

        onMediaStatusChanged: function(mediaStatus) {
            if (mediaStatus === MediaPlayer.EndOfMedia)
                root.handleVideoCompleted()
        }

        onErrorOccurred: function(error, errorString) {
            if (!root.active)
                return
            root.showVideoError = true
            root.videoErrorMessage = errorString && errorString !== ""
                ? errorString
                : "CPR videosu oynatılamadı"
            console.log("CPR video error:", videoPlayer.source, root.videoErrorMessage)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#05070A"
    }

    SharedTopBar {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        guideText: root.diagnosisText !== "" ? root.diagnosisText : "Kardiyak Arrest - TYD"
        emergencyElapsedSec: root.emergencyElapsedSec
        tourniquetActive: root.tourniquetActive
        tourniquetElapsedSec: root.tourniquetElapsedSec
        onBackClicked: root.backRequested()
    }

    VideoOutput {
        id: videoOutput
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        fillMode: VideoOutput.PreserveAspectCrop
    }

    Rectangle {
        anchors.fill: videoOutput
        visible: root.showVideoError
        color: "#CC000000"
        z: 7

        Rectangle {
            width: 680
            height: contentCol.implicitHeight + 40
            anchors.centerIn: parent
            radius: 28
            color: "#F8FAFC"
            border.color: "#DC2626"
            border.width: 2

            Column {
                id: contentCol
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 24
                width: parent.width - 48
                spacing: 18

                Text {
                    width: parent.width
                    text: "CPR videosu açılamadı"
                    color: "#991B1B"
                    font.pixelSize: 30
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: root.videoErrorMessage
                    color: "#334155"
                    font.pixelSize: 18
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: String(videoPlayer.source)
                    color: "#64748B"
                    font.pixelSize: 14
                    wrapMode: Text.WrapAnywhere
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    Rectangle {
                        width: 220
                        height: 58
                        radius: 18
                        color: "#1D4ED8"
                        Text {
                            anchors.centerIn: parent
                            text: "Videoyu Atla"
                            color: "white"
                            font.pixelSize: 20
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.handleVideoCompleted()
                        }
                    }

                    Rectangle {
                        width: 220
                        height: 58
                        radius: 18
                        color: "#16A34A"
                        Text {
                            anchors.centerIn: parent
                            text: "Ana Sayfa"
                            color: "white"
                            font.pixelSize: 20
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: appBridge.goHome()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: videoOutput
        visible: cpr.showDecision && !root.showPulseCheckPopup
        color: "#7A000000"
        z: 5

        onVisibleChanged: {
            if (visible)
                root.selectedDecision = 0
            else
                questionVoice.stop()
        }

        Rectangle {
            width: 620
            height: 250
            anchors.centerIn: parent
            radius: 30
            color: "#F8FAFC"
            border.color: "#D7DEE6"
            border.width: 2

            Row {
                anchors.centerIn: parent
                spacing: 24

                Rectangle {
                    width: 270
                    height: 110
                    radius: 26
                    color: "#16A34A"
                    border.color: root.selectedDecision === 0 ? "#0F172A" : "transparent"
                    border.width: root.selectedDecision === 0 ? 4 : 0
                    Text {
                        anchors.centerIn: parent
                        text: cpr.primaryActionText
                        color: "#FFFFFF"
                        font.pixelSize: 34
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: cpr.choosePrimary()
                    }
                }

                Rectangle {
                    width: 270
                    height: 110
                    radius: 26
                    color: "#0F172A"
                    border.color: root.selectedDecision === 1 ? "#16A34A" : "transparent"
                    border.width: root.selectedDecision === 1 ? 4 : 0
                    Text {
                        anchors.centerIn: parent
                        text: cpr.secondaryActionText
                        color: "#FFFFFF"
                        font.pixelSize: 30
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: cpr.chooseSecondary()
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: videoOutput
        visible: root.showPulseCheckPopup
        color: "#7A000000"
        z: 6

        Rectangle {
            width: 680
            height: 320
            anchors.centerIn: parent
            radius: 30
            color: "#F8FAFC"
            border.color: "#2563EB"
            border.width: 2

            Column {
                anchors.centerIn: parent
                width: parent.width - 60
                spacing: 26

                Text {
                    width: parent.width
                    text: "Fiziksel kontrol yapın"
                    color: "#0F172A"
                    font.pixelSize: 32
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: "Sensöre göre nabız görünüyor. Hastanın nabzı ve solunumu gerçekten var mı?"
                    color: "#334155"
                    font.pixelSize: 22
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 24

                    Rectangle {
                        width: 270
                        height: 110
                        radius: 26
                        color: "#16A34A"
                        border.color: root.selectedDecision === 0 ? "#0F172A" : "transparent"
                        border.width: root.selectedDecision === 0 ? 4 : 0
                        Text {
                            anchors.centerIn: parent
                            text: "Evet, Var"
                            color: "#FFFFFF"
                            font.pixelSize: 30
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.onPulsePresent()
                        }
                    }

                    Rectangle {
                        width: 270
                        height: 110
                        radius: 26
                        color: "#DC2626"
                        border.color: root.selectedDecision === 1 ? "#0F172A" : "transparent"
                        border.width: root.selectedDecision === 1 ? 4 : 0
                        Text {
                            anchors.centerIn: parent
                            text: "Hayır, Yok"
                            color: "#FFFFFF"
                            font.pixelSize: 30
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.onPulseAbsent()
                        }
                    }
                }
            }
        }
    }
}
