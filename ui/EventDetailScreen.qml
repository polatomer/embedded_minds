import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia

Item {
    id: root
    anchors.fill: parent
    clip: true

    property string eventId: ""
    property bool active: false
    property var rec: appBridge.eventRecorder

    property var eventData: null
    property var segments: []
    property var vitals: []
    property var questions: []
    property var decisions: []
    property var guidance: null
    property int durationSec: 0

    property int currentSegmentIndex: 0
    property int segmentLengthSec: 60
    property int currentEventSec: 0
    property bool isPlaying: false

    signal backRequested()

    property int selectedControl: 0

    function handlePhysicalBack() {
        root.backRequested()
    }

    function handlePhysicalRotate(direction) {
        const maxControl = (segments && segments.length > 0) ? 3 : 0
        if (direction > 0 && selectedControl < maxControl)
            selectedControl += 1
        else if (direction < 0 && selectedControl > 0)
            selectedControl -= 1
    }

    function handlePhysicalPress() {
        switch (selectedControl) {
        case 0:
            root.backRequested()
            break
        case 1:
            if (segments && segments.length > 0)
                root.togglePlay()
            break
        case 2:
            if (root.currentSegmentIndex > 0)
                root.loadSegment(root.currentSegmentIndex - 1)
            break
        case 3:
            if (root.currentSegmentIndex + 1 < root.segments.length)
                root.loadSegment(root.currentSegmentIndex + 1)
            break
        }
    }

    function load() {
        if (!eventId || eventId === "")
            return

        eventData = rec.loadEvent(eventId)
        segments = eventData.segments || []
        vitals = eventData.vitals || []
        questions = eventData.questions || []
        decisions = eventData.decisions || []
        guidance = eventData.guidance || null
        durationSec = eventData.durationSec || 0

        currentSegmentIndex = 0
        currentEventSec = 0
        loadSegment(0)
    }

    function unload() {
        videoPlayer.stop()
        videoPlayer.source = ""
        isPlaying = false
    }

    function loadSegment(idx) {
        if (!segments || segments.length === 0) {
            videoPlayer.stop()
            videoPlayer.source = ""
            return
        }
        if (idx < 0 || idx >= segments.length)
            return

        currentSegmentIndex = idx
        currentEventSec = idx * segmentLengthSec

        videoPlayer.stop()
        videoPlayer.source = ""
        videoPlayer.source = segments[idx]
        videoPlayer.play()
        isPlaying = true
    }

    function togglePlay() {
        if (videoPlayer.playbackState === MediaPlayer.PlayingState) {
            videoPlayer.pause()
            isPlaying = false
        } else {
            videoPlayer.play()
            isPlaying = true
        }
    }

    function updateEventTime() {
        const posSec = Math.floor((videoPlayer.position || 0) / 1000)
        currentEventSec = currentSegmentIndex * segmentLengthSec + posSec
    }

    function currentVitals() {
        if (!vitals || vitals.length === 0)
            return null

        let pulse = -1
        let spo2 = -1
        let foundAny = false

        for (var i = 0; i < vitals.length; i++) {
            var v = vitals[i]

            if (v.t > currentEventSec)
                break

            foundAny = true

            if (v.pulse !== undefined && v.pulse >= 0)
                pulse = v.pulse

            if (v.spo2 !== undefined && v.spo2 >= 0)
                spo2 = v.spo2
        }

        if (!foundAny) {
            for (var j = 0; j < vitals.length; j++) {
                var first = vitals[j]
                if ((first.pulse !== undefined && first.pulse >= 0) ||
                    (first.spo2 !== undefined && first.spo2 >= 0)) {
                    return {
                        pulse: (first.pulse !== undefined ? first.pulse : -1),
                        spo2: (first.spo2 !== undefined ? first.spo2 : -1)
                    }
                }
            }
            return null
        }

        return {
            pulse: pulse,
            spo2: spo2
        }
    }

    function formatMs(totalSec) {
        const m = Math.floor(totalSec / 60)
        const s = totalSec % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    onActiveChanged: {
        if (active) {
            selectedControl = 0
            load()
        } else {
            unload()
        }
    }

    onEventIdChanged: {
        if (active) {
            unload()
            load()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#05070A"
    }

    MediaPlayer {
        id: videoPlayer
        audioOutput: AudioOutput { volume: 1.0 }
        videoOutput: videoOutput

        onPositionChanged: root.updateEventTime()

        onPlaybackStateChanged: {
            root.isPlaying = (playbackState === MediaPlayer.PlayingState)
        }

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia) {
                if (root.currentSegmentIndex + 1 < root.segments.length) {
                    root.loadSegment(root.currentSegmentIndex + 1)
                } else {
                    root.isPlaying = false
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            color: "#141A20"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 10

                Rectangle {
                    width: 50
                    height: 38
                    radius: 10
                    color: "#1F2730"
                    border.color: root.selectedControl === 0 ? "#60A5FA" : "#2D3844"
                    border.width: root.selectedControl === 0 ? 3 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        color: "#FFFFFF"
                        font.pixelSize: 28
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.backRequested()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: eventData ? eventData.date : ""
                        color: "#FFFFFF"
                        font.pixelSize: 15
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: (guidance && guidance.diagnosis)
                              ? guidance.diagnosis
                              : "(Yönlendirme yok)"
                        color: "#9CA3AF"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    width: 100
                    height: 38
                    radius: 10
                    color: "#1B232B"
                    border.color: "#2D3844"
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "♥"
                            color: "#FF5A6B"
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: {
                                const v = root.currentVitals()
                                if (!v || v.pulse < 0)
                                    return "--"
                                return v.pulse
                            }
                            color: "#FFFFFF"
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }
                }

                Rectangle {
                    width: 100
                    height: 38
                    radius: 10
                    color: "#1B232B"
                    border.color: "#2D3844"
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "O₂"
                            color: "#67E8F9"
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Text {
                            text: {
                                const v = root.currentVitals()
                                if (!v || v.spo2 < 0)
                                    return "--"
                                return v.spo2 + "%"
                            }
                            color: "#FFFFFF"
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                Layout.preferredWidth: parent.width * 0.58
                Layout.fillHeight: true

                VideoOutput {
                    id: videoOutput
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectFit
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#0F172A"
                    visible: !segments || segments.length === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "🎥"
                            color: "#475569"
                            font.pixelSize: 40
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Video kaydı yok"
                            color: "#94A3B8"
                            font.pixelSize: 14
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 40
                    color: "#CC000000"
                    visible: segments && segments.length > 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        Rectangle {
                            width: 36
                            height: 28
                            radius: 8
                            color: "#1E40AF"
                            border.color: root.selectedControl === 1 ? "#FFFFFF" : "transparent"
                            border.width: root.selectedControl === 1 ? 2 : 0

                            Text {
                                anchors.centerIn: parent
                                text: root.isPlaying ? "⏸" : "▶"
                                color: "#FFFFFF"
                                font.pixelSize: 14
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.togglePlay()
                            }
                        }

                        Rectangle {
                            width: 36
                            height: 28
                            radius: 8
                            color: "#374151"
                            border.color: root.selectedControl === 2 ? "#60A5FA" : "transparent"
                            border.width: root.selectedControl === 2 ? 2 : 0
                            opacity: root.currentSegmentIndex > 0 ? 1.0 : 0.4

                            Text {
                                anchors.centerIn: parent
                                text: "⏮"
                                color: "#FFFFFF"
                                font.pixelSize: 14
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (root.currentSegmentIndex > 0)
                                        root.loadSegment(root.currentSegmentIndex - 1)
                                }
                            }
                        }

                        Rectangle {
                            width: 36
                            height: 28
                            radius: 8
                            color: "#374151"
                            border.color: root.selectedControl === 3 ? "#60A5FA" : "transparent"
                            border.width: root.selectedControl === 3 ? 2 : 0
                            opacity: root.currentSegmentIndex + 1 < root.segments.length ? 1.0 : 0.4

                            Text {
                                anchors.centerIn: parent
                                text: "⏭"
                                color: "#FFFFFF"
                                font.pixelSize: 14
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (root.currentSegmentIndex + 1 < root.segments.length)
                                        root.loadSegment(root.currentSegmentIndex + 1)
                                }
                            }
                        }

                        Text {
                            text: root.formatMs(root.currentEventSec) + " / "
                                  + root.formatMs(root.durationSec)
                            color: "#FFFFFF"
                            font.pixelSize: 12
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "Seg " + (root.currentSegmentIndex + 1)
                                  + "/" + root.segments.length
                            color: "#9CA3AF"
                            font.pixelSize: 11
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#0F172A"

                ListView {
                    id: timelineView
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    spacing: 6

                    ScrollBar.vertical: ScrollBar {}

                    model: {
                        var arr = []
                        for (var i = 0; i < root.questions.length; i++) {
                            var q = root.questions[i]
                            arr.push({ t: q.t, kind: "question", a: q.a, b: q.q })
                        }
                        for (var k = 0; k < root.decisions.length; k++) {
                            var d = root.decisions[k]
                            arr.push({ t: d.t, kind: "decision", a: d.a, b: d.q })
                        }
                        if (root.guidance && root.guidance.diagnosis) {
                            arr.push({
                                t: root.guidance.t,
                                kind: "guidance",
                                a: root.guidance.diagnosis,
                                b: root.guidance.screen
                            })
                        }
                        arr.sort(function(x, y) { return x.t - y.t })
                        return arr
                    }

                    delegate: Rectangle {
                        width: timelineView.width
                        height: bodyCol.implicitHeight + 16
                        radius: 10
                        color: "#1E293B"
                        border.color: "#334155"
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Rectangle {
                                width: 6
                                height: parent.height - 4
                                radius: 3
                                color: modelData.kind === "guidance" ? "#10B981"
                                     : modelData.kind === "decision" ? "#F59E0B"
                                     : "#3B82F6"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                id: bodyCol
                                width: parent.width - 20
                                spacing: 2

                                Row {
                                    spacing: 6

                                    Text {
                                        text: root.formatMs(modelData.t)
                                        color: "#9CA3AF"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    Text {
                                        text: modelData.kind === "guidance" ? "YÖNLENDİRME"
                                             : modelData.kind === "decision" ? "KARAR"
                                             : "SORU"
                                        color: modelData.kind === "guidance" ? "#10B981"
                                             : modelData.kind === "decision" ? "#F59E0B"
                                             : "#3B82F6"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.b || ""
                                    color: "#CBD5E1"
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    width: parent.width
                                    text: "▶ " + (modelData.a || "")
                                    color: "#F1F5F9"
                                    font.pixelSize: 12
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                const segIdx = Math.floor(modelData.t / root.segmentLengthSec)
                                const posInSeg = modelData.t % root.segmentLengthSec
                                if (segIdx < root.segments.length) {
                                    root.loadSegment(segIdx)
                                    videoPlayer.position = posInSeg * 1000
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}