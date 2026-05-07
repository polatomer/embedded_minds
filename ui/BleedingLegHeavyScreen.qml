// BleedingLegHeavyScreen.qml — Bacakta Ağır Kanama
// video_call_112 → video_direct_press → popup → video_tourniquet → popup (taktın mı?)
import QtQuick 2.15

GuidanceVideoScreen {
    scenarioFolder: "bleeding_leg_heavy"

    signal tourniquetActivated2()
    onTourniquetActivated: tourniquetActivated2()

    steps: [
        {
            id:       "step_call",
            guideText:"112'yi Arayın — Bacakta Ağır Kanama",
            videoKey: "video_call_112",
            voiceCue: "",
            autoNext: "step_press"
        },
        {
            id:       "step_press",
            guideText:"Güçlü Doğrudan Bası — 3 Dakika Aralıksız",
            videoKey: "video_direct_press",
            voiceCue: "",
            autoNext: null,
            popup: {
                question: "Kanama devam ediyor mu?",
                voiceCue: "q_bleeding_continues",
                options: [
                    { text: "Evet, Devam Ediyor", nextStepId: "step_tourniquet" },
                    { text: "Hayır, Yavaşladı",   nextStepId: "complete"        }
                ]
            }
        },
        {
            id:       "step_tourniquet",
            guideText:"Turnike — Kasıktan 5 cm Uzak, Proksimal",
            videoKey: "video_tourniquet",
            voiceCue: "",
            autoNext: null,
            popup: {
                question: "Bacağa turnikeyi uyguladınız mı?",
                voiceCue: "q_tourniquet_done",
                options: [
                    { text: "Evet, Taktım",            nextStepId: "complete", action: "tourniquet" },
                    { text: "Hayır, Henüz Takmadım",   nextStepId: "step_tourniquet" }
                ]
            }
        }
    ]
}
