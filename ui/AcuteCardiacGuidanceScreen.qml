// AcuteCardiacGuidanceScreen.qml — Akut Kardiyak Olay
// video_call_112 → popup (ağrı sürüyor mu?) → video_recovery_position
import QtQuick 2.15

GuidanceVideoScreen {
    scenarioFolder: "acute_cardiac"

    steps: [
        {
            id:       "step_call",
            guideText:"112'yi Arayın — Kalp Krizi Şüphesi",
            videoKey: "video_call_112",
            voiceCue: "",
            autoNext: null,
            popup: {
                question: "Göğüs ağrısı hâlâ sürüyor mu?",
                voiceCue: "q_chest_pain",
                options: [
                    { text: "Evet, Sürüyor", nextStepId: "step_position" },
                    { text: "Hayır, Geçti",  nextStepId: "step_position" }
                ]
            }
        },
        {
            id:       "step_position",
            guideText:"Koma Pozisyonu — Yetkilileri Bekleyin",
            videoKey: "video_recovery_position",
            voiceCue: "",
            autoNext: "complete"
        }
    ]
}
