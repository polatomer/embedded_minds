import QtQuick 2.15
import QtQuick.Controls 2.15
import QtMultimedia

Item {
    id: root
    anchors.fill: parent
    clip: true

    property bool active: false
    property var bleeding: appBridge.bleedingController
    property bool voiceAckPending: false

    property int emergencyElapsedSec: 0
    property bool tourniquetActive: false
    property int tourniquetElapsedSec: 0

    property int selectedOverlayAction: 0
    property bool showTourniquetPopup: false
    property bool tourniquetCheckDone: false
    property int selectedTqOption: 0
    property bool showVideoError: false
    property string videoErrorMessage: ""

    signal backRequested()
    signal restartRequested()
    signal tourniquetActivated()

    function handlePhysicalBack() {
        root.backRequested()
    }

    function handlePhysicalRotate(direction) {
        if (direction === 0)
            return

        if (root.showTourniquetPopup) {
            selectedTqOption = (selectedTqOption === 0) ? 1 : 0
            return
        }

        if (bleeding.showDecision || bleeding.showMonitor)
            selectedOverlayAction = (selectedOverlayAction === 0) ? 1 : 0
    }

    function handlePhysicalPress() {
        if (root.showTourniquetPopup) {
            if (selectedTqOption === 0)
                onTourniquetYes()
            else
                onTourniquetNo()
            return
        }

        if (bleeding.showDecision) {
            if (selectedOverlayAction === 0)
                bleeding.choosePrimary()
            else
                bleeding.chooseSecondary()
            return
        }

        if (bleeding.showMonitor) {
            if (selectedOverlayAction === 0)
                bleeding.restart()
            else
                appBridge.goHome()
        }
    }

    function clearVideoError() {
        showVideoError = false
        videoErrorMessage = ""
    }

    function onTourniquetYes() {
        try { appBridge.eventRecorder.logDecision( "bleeding_arm", "Turnike taktınız mı?", "Evet, taktım" ) } catch(e) {}
        root.showTourniquetPopup = false
        tourniquetCheckVoice.stop()
        root.tourniquetActivated()
    }

    function onTourniquetNo() {
        try { appBridge.eventRecorder.logDecision( "bleeding_arm", "Turnike taktınız mı?", "Hayır, henüz takmadım" ) } catch(e) {}
        root.showTourniquetPopup = false
        tourniquetCheckVoice.stop()
        bleeding.restart()
    }

    function videoSourceForKey(key) {
        var base = appBridge.mediaBaseUrl
        if (!base || base === "")
            return ""

        switch (key) {
        case "press":
            return base + "/bleeding/video_press.mp4"
        case "tourniquet":
            return base + "/bleeding/video_tourniquet.mp4"
        default:
            return ""
        }
    }

    function voiceSourceForCue(cue) {
        switch (cue) {
        case "question_bleeding_stopped":
            return "qrc:/ui/assets/bleeding/voice_bleeding_stopped.wav"
        default:
            return ""
        }
    }

    function stopVideo() {
        videoPlayer.stop()
        videoPlayer.source = ""
    }

    function handleVideoCompleted() {
        clearVideoError()

        if (bleeding.videoKey === "tourniquet" && !root.tourniquetCheckDone) {
            root.tourniquetCheckDone = true
            root.showTourniquetPopup = true
            root.selectedTqOption = 0
            tourniquetCheckVoice.stop()
            tourniquetCheckVoice.play()
            try { appBridge.eventRecorder.logDecision( "bleeding_arm", "Turnike popup gösterildi", "video_bitti" ) } catch(e) {}
        } else {
            bleeding.videoFinished()
        }
    }

    function playCurrentVideo() {
        var source = videoSourceForKey(bleeding.videoKey)
        clearVideoError()

        if (!source || source === "") {
            showVideoError = true
            videoErrorMessage = "Kanama videosu yolu üretilemedi"
            return
        }

        console.log("BleedingArm video:", source)
        voiceAckPending = false
        voicePlayer.stop()
        voicePlayer.source = ""
        videoPlayer.stop()
        videoPlayer.source = ""
        videoPlayer.source = source
        videoPlayer.play()
    }

    function playCurrentVoice() {
        var src = voiceSourceForCue(bleeding.voiceCue)
        if (!src || src === "") {
            bleeding.voiceFinished()
            return
        }

        voiceAckPending = false
        voicePlayer.stop()
        voicePlayer.source = ""
        voicePlayer.source = src
        voiceAckPending = true
        voicePlayer.play()
    }

    onActiveChanged: {
        if (active) {
            tourniquetCheckDone = false
            showTourniquetPopup = false
            clearVideoError()
            bleeding.start()
        } else {
            voiceAckPending = false
            voicePlayer.stop()
            voicePlayer.source = ""
            stopVideo()
            clearVideoError()
            showTourniquetPopup = false
            tourniquetCheckVoice.stop()
            bleeding.stop()
        }
    }

    Connections {
        target: bleeding

        function onVideoSerialChanged() {
            root.playCurrentVideo()
        }

        function onVoiceSerialChanged() {
            root.playCurrentVoice()
        }
    }

    SoundEffect {
        id: tourniquetCheckVoice
        source: "qrc:/ui/assets/bleeding/voice_tourniquet_check.wav"
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
                : "Kanama videosu oynatılamadı"
            console.log("BleedingArm video error:", videoPlayer.source, root.videoErrorMessage)
        }
    }

    MediaPlayer {
        id: voicePlayer
        audioOutput: AudioOutput { volume: 1.0 }

        onPlaybackStateChanged: function(playbackState) {
            if (playbackState === MediaPlayer.StoppedState && root.voiceAckPending) {
                root.voiceAckPending = false
                bleeding.voiceFinished()
            }
        }

        onErrorOccurred: function(error, errorString) {
            if (root.voiceAckPending) {
                root.voiceAckPending = false
                bleeding.voiceFinished()
            }
            console.log("BleedingArm voice error:", voicePlayer.source, errorString)
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
        guideText: "Kolda Ağır Kanama - " + bleeding.elapsedText
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
                    text: "Kanama videosu açılamadı"
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
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: bleeding.showMonitor && !root.showTourniquetPopup
        z: 4

        onVisibleChanged: {
            if (visible)
                root.selectedOverlayAction = 0
        }

        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0E1A2B" }
            GradientStop { position: 1.0; color: "#0B1422" }
        }

        Column {
            anchors.centerIn: parent
            spacing: 30
            width: Math.min(parent.width - 80, 820)

            Item {
                width: 180
                height: 180
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: 180
                    height: 180
                    radius: 90
                    color: "transparent"
                    border.width: 3
                    border.color: "#16A34A"

                    SequentialAnimation on scale {
                        running: bleeding.showMonitor
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.92; to: 1.10; duration: 1600 }
                        NumberAnimation { from: 1.10; to: 0.92; duration: 1600 }
                    }

                    SequentialAnimation on opacity {
                        running: bleeding.showMonitor
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.9; to: 0.3; duration: 1600 }
                        NumberAnimation { from: 0.3; to: 0.9; duration: 1600 }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 110
                    height: 110
                    radius: 55
                    color: "#16A34A"
                    Text {
                        anchors.centerIn: parent
                        text: "♥"
                        color: "#FFFFFF"
                        font.pixelSize: 54
                        font.bold: true
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                text: bleeding.monitorText
                color: "#FFFFFF"
                font.pixelSize: 34
                font.bold: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.25
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Rectangle {
                    width: 220
                    height: 60
                    radius: 20
                    color: "#1F2937"
                    border.color: root.selectedOverlayAction === 0 ? "#60A5FA" : "#334155"
                    border.width: root.selectedOverlayAction === 0 ? 3 : 1
                    Text {
                        anchors.centerIn: parent
                        text: "Yeniden Başlat"
                        color: "#FFFFFF"
                        font.pixelSize: 20
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: bleeding.restart()
                    }
                }

                Rectangle {
                    width: 220
                    height: 60
                    radius: 20
                    color: "#16A34A"
                    border.color: root.selectedOverlayAction === 1 ? "#FFFFFF" : "#15803D"
                    border.width: root.selectedOverlayAction === 1 ? 3 : 1
                    Text {
                        anchors.centerIn: parent
                        text: "Ana Sayfa"
                        color: "#FFFFFF"
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

    Rectangle {
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: bleeding.showDecision && !root.showTourniquetPopup
        color: "#7A000000"
        z: 5

        onVisibleChanged: {
            if (visible)
                root.selectedOverlayAction = 0
            else {
                voiceAckPending = false
                voicePlayer.stop()
                voicePlayer.source = ""
            }
        }

        Rectangle {
            width: 680
            height: 300
            anchors.centerIn: parent
            radius: 30
            color: "#F8FAFC"
            border.color: "#D7DEE6"
            border.width: 2

            Column {
                anchors.centerIn: parent
                spacing: 26
                width: parent.width - 60

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    text: bleeding.questionText
                    color: "#0F172A"
                    font.pixelSize: 30
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 24

                    Rectangle {
                        width: 270
                        height: 110
                        radius: 26
                        color: "#16A34A"
                        border.color: root.selectedOverlayAction === 0 ? "#0F172A" : "transparent"
                        border.width: root.selectedOverlayAction === 0 ? 4 : 0
                        Text {
                            anchors.centerIn: parent
                            text: bleeding.primaryActionText
                            color: "#FFFFFF"
                            font.pixelSize: 34
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: bleeding.choosePrimary()
                        }
                    }

                    Rectangle {
                        width: 270
                        height: 110
                        radius: 26
                        color: "#DC2626"
                        border.color: root.selectedOverlayAction === 1 ? "#0F172A" : "transparent"
                        border.width: root.selectedOverlayAction === 1 ? 4 : 0
                        Text {
                            anchors.centerIn: parent
                            text: bleeding.secondaryActionText
                            color: "#FFFFFF"
                            font.pixelSize: 34
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: bleeding.chooseSecondary()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.showTourniquetPopup
        color: "#7A000000"
        z: 6

        Rectangle {
            width: 680
            height: 280
            anchors.centerIn: parent
            radius: 30
            color: "#F8FAFC"
            border.color: "#DC2626"
            border.width: 2

            Column {
                anchors.centerIn: parent
                width: parent.width - 60
                spacing: 26

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    text: "Üst kola turnikeyi uyguladınız mı?"
                    color: "#0F172A"
                    font.pixelSize: 30
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 24

                    Rectangle {
                        width: 270
                        height: 110
                        radius: 26
                        color: "#16A34A"
                        border.color: root.selectedTqOption === 0 ? "#0F172A" : "transparent"
                        border.width: root.selectedTqOption === 0 ? 4 : 0
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Evet, Taktım"
                                color: "#FFFFFF"
                                font.pixelSize: 30
                                font.bold: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Sayaç başlar"
                                color: "#D1FAE5"
                                font.pixelSize: 14
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.onTourniquetYes()
                        }
                    }

                    Rectangle {
                        width: 270
                        height: 110
                        radius: 26
                        color: "#DC2626"
                        border.color: root.selectedTqOption === 1 ? "#0F172A" : "transparent"
                        border.width: root.selectedTqOption === 1 ? 4 : 0
                        Text {
                            anchors.centerIn: parent
                            text: "Hayır, Henüz\nTakmadım"
                            color: "#FFFFFF"
                            font.pixelSize: 28
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.onTourniquetNo()
                        }
                    }
                }
            }
        }
    }
}
