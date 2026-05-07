// BleedingArmLightScreen.qml — Kolda Hafif Kanama
import QtQuick 2.15
GuidanceVideoScreen {
    scenarioFolder: "bleeding_arm_light"
    steps: [
        {
            id: "step_cover", guideText: "Yarayı Temiz Bezle Kapatın",
            videoKey: "video_cover_wound", voiceCue: "cover_wound", autoNext: "step_press"
        },
        {
            id: "step_press", guideText: "Kanayan Bölgeye Bası Uygulayın",
            videoKey: "video_direct_press", voiceCue: "direct_press", autoNext: null,
            popup: {
                question: "Bası ile kanama durdu mu?",
                voiceCue: "q_bleeding_stopped",
                options: [
                    { text: "Evet, Durdu",     nextStepId: "step_dress"    },
                    { text: "Hayır, Sürüyor",  nextStepId: "step_escalate" }
                ]
            }
        },
        {
            id: "step_dress", guideText: "Basınçlı Sargı Yapın",
            videoKey: "video_pressure_dressing", voiceCue: "pressure_dressing", autoNext: "complete"
        },
        {
            id: "step_escalate", guideText: "Ağır Kanama Protokolü — 112'yi Arayın",
            videoKey: "video_escalate", voiceCue: "escalate", autoNext: "complete"
        }
    ]
}
