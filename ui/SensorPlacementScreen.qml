import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    anchors.fill: parent
    clip: true

    signal backRequested()
    signal continueRequested()

    function handlePhysicalBack() {
        root.backRequested()
    }

    function handlePhysicalRotate(direction) {
    }

    function handlePhysicalPress() {
        root.autoContinued = true
        root.continueRequested()
    }

    readonly property var vs: appBridge.vitalSigns

    readonly property color bg: "#F3F5F7"
    readonly property color pageText: "#13283D"
    readonly property color subText: "#667B91"
    readonly property color lineColor: "#D9DEE5"
    readonly property color cardBg: "#FFFFFF"
    readonly property color cardBorder: "#D8DEE7"

    property bool beatAnim: false
    property bool autoContinued: false
    readonly property int autoContinueDelayMs: 1200

    function scheduleAutoContinue() {
        if (!root.visible) {
            autoContinueTimer.stop()
            return
        }

        if (vs && vs.fingerPresent && !root.autoContinued) {
            if (!autoContinueTimer.running)
                autoContinueTimer.start()
        } else {
            autoContinueTimer.stop()
            if (!vs || !vs.fingerPresent)
                root.autoContinued = false
        }
    }

    onVisibleChanged: {
        if (visible) {
            root.autoContinued = false
            root.scheduleAutoContinue()
        } else {
            autoContinueTimer.stop()
        }
    }

    Component.onCompleted: root.scheduleAutoContinue()

    readonly property int pageMargin: 10
    readonly property int headerH: 52
    readonly property int footerH: 54
    readonly property int gap: 10

    readonly property int contentTop: pageMargin + headerH + 12
    readonly property int footerTop: root.height - pageMargin - footerH
    readonly property int contentHeight: footerTop - contentTop - gap

    readonly property int leftW: 300
    readonly property int rightX: pageMargin + leftW + gap
    readonly property int rightW: root.width - rightX - pageMargin

    readonly property int topCardH: 170
    readonly property int bottomCardH: contentHeight - topCardH - gap

    readonly property int stepGap: 8
    readonly property int stepH: Math.floor((contentHeight - 2 * stepGap) / 3)

    function pulseValueText() {
        if (!vs.fingerPresent) return "--"
        if (!vs.pulseDetected) return vs.available ? "..." : "--"
        return Math.round(vs.heartRateBpm).toString()
    }

    function spo2ValueText() {
        if (!vs.fingerPresent) return "--"
        if (!vs.signalStable) return "..."
        return Math.round(vs.spo2).toString()
    }

    function signalBarColor(index) {
        var q = vs.signalQuality ? vs.signalQuality : 0
        var threshold = (index + 1) / 5.0

        if (q >= threshold) {
            if (q >= 0.8) return "#22C55E"
            if (q >= 0.5) return "#F59E0B"
            return "#EF4444"
        }
        return "#E2E8F0"
    }

    readonly property color pulseColor: {
        if (!vs.fingerPresent) return "#94A3B8"
        if (!vs.pulseDetected) return "#F59E0B"
        return "#22C55E"
    }

    readonly property color spo2Color: {
        if (!vs.fingerPresent) return "#94A3B8"
        if (!vs.signalStable) return "#94A3B8"
        if (vs.spo2 < 90) return "#EF4444"
        if (vs.spo2 < 95) return "#F59E0B"
        return "#22C55E"
    }

    Timer {
        id: beatTimer
        interval: 120
        repeat: false
        onTriggered: root.beatAnim = false
    }

    Timer {
        id: autoContinueTimer
        interval: root.autoContinueDelayMs
        repeat: false
        onTriggered: {
            if (root.visible && vs && vs.fingerPresent && !root.autoContinued) {
                root.autoContinued = true
                root.continueRequested()
            }
        }
    }

    Connections {
        target: vs

        function onChanged() {
            if (vs.pulseDetected) {
                root.beatAnim = true
                beatTimer.restart()
            }
            root.scheduleAutoContinue()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.bg
    }

    Rectangle {
        x: pageMargin
        y: pageMargin
        width: 50
        height: 50
        radius: 16
        color: "#FFFFFF"
        border.width: 3
        border.color: "#245FCE"

        Text {
            anchors.centerIn: parent
            text: "⌂"
            color: root.pageText
            font.pixelSize: 28
            font.weight: Font.Medium
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.backRequested()
        }
    }

    Text {
        x: 72
        y: 11
        text: "Sensör Yerleştirme"
        color: root.pageText
        font.pixelSize: 22
        font.weight: Font.DemiBold
    }

    Text {
        x: 72
        y: 37
        text: "Parmağınızı sensöre yerleştirin"
        color: root.subText
        font.pixelSize: 11
    }

    Rectangle {
        x: pageMargin
        y: contentTop - 8
        width: root.width - pageMargin * 2
        height: 1
        color: root.lineColor
    }

    Rectangle {
        x: pageMargin
        y: contentTop
        width: leftW
        height: topCardH
        radius: 20
        color: root.cardBg
        border.width: 1
        border.color: root.cardBorder
        clip: true

        Rectangle {
            x: 12
            y: 12
            width: 56
            height: 56
            radius: 16
            color: vs.fingerPresent ? "#F0FDF4" : "#F8FAFC"
            border.width: 1
            border.color: vs.fingerPresent ? "#BBF7D0" : root.cardBorder

            Text {
                anchors.centerIn: parent
                text: vs.fingerPresent ? "♥" : "◌"
                color: root.pulseColor
                font.pixelSize: vs.fingerPresent ? (root.beatAnim ? 30 : 26) : 24
                font.weight: Font.Bold

                Behavior on font.pixelSize {
                    NumberAnimation { duration: 100 }
                }
            }
        }

        Text {
            x: 80
            y: 14
            text: "Sensör Durumu"
            color: root.subText
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        Text {
            x: 80
            y: 32
            width: parent.width - 92
            text: vs.statusText
            color: root.pageText
            font.pixelSize: 14
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Rectangle {
            x: 12
            y: 82
            width: 94
            height: 76
            radius: 16
            color: "#F8FAFC"
            border.width: 1
            border.color: root.cardBorder

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 8
                text: "NABIZ"
                color: root.subText
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 24
                text: root.pulseValueText()
                color: root.pulseColor
                font.pixelSize: 28
                font.weight: Font.Bold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 56
                text: "bpm"
                color: root.subText
                font.pixelSize: 11
            }
        }

        Rectangle {
            x: 112
            y: 82
            width: 94
            height: 76
            radius: 16
            color: "#F8FAFC"
            border.width: 1
            border.color: root.cardBorder

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 8
                text: "SpO₂"
                color: root.subText
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 24
                text: root.spo2ValueText()
                color: root.spo2Color
                font.pixelSize: 28
                font.weight: Font.Bold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 56
                text: "%"
                color: root.subText
                font.pixelSize: 11
            }
        }

        Rectangle {
            x: 212
            y: 82
            width: 76
            height: 76
            radius: 16
            color: "#F8FAFC"
            border.width: 1
            border.color: root.cardBorder

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 8
                text: "SİNYAL"
                color: root.subText
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 28
                spacing: 3

                Repeater {
                    model: 5
                    Rectangle {
                        width: 7
                        height: 10 + index * 6
                        radius: 2
                        color: root.signalBarColor(index)
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 58
                text: Math.round((vs.signalQuality ? vs.signalQuality : 0) * 100) + "%"
                color: root.subText
                font.pixelSize: 10
            }
        }
    }

    Rectangle {
        x: pageMargin
        y: contentTop + topCardH + gap
        width: leftW
        height: bottomCardH
        radius: 20
        color: root.cardBg
        border.width: 1
        border.color: root.cardBorder
        clip: true

        Text {
            x: 14
            y: 12
            text: "Kontrol"
            color: root.pageText
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        Rectangle {
            x: 14
            y: 38
            width: parent.width - 28
            height: 1
            color: root.lineColor
        }

        Rectangle {
            x: 14
            y: 52
            width: 10
            height: 10
            radius: 5
            color: vs.fingerPresent ? "#22C55E" : "#94A3B8"
        }

        Text {
            x: 32
            y: 48
            width: parent.width - 46
            text: vs.fingerPresent ? "Parmak algılandı" : "Parmak algılanmadı"
            color: root.pageText
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }

        Rectangle {
            x: 14
            y: 80
            width: 10
            height: 10
            radius: 5
            color: vs.pulseDetected ? "#22C55E" : "#F59E0B"
        }

        Text {
            x: 32
            y: 76
            width: parent.width - 46
            text: vs.pulseDetected ? "Nabız sinyali alındı" : "Nabız sinyali bekleniyor"
            color: root.pageText
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }

        Rectangle {
            x: 14
            y: 108
            width: 10
            height: 10
            radius: 5
            color: vs.signalStable ? "#22C55E" : "#F59E0B"
        }

        Text {
            x: 32
            y: 104
            width: parent.width - 46
            text: vs.signalStable ? "SpO₂ ölçümü okunabilir" : "SpO₂ için sensörü sabit tutun"
            color: root.pageText
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }

        Rectangle {
            x: 14
            y: parent.height - 54
            width: parent.width - 28
            height: 40
            radius: 14
            color: "#EEF4FF"
            border.width: 1
            border.color: "#C6D8FF"

            Text {
                anchors.fill: parent
                anchors.margins: 10
                text: vs.fingerPresent
                      ? "Sensör algılandı. Değerlendirme otomatik başlayacak."
                      : "Sensörü takın veya aşağıdaki Devam Et butonuyla sensörsüz devam edin."
                color: "#2A67E8"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
    }

    Rectangle {
        x: rightX
        y: contentTop
        width: rightW
        height: stepH
        radius: 18
        color: root.cardBg
        border.width: 1
        border.color: root.cardBorder
        clip: true

        Rectangle {
            x: 8
            y: 8
            width: 210
            height: parent.height - 16
            radius: 14
            color: "#EAF3FF"
            border.width: 2
            border.color: "#BFD7FF"
            clip: true

            Image {
                id: img1
                anchors.fill: parent
                anchors.margins: 4
                source: "qrc:/ui/assets/sensor/step1.png"
                fillMode: Image.PreserveAspectFit
                asynchronous: false
                cache: true
                smooth: true
            }

            Text {
                anchors.centerIn: parent
                visible: img1.status !== Image.Ready
                text: "Görsel 1"
                color: "#4B6075"
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
        }

        Text {
            x: 232
            y: 18
            width: parent.width - 244
            text: "1. Parmak sensörü"
            color: root.pageText
            font.pixelSize: 16
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }

        Text {
            x: 232
            y: 46
            width: parent.width - 244
            text: "Sensörü işaret parmağına tam oturacak şekilde takın."
            color: root.subText
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }

    Rectangle {
        x: rightX
        y: contentTop + stepH + stepGap
        width: rightW
        height: stepH
        radius: 18
        color: root.cardBg
        border.width: 1
        border.color: root.cardBorder
        clip: true

        Rectangle {
            x: 8
            y: 8
            width: 210
            height: parent.height - 16
            radius: 14
            color: "#EAF3FF"
            border.width: 2
            border.color: "#BFD7FF"
            clip: true

            Image {
                id: img2
                anchors.fill: parent
                anchors.margins: 4
                source: "qrc:/ui/assets/sensor/step2.png"
                fillMode: Image.PreserveAspectFit
                asynchronous: false
                cache: true
                smooth: true
            }

            Text {
                anchors.centerIn: parent
                visible: img2.status !== Image.Ready
                text: "Görsel 2"
                color: "#4B6075"
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
        }

        Text {
            x: 232
            y: 18
            width: parent.width - 244
            text: "2. Temas kontrolü"
            color: root.pageText
            font.pixelSize: 16
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }

        Text {
            x: 232
            y: 46
            width: parent.width - 244
            text: "Kablo gevşek kalmasın. Sensör ciltle tam temas etsin."
            color: root.subText
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }

    Rectangle {
        x: rightX
        y: contentTop + (stepH + stepGap) * 2
        width: rightW
        height: stepH
        radius: 18
        color: root.cardBg
        border.width: 1
        border.color: root.cardBorder
        clip: true

        Rectangle {
            x: 8
            y: 8
            width: 210
            height: parent.height - 16
            radius: 14
            color: "#EAF3FF"
            border.width: 2
            border.color: "#BFD7FF"
            clip: true

            Image {
                id: img3
                anchors.fill: parent
                anchors.margins: 4
                source: "qrc:/ui/assets/sensor/step3.png"
                fillMode: Image.PreserveAspectFit
                asynchronous: false
                cache: true
                smooth: true
            }

            Text {
                anchors.centerIn: parent
                visible: img3.status !== Image.Ready
                text: "Görsel 3"
                color: "#4B6075"
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
        }

        Text {
            x: 232
            y: 18
            width: parent.width - 244
            text: "3. Otomatik geçiş"
            color: root.pageText
            font.pixelSize: 16
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }

        Text {
            x: 232
            y: 46
            width: parent.width - 244
            text: "Parmak algılanınca değerlendirme ekranına otomatik geçilir."
            color: root.subText
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }

    Rectangle {
        x: pageMargin
        y: footerTop
        width: root.width - pageMargin * 2
        height: footerH
        radius: 18
        color: "#245FCE"
        border.width: 0
        border.color: "transparent"

        Text {
            anchors.centerIn: parent
            text: vs.fingerPresent ? "Sensör Algılandı - Devam Et" : "Devam Et"
            color: "#FFFFFF"
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.autoContinued = true
                root.continueRequested()
            }
        }
    }
}