import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    id: window
    visible: true
    width: 800
    height: 480
    minimumWidth: 800
    maximumWidth: 800
    minimumHeight: 480
    maximumHeight: 480
    title: "Akıllı Sağlık Çantası"

    property string errorText: ""
    property bool showSensorPlacement: false
    property bool showManualMeasurement: false
    property string openEventId: ""

    property int emergencyElapsedSec: 0
    property bool tourniquetActive: false
    property int tourniquetElapsedSec: 0

    Timer {
        interval: 1000
        repeat: true
        running: appBridge.screen !== "home"
                 && appBridge.screen !== "settings"
                 && appBridge.screen !== "records"
                 && appBridge.screen !== "event_detail"
                 && !window.showSensorPlacement
                 && !window.showManualMeasurement
        onTriggered: window.emergencyElapsedSec++
    }

    Timer {
        interval: 1000
        repeat: true
        running: window.tourniquetActive
        onTriggered: window.tourniquetElapsedSec++
    }

    function activateTourniquet() {
        if (window.tourniquetActive)
            return

        window.tourniquetActive = true
        window.tourniquetElapsedSec = 0
        try { appBridge.eventRecorder.logDecision("tourniquet", "Turnike aktivasyonu", "basladi") } catch(e) {}
    }

    function screenIndex(name) {
        if (showSensorPlacement) return 1
        if (showManualMeasurement) return 2
        if (name === "question") return 3
        if (name === "settings") return 4
        if (name === "cpr") return 5
        if (name === "massive_bleeding" || name === "gd_bleeding_arm_heavy" || name === "bleeding_arm_heavy") return 6
        if (name === "bleeding_leg_heavy" || name === "gd_bleeding_leg_heavy") return 7
        if (name === "bleeding_body_heavy" || name === "gd_bleeding_body_heavy") return 8
        if (name === "bleeding_body_light"  || name === "gd_bleeding_body_light")  return 8
        if (name === "bleeding_arm_light" || name === "gd_bleeding_arm_light") return 9
        if (name === "bleeding_leg_light" || name === "gd_bleeding_leg_light") return 10
        if (name === "anaphylaxis" || name === "gd_anaphylaxis") return 11
        if (name === "stroke" || name === "gd_stroke") return 12
        if (name === "acute_cardiac_event" || name === "gd_acute_cardiac_event") return 13
        if (name === "respiratory_failure" || name === "gd_respiratory_failure" || name === "low_spo2") return 14
        if (name === "seizure_emergency" || name === "gd_seizure_emergency") return 15
        if (name === "unknown_result") return 16
        if (name === "records") return 17
        if (name === "event_detail") return 18
        return 0
    }

    readonly property bool guidanceActive:
        !showSensorPlacement
        && !showManualMeasurement
        && appBridge.screen !== "home"
        && appBridge.screen !== "question"
        && appBridge.screen !== "settings"
        && appBridge.screen !== "records"
        && appBridge.screen !== "event_detail"
        && appBridge.screen !== ""

    function routeUiBack() {
        if (showSensorPlacement) {
            sensorPlacementScreen.handlePhysicalBack()
            return
        }

        if (showManualMeasurement) {
            manualMeasurementScreen.handlePhysicalBack()
            return
        }

        switch (appBridge.screen) {
        case "settings":
            settingsScreen.handlePhysicalBack()
            break
        case "cpr":
            cprScreen.handlePhysicalBack()
            break
        case "massive_bleeding":
        case "gd_bleeding_arm_heavy":
        case "bleeding_arm_heavy":
            bleedingArmScreen.handlePhysicalBack()
            break
        case "bleeding_leg_heavy":
        case "gd_bleeding_leg_heavy":
            bleedingLegScreen.handlePhysicalBack()
            break
        case "bleeding_body_heavy":
        case "gd_bleeding_body_heavy":
        case "bleeding_body_light":
        case "gd_bleeding_body_light":
            bleedingBodyScreen.handlePhysicalBack()
            break
        case "bleeding_arm_light":
        case "gd_bleeding_arm_light":
            bleedingArmLightScreen.handlePhysicalBack()
            break
        case "bleeding_leg_light":
        case "gd_bleeding_leg_light":
            bleedingLegLightScreen.handlePhysicalBack()
            break
        case "anaphylaxis":
        case "gd_anaphylaxis":
            anaphylaxisScreen.handlePhysicalBack()
            break
        case "stroke":
        case "gd_stroke":
            strokeScreen.handlePhysicalBack()
            break
        case "acute_cardiac_event":
        case "gd_acute_cardiac_event":
            cardiacScreen.handlePhysicalBack()
            break
        case "respiratory_failure":
        case "gd_respiratory_failure":
        case "low_spo2":
            respiratoryScreen.handlePhysicalBack()
            break
        case "seizure_emergency":
        case "gd_seizure_emergency":
            seizureScreen.handlePhysicalBack()
            break
        case "records":
            eventsScreen.handlePhysicalBack()
            break
        case "event_detail":
            eventDetailScreen.handlePhysicalBack()
            break
        default:
            appBridge.goHome()
            break
        }
    }

    function routeUiPress() {
        if (showSensorPlacement) {
            sensorPlacementScreen.handlePhysicalPress()
            return
        }

        if (showManualMeasurement) {
            manualMeasurementScreen.handlePhysicalPress()
            return
        }

        switch (appBridge.screen) {
        case "home":
            homeScreen.handlePhysicalPress()
            break
        case "settings":
            settingsScreen.handlePhysicalPress()
            break
        case "cpr":
            cprScreen.handlePhysicalPress()
            break
        case "massive_bleeding":
        case "gd_bleeding_arm_heavy":
        case "bleeding_arm_heavy":
            bleedingArmScreen.handlePhysicalPress()
            break
        case "bleeding_leg_heavy":
        case "gd_bleeding_leg_heavy":
            bleedingLegScreen.handlePhysicalPress()
            break
        case "bleeding_body_heavy":
        case "gd_bleeding_body_heavy":
        case "bleeding_body_light":
        case "gd_bleeding_body_light":
            bleedingBodyScreen.handlePhysicalPress()
            break
        case "bleeding_arm_light":
        case "gd_bleeding_arm_light":
            bleedingArmLightScreen.handlePhysicalPress()
            break
        case "bleeding_leg_light":
        case "gd_bleeding_leg_light":
            bleedingLegLightScreen.handlePhysicalPress()
            break
        case "anaphylaxis":
        case "gd_anaphylaxis":
            anaphylaxisScreen.handlePhysicalPress()
            break
        case "stroke":
        case "gd_stroke":
            strokeScreen.handlePhysicalPress()
            break
        case "acute_cardiac_event":
        case "gd_acute_cardiac_event":
            cardiacScreen.handlePhysicalPress()
            break
        case "respiratory_failure":
        case "gd_respiratory_failure":
        case "low_spo2":
            respiratoryScreen.handlePhysicalPress()
            break
        case "seizure_emergency":
        case "gd_seizure_emergency":
            seizureScreen.handlePhysicalPress()
            break
        case "records":
            eventsScreen.handlePhysicalPress()
            break
        case "event_detail":
            eventDetailScreen.handlePhysicalPress()
            break
        default:
            break
        }
    }

    function routeUiRotate(direction) {
        if (showSensorPlacement) {
            sensorPlacementScreen.handlePhysicalRotate(direction)
            return
        }

        if (showManualMeasurement) {
            manualMeasurementScreen.handlePhysicalRotate(direction)
            return
        }

        switch (appBridge.screen) {
        case "home":
            homeScreen.handlePhysicalRotate(direction)
            break
        case "settings":
            settingsScreen.handlePhysicalRotate(direction)
            break
        case "cpr":
            cprScreen.handlePhysicalRotate(direction)
            break
        case "massive_bleeding":
        case "gd_bleeding_arm_heavy":
        case "bleeding_arm_heavy":
            bleedingArmScreen.handlePhysicalRotate(direction)
            break
        case "bleeding_leg_heavy":
        case "gd_bleeding_leg_heavy":
            bleedingLegScreen.handlePhysicalRotate(direction)
            break
        case "bleeding_body_heavy":
        case "gd_bleeding_body_heavy":
        case "bleeding_body_light":
        case "gd_bleeding_body_light":
            bleedingBodyScreen.handlePhysicalRotate(direction)
            break
        case "bleeding_arm_light":
        case "gd_bleeding_arm_light":
            bleedingArmLightScreen.handlePhysicalRotate(direction)
            break
        case "bleeding_leg_light":
        case "gd_bleeding_leg_light":
            bleedingLegLightScreen.handlePhysicalRotate(direction)
            break
        case "anaphylaxis":
        case "gd_anaphylaxis":
            anaphylaxisScreen.handlePhysicalRotate(direction)
            break
        case "stroke":
        case "gd_stroke":
            strokeScreen.handlePhysicalRotate(direction)
            break
        case "acute_cardiac_event":
        case "gd_acute_cardiac_event":
            cardiacScreen.handlePhysicalRotate(direction)
            break
        case "respiratory_failure":
        case "gd_respiratory_failure":
        case "low_spo2":
            respiratoryScreen.handlePhysicalRotate(direction)
            break
        case "seizure_emergency":
        case "gd_seizure_emergency":
            seizureScreen.handlePhysicalRotate(direction)
            break
        case "records":
            eventsScreen.handlePhysicalRotate(direction)
            break
        case "event_detail":
            eventDetailScreen.handlePhysicalRotate(direction)
            break
        default:
            break
        }
    }

    background: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#F8FBFF" }
            GradientStop { position: 1.0; color: "#EEF4FB" }
        }
    }

    Dialog {
        id: errorDialog
        modal: true
        title: appBridge.language === "tr" ? "Hata" : "Error"
        standardButtons: Dialog.Ok
        anchors.centerIn: parent
        width: 420

        contentItem: Label {
            text: window.errorText
            wrapMode: Text.WordWrap
            color: "#24364B"
            padding: 14
            font.pixelSize: 18
        }
    }

    Connections {
        target: appBridge

        function onErrorOccurred(message) {
            window.errorText = message
            errorDialog.open()
        }

        function onScreenChanged() {
            if (appBridge.screen === "home") {
                window.emergencyElapsedSec = 0
                window.tourniquetActive = false
                window.tourniquetElapsedSec = 0
            }

            if (appBridge.screen !== "home") {
                window.showSensorPlacement = false
                window.showManualMeasurement = false
            }
        }

        function onUiBackRequested() {
            window.routeUiBack()
        }

        function onUiEncoderPressed() {
            window.routeUiPress()
        }

        function onUiEncoderRotated(direction) {
            window.routeUiRotate(direction)
        }
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: window.screenIndex(appBridge.screen)

        HomeScreen {
            id: homeScreen
            onStartRequested: {
                window.showManualMeasurement = false
                window.showSensorPlacement = true
            }
            onManualRequested: {
                window.showSensorPlacement = false
                window.showManualMeasurement = true
            }
            onSettingsRequested: {
                window.showSensorPlacement = false
                window.showManualMeasurement = false
                appBridge.openSettings()
            }
            onRecordsRequested: {
                window.showSensorPlacement = false
                window.showManualMeasurement = false
                appBridge.openRecords()
            }
        }

        SensorPlacementScreen {
            id: sensorPlacementScreen
            onBackRequested: {
                window.showSensorPlacement = false
                window.showManualMeasurement = false
            }
            onContinueRequested: {
                window.showSensorPlacement = false
                appBridge.startEmergency()
            }
        }

        ManualMeasurementScreen {
            id: manualMeasurementScreen
            onBackRequested: {
                window.showManualMeasurement = false
            }
        }

        QuestionScreen {
            screenTitle: appBridge.language === "tr" ? "Acil Değerlendirme" : "Emergency Assessment"
            screenSubtitle: appBridge.language === "tr" ? "Soruyu dikkatle yanıtlayın" : "Answer carefully"
            questionText: appBridge.currentQuestionText
            answersModel: appBridge.currentAnswerItems
            selectedAnswerIndex: appBridge.selectedAnswerIndex
            onBackRequested: appBridge.previousQuestion()
            onAnswerSelected: function(i) { appBridge.submitAnswer(i) }
        }

        SettingsScreen {
            id: settingsScreen
            selectedLanguage: appBridge.language
            onBackRequested: {
                window.showSensorPlacement = false
                window.showManualMeasurement = false
                appBridge.goHome()
            }
            onLanguageSelected: function(code) { appBridge.language = code }
        }

        CPRGuidanceScreen {
            id: cprScreen
            active: appBridge.screen === "cpr"
            diagnosisText: appBridge.finalDiagnosis
            emergencyElapsedSec: window.emergencyElapsedSec
            tourniquetActive: window.tourniquetActive
            tourniquetElapsedSec: window.tourniquetElapsedSec
            onBackRequested: appBridge.goHome()
            onRestartRequested: {}
        }

        BleedingArmHeavyScreen {
            id: bleedingArmScreen
            active: appBridge.screen === "massive_bleeding" || appBridge.screen === "gd_bleeding_arm_heavy" || appBridge.screen === "bleeding_arm_heavy"
            emergencyElapsedSec: window.emergencyElapsedSec
            tourniquetActive: window.tourniquetActive
            tourniquetElapsedSec: window.tourniquetElapsedSec
            onBackRequested: appBridge.goHome()
            onRestartRequested: {}
            onTourniquetActivated: window.activateTourniquet()
        }

        BleedingLegHeavyScreen {
            id: bleedingLegScreen
            active: appBridge.screen === "bleeding_leg_heavy" || appBridge.screen === "gd_bleeding_leg_heavy"
            emergencyElapsedSec: window.emergencyElapsedSec
            tourniquetActive: window.tourniquetActive
            tourniquetElapsedSec: window.tourniquetElapsedSec
            onBackRequested: appBridge.goHome()
            onTourniquetActivated2: window.activateTourniquet()
        }

        // Vücut kanaması — tek ekran (hafif + ağır)
        BleedingBodyScreen {
            id: bleedingBodyScreen
            active: appBridge.screen === "bleeding_body_heavy" || appBridge.screen === "gd_bleeding_body_heavy"
                 || appBridge.screen === "bleeding_body_light"  || appBridge.screen === "gd_bleeding_body_light"
            emergencyElapsedSec:  window.emergencyElapsedSec
            tourniquetActive:     window.tourniquetActive
            tourniquetElapsedSec: window.tourniquetElapsedSec
            onBackRequested:      appBridge.goHome()
        }

        BleedingArmLightScreen {
            id: bleedingArmLightScreen
            active: appBridge.screen === "bleeding_arm_light" || appBridge.screen === "gd_bleeding_arm_light"
            emergencyElapsedSec:  window.emergencyElapsedSec
            tourniquetActive:     window.tourniquetActive
            tourniquetElapsedSec: window.tourniquetElapsedSec
            onBackRequested:      appBridge.goHome()
        }

        BleedingLegLightScreen {
            id: bleedingLegLightScreen
            active: appBridge.screen === "bleeding_leg_light" || appBridge.screen === "gd_bleeding_leg_light"
            emergencyElapsedSec:  window.emergencyElapsedSec
            tourniquetActive:     window.tourniquetActive
            tourniquetElapsedSec: window.tourniquetElapsedSec
            onBackRequested:      appBridge.goHome()
            onStepActionTriggered: function(action) {
                if (action === "escalate_leg") appBridge.setScreen("bleeding_leg_heavy")
            }
        }

        AnaphylaxisGuidanceScreen {
            id: anaphylaxisScreen
            active: appBridge.screen === "anaphylaxis" || appBridge.screen === "gd_anaphylaxis"
            emergencyElapsedSec: window.emergencyElapsedSec
            tourniquetActive: window.tourniquetActive
            tourniquetElapsedSec: window.tourniquetElapsedSec
            onBackRequested: appBridge.goHome()
        }

        StrokeGuidanceScreen {
            id: strokeScreen
            active: appBridge.screen === "stroke" || appBridge.screen === "gd_stroke"
            emergencyElapsedSec: window.emergencyElapsedSec
            tourniquetActive: window.tourniquetActive
            tourniquetElapsedSec: window.tourniquetElapsedSec
            onBackRequested: appBridge.goHome()
        }

        AcuteCardiacGuidanceScreen {
            id: cardiacScreen
            active: appBridge.screen === "acute_cardiac_event" || appBridge.screen === "gd_acute_cardiac_event"
            emergencyElapsedSec: window.emergencyElapsedSec
            tourniquetActive: window.tourniquetActive
            tourniquetElapsedSec: window.tourniquetElapsedSec
            onBackRequested: appBridge.goHome()
        }

        RespiratoryFailureGuidanceScreen {
            id: respiratoryScreen
            active: appBridge.screen === "respiratory_failure" || appBridge.screen === "gd_respiratory_failure" || appBridge.screen === "low_spo2"
            emergencyElapsedSec: window.emergencyElapsedSec
            tourniquetActive: window.tourniquetActive
            tourniquetElapsedSec: window.tourniquetElapsedSec
            onBackRequested: appBridge.goHome()
        }

        SeizureGuidanceScreen {
            id: seizureScreen
            active: appBridge.screen === "seizure_emergency" || appBridge.screen === "gd_seizure_emergency"
            emergencyElapsedSec: window.emergencyElapsedSec
            tourniquetActive: window.tourniquetActive
            tourniquetElapsedSec: window.tourniquetElapsedSec
            onBackRequested: appBridge.goHome()
        }

        Rectangle {
            color: "#05070A"

            Column {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    text: "Değerlendirme Tamamlandı"
                    color: "#FFFFFF"
                    font.pixelSize: 28
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: appBridge.finalDiagnosis
                    color: "#9CA3AF"
                    font.pixelSize: 18
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    width: 220
                    height: 60
                    radius: 20
                    color: "#16A34A"
                    anchors.horizontalCenter: parent.horizontalCenter

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

        EventsScreen {
            id: eventsScreen
            active: appBridge.screen === "records"
            onBackRequested: appBridge.goHome()
            onEventOpened: function(eventId) {
                window.openEventId = eventId
                appBridge.openEventDetail(eventId)
            }
        }

        EventDetailScreen {
            id: eventDetailScreen
            active: appBridge.screen === "event_detail"
            eventId: window.openEventId
            onBackRequested: appBridge.openRecords()
        }
    }

    VitalAlertOverlay {
        monitoringActive: window.guidanceActive

        onNavigateToCpr: {
            try { appBridge.eventRecorder.logGuidance("cpr", "vital_alert_nabiz") } catch(e) {}
            appBridge.navigateToCpr()
        }

        onNavigateToRespiratory: {
            try { appBridge.eventRecorder.logGuidance("low_spo2", "vital_alert_spo2") } catch(e) {}
            appBridge.navigateToLowSpo2()
        }
    }
}
