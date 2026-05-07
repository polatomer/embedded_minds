// BleedingBodyHeavyScreen.qml — Vücutta Ağır Kanama
// Klinik: PHTLS 10th Ed. Torso Hemorrhage — TURNİKE UYGULANAMAZ
// Adımlar: 112 → Güçlü bası → [Kontrol altında mı?] → Tamponad → [Şok var mı?] → İzle
import QtQuick 2.15
GuidanceVideoScreen {
    scenarioFolder: "bleeding_body_heavy"
    steps: [
        {
            id: "step_call", guideText: "112'yi Arayın — Vücutta Ağır Kanama",
            videoKey: "video_call_112", voiceCue: "call_112", autoNext: "step_press"
        },
        {
            id: "step_press", guideText: "Mümkün Olan En Güçlü Basıyı Uygulayın",
            videoKey: "video_direct_press", voiceCue: "direct_press", autoNext: null,
            popup: {
                question: "Güçlü bası ile kanama yavaşladı mı?",
                voiceCue: "q_bleeding_controlled",
                options: [
                    { text: "Evet, Yavaşladı",  nextStepId: "step_monitor" },
                    { text: "Hayır, Sürüyor",    nextStepId: "step_packing" }
                ]
            }
        },
        {
            id: "step_packing", guideText: "Yara Tamponadı — Yarayı Gazlı Bezle Doldurun",
            videoKey: "video_wound_packing", voiceCue: "wound_packing", autoNext: "step_pack_press"
        },
        {
            id: "step_pack_press", guideText: "Tamponat Üzerine 3 Dakika Sürekli Bası",
            videoKey: "video_pack_press", voiceCue: "pack_press", autoNext: null,
            popup: {
                question: "Hastada şok belirtisi var mı?\n(Solukluk · Soğuk terleme · Zayıf nabız)",
                voiceCue: "q_shock_signs",
                options: [
                    { text: "Evet, Var",  nextStepId: "step_shock_pos" },
                    { text: "Hayır, Yok", nextStepId: "step_monitor"   }
                ]
            }
        },
        {
            id: "step_shock_pos", guideText: "Şok Pozisyonu — Bacakları Kaldırın, Isıtın",
            videoKey: "video_shock_position", voiceCue: "shock_position", autoNext: "step_monitor"
        },
        {
            id: "step_monitor", guideText: "112 Ekibini Bekleyin — Hastayı İzleyin",
            videoKey: "video_monitor", voiceCue: "monitor", autoNext: "complete"
        }
    ]
}
