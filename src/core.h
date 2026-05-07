#pragma once

#include <optional>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

// =========================
// Temel veri yapilari
// =========================

struct Answer
{
    std::string id;
    std::unordered_map<std::string, std::string> text; // tr,en
    std::string image;                                  // qrc:/... veya bos
    std::unordered_map<std::string, int> scores;       // diagnosis/event puanlari
};

struct Question
{
    std::string id;
    std::unordered_map<std::string, std::string> text; // tr,en
    std::unordered_map<std::string, std::string> hint; // tr,en — kullaniciya kontrol talimatı

    // Kucuk order daha once sorulur
    int order = 0;

    // Bu soru ancak belirli bir onceki soruya belirli cevap verildiyse acilir.
    std::optional<std::string> requires_question_id;
    std::optional<std::string> requires_answer_id;

    std::vector<Answer> answers;
};

struct Diagnosis
{
    std::string id;
    std::unordered_map<std::string, std::string> name; // tr,en

    // Bu puana ulasinca olay esigi dolmus sayilir
    int min_score = 0;

    // Ayni anda birden fazla aday varsa buyuk priority kazanir
    int priority = 0;

    // true ise min_score doldugu anda akisi bitir
    // false ise tum sorular tamamlanana kadar devam et
    bool early_finish = false;

    // Sonucta hangi ozel QML ekrani acilacak
    std::string screen_id;

    // Ileride ek protokol / aktif davranis konfigi icin
    std::string protocol_id;
};

struct QuestionHistoryEntry
{
    std::string question_id;
    std::string answer_id;
};

// =========================
// Runtime / Oturum verisi
// =========================

struct Session
{
    // kullanicinin verdigi cevaplar
    std::unordered_map<std::string, std::string> answers;

    // hesaplanan puanlar
    std::unordered_map<std::string, int> diagnosis_scores;

    // tekrar sormamak icin
    std::unordered_set<std::string> asked_questions;

    // geri gitme icin cevap gecmisi
    std::vector<QuestionHistoryEntry> history;

    // secili dil
    std::string language = "tr";

    // oturum durumu
    bool finished = false;
    std::optional<std::string> final_diagnosis_id;
    std::optional<std::string> final_screen_id;
    std::optional<std::string> final_protocol_id;
};

struct StartResult
{
    std::optional<Question> first_question;
    bool finished = false;
};

struct SubmitResult
{
    std::optional<Question> next_question;
    bool finished = false;
};

// =========================
// Ana motor
// =========================

class Core
{
public:
    // guidance_dir gecis uyumlulugu icin korunuyor, artik kullanilmiyor
    bool load_all(
        const std::string& questions_dir,
        const std::string& diagnoses_dir,
        const std::string& guidance_dir = "");

    StartResult start_session(Session& session);
    SubmitResult submit_answer(
        Session& session,
        const std::string& question_id,
        const std::string& answer_id);

    bool go_to_previous_question(
        Session& session,
        std::optional<Question>& out_question,
        std::optional<std::string>& out_previous_answer_id);

    std::optional<Diagnosis> get_final_diagnosis(const Session& session) const;

    static std::string pick_text(
        const std::unordered_map<std::string, std::string>& texts,
        const std::string& language);

private:
    std::vector<Question> questions_;
    std::vector<Diagnosis> diagnoses_;

private:
    bool load_questions(const std::string& dir);
    bool load_diagnoses(const std::string& dir);

    std::optional<Question> select_next_question(const Session& session) const;
    bool is_question_visible(const Question& question, const Session& session) const;

    bool apply_answer_by_ids(
        Session& session,
        const std::string& question_id,
        const std::string& answer_id);

    std::optional<Diagnosis> find_early_finish_diagnosis(const Session& session) const;
    std::optional<Diagnosis> select_best_scored_diagnosis(const Session& session) const;

    void finalize_session(
        Session& session,
        const std::optional<Diagnosis>& diagnosis);

    const Question* find_question(const std::string& id) const;
    const Answer* find_answer(const Question& question, const std::string& answer_id) const;
    const Diagnosis* find_diagnosis(const std::string& id) const;

    static void add_scores(
        Session& session,
        const std::unordered_map<std::string, int>& scores);

    static void remove_scores(
        Session& session,
        const std::unordered_map<std::string, int>& scores);
};
