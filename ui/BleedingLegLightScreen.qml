// BleedingLegLightScreen.qml — Bacakta Hafif Kanama
// video_call_112 → video_direct_press → popup → durdu: tamamlandı / durmadı: ağır ekrana
import QtQuick 2.15

GuidanceVideoScreen {
    scenarioFolder: "bleeding_leg_light"

    steps: [
        {
            id:       "step_call",
            guideText:"112'yi Arayın",
            videoKey: "video_call_112",
            voiceCue: "",
            autoNext: "step_press"
        },
        {
            id:       "step_press",
            guideText:"Kanayan Bölgeye Bası Uygulayın",
            videoKey: "video_direct_press",
            voiceCue: "",
            autoNext: null,
            popup: {
                question: "Kanama durdu mu?",
                voiceCue: "q_bleeding_stopped",
                options: [
                    { text: "Evet, Durdu",    nextStepId: "complete"                      },
                    { text: "Hayır, Sürüyor", nextStepId: "complete", action: "escalate_leg" }
                ]
            }
        }
    ]

    onStepActionTriggered: function(action) {
        if (action === "escalate_leg") {
            try { appBridge.eventRecorder.logDecision( "bleeding_leg_light", "Kanama durdu mu?", "Hayir - agir protokole gecis" ) } catch(e) {}
            appBridge.setScreen("bleeding_leg_heavy")
        }
    }
}
