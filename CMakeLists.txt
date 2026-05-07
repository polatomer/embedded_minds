cmake_minimum_required(VERSION 3.16)
project(AKS LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Multimedia Network)
find_package(nlohmann_json REQUIRED)
find_library(GPIOD_LIB gpiod REQUIRED)

add_executable(AKS
    src/main.cpp
    src/core.cpp
    src/app_bridge.cpp
    src/cpr_controller.cpp
    src/bleeding_controller.cpp
    src/vital_signs_service.cpp
    src/max30102_sensor.cpp
    src/event_recorder.cpp
    src/voice_command_server.cpp
)

target_include_directories(AKS PRIVATE src)

target_link_libraries(AKS PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Multimedia
    Qt6::Network
    nlohmann_json::nlohmann_json
    ${GPIOD_LIB}
)

qt_add_resources(AKS "ui_resources"
    PREFIX "/"
    FILES
        ui/main.qml
        ui/HomeScreen.qml
        ui/SensorPlacementScreen.qml
        ui/ManualMeasurementScreen.qml
        ui/QuestionScreen.qml
        ui/SettingsScreen.qml
        ui/EventsScreen.qml
        ui/EventDetailScreen.qml
        ui/SharedTopBar.qml
        ui/GuidanceVideoScreen.qml
        ui/VitalAlertOverlay.qml
        ui/CPRGuidanceScreen.qml
        ui/BleedingArmHeavyScreen.qml
        ui/BleedingLegHeavyScreen.qml
        ui/BleedingBodyScreen.qml
        ui/BleedingArmLightScreen.qml
        ui/BleedingLegLightScreen.qml
        ui/AnaphylaxisGuidanceScreen.qml
        ui/StrokeGuidanceScreen.qml
        ui/AcuteCardiacGuidanceScreen.qml
        ui/RespiratoryFailureGuidanceScreen.qml
        ui/SeizureGuidanceScreen.qml
        ui/assets/bleeding/arm.png
        ui/assets/bleeding/leg.png
        ui/assets/bleeding/body.png
        ui/assets/sensor/step1.png
        ui/assets/sensor/step2.png
        ui/assets/sensor/step3.png
        ui/assets/bleeding/voice_bleeding_stopped.wav
        ui/assets/bleeding/voice_tourniquet_check.wav
        ui/assets/cpr/voice_question.wav
        ui/assets/cpr/voice_speed_up.wav
        ui/assets/cpr/voice_slow_down.wav
        ui/assets/cpr/voice_pulse_check.wav
        ui/assets/cpr/metronome_tick.wav
        ui/assets/shared/voice_vital_alert.wav
        ui/assets/respiratory/voice_q_choking.wav
        ui/assets/respiratory/voice_q_back_result.wav
        ui/assets/respiratory/voice_comfort.wav
        ui/assets/anaphylaxis/voice_q_epi_available.wav
        ui/assets/anaphylaxis/voice_q_wait.wav
        ui/assets/anaphylaxis/voice_q_recovered.wav
        ui/assets/anaphylaxis/voice_comfort_end.wav
        ui/assets/anaphylaxis/voice_no_epi.wav
        ui/assets/seizure/voice_q_seizure_ended.wav
        ui/assets/bleeding_leg_light/voice_q_bleeding_stopped.wav
        ui/assets/bleeding_body/voice_final_msg.wav
        ui/assets/gas_detector/gas_alert.wav
)
