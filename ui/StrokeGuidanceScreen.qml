// StrokeGuidanceScreen.qml — İnme
// video_call_112 → popup (süre?) → video_shock_position → izle
import QtQuick 2.15

GuidanceVideoScreen {
    scenarioFolder: "stroke"

    steps: [
        {
            id:       "step_call",
            guideText:"112'yi Arayın — İnme Şüphesi",
            videoKey: "video_call_112",
            voiceCue: "",
            autoNext: null,
            popup: {
                question: "Belirtiler ne zaman başladı?",
                voiceCue: "q_time_window",
                options: [
                    { text: "4.5 Saatten Az",         nextStepId: "step_position" },
                    { text: "4.5+ Saat / Bilinmiyor", nextStepId: "step_position" }
                ]
            }
        },
        {
            id:       "step_position",
            guideText:"Hastayı Pozisyonlayın — Yetkilileri Bekleyin",
            videoKey: "video_shock_position",
            voiceCue: "",
            autoNext: "complete"
        }
    ]
}
