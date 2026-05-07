#include "core.h"

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <limits>
#include <stdexcept>

#include <nlohmann/json.hpp>

using json = nlohmann::json;
namespace fs = std::filesystem;

// =========================
// Yerel yardimcilar
// =========================

static json read_json_file(const std::string& path)
{
    std::ifstream file(path);
    if (!file.is_open())
        throw std::runtime_error("Dosya acilamadi: " + path);

    json j;
    file >> j;
    return j;
}

static std::unordered_map<std::string, std::string> parse_text_map(const json& j)
{
    std::unordered_map<std::string, std::string> result;

    for (auto it = j.begin(); it != j.end(); ++it)
        result[it.key()] = it.value().get<std::string>();

    return result;
}

// Yeni yapida "order" kullanilir.
// Geriye donuk uyumluluk icin eski numeric "priority" da okunur.
static int parse_question_order(const json& j)
{
    if (j.contains("order") && j["order"].is_number_integer())
        return j["order"].get<int>();

    if (j.contains("priority") && j["priority"].is_number_integer())
        return -j["priority"].get<int>();

    return 0;
}

// Yeni yapida int priority kullanilir.
// Geriye donuk uyumluluk icin string priority de okunur.
static int parse_diagnosis_priority(const json& j)
{
    if (!j.contains("priority"))
        return 0;

    const auto& p = j["priority"];

    if (p.is_number_integer())
        return p.get<int>();

    if (p.is_string())
    {
        const std::string value = p.get<std::string>();

        if (value == "critical") return 100;
        if (value == "urgent")   return 70;
        if (value == "routine")  return 40;
        return 0;
    }

    return 0;
}

// =========================
// Public API
// =========================

bool Core::load_all(
    const std::string& questions_dir,
    const std::string& diagnoses_dir,
    const std::string& guidance_dir)
{
    (void)guidance_dir; // artik guidance kullanilmiyor

    questions_.clear();
    diagnoses_.clear();

    return load_questions(questions_dir)
        && load_diagnoses(diagnoses_dir);
}

StartResult Core::start_session(Session& session)
{
    const std::string preserved_language = session.language.empty() ? "tr" : session.language;

    session.answers.clear();
    session.diagnosis_scores.clear();
    session.asked_questions.clear();
    session.history.clear();
    session.finished = false;
    session.final_diagnosis_id.reset();
    session.final_screen_id.reset();
    session.final_protocol_id.reset();
    session.language = preserved_language;

    auto first = select_next_question(session);

    if (!first.has_value())
    {
        auto best = select_best_scored_diagnosis(session);
        finalize_session(session, best);

        return StartResult{
            .first_question = std::nullopt,
            .finished = true
        };
    }

    return StartResult{
        .first_question = first,
        .finished = false
    };
}

SubmitResult Core::submit_answer(
    Session& session,
    const std::string& question_id,
    const std::string& answer_id)
{
    if (session.finished)
    {
        return SubmitResult{
            .next_question = std::nullopt,
            .finished = true
        };
    }

    const bool ok = apply_answer_by_ids(session, question_id, answer_id);
    if (!ok)
    {
        auto next = select_next_question(session);

        return SubmitResult{
            .next_question = next,
            .finished = false
        };
    }

    auto early = find_early_finish_diagnosis(session);
    if (early.has_value())
    {
        finalize_session(session, early);

        return SubmitResult{
            .next_question = std::nullopt,
            .finished = true
        };
    }

    auto next = select_next_question(session);
    if (!next.has_value())
    {
        auto best = select_best_scored_diagnosis(session);
        finalize_session(session, best);

        return SubmitResult{
            .next_question = std::nullopt,
            .finished = true
        };
    }

    return SubmitResult{
        .next_question = next,
        .finished = false
    };
}

bool Core::go_to_previous_question(
    Session& session,
    std::optional<Question>& out_question,
    std::optional<std::string>& out_previous_answer_id)
{
    out_question.reset();
    out_previous_answer_id.reset();

    if (session.history.empty())
        return false;

    session.finished = false;
    session.final_diagnosis_id.reset();
    session.final_screen_id.reset();
    session.final_protocol_id.reset();

    const QuestionHistoryEntry last = session.history.back();
    session.history.pop_back();

    const Question* question = find_question(last.question_id);
    if (!question)
        return false;

    const Answer* answer = find_answer(*question, last.answer_id);
    if (!answer)
        return false;

    remove_scores(session, answer->scores);

    session.answers.erase(last.question_id);
    session.asked_questions.erase(last.question_id);

    out_question = *question;
    out_previous_answer_id = last.answer_id;
    return true;
}

std::optional<Diagnosis> Core::get_final_diagnosis(const Session& session) const
{
    if (!session.final_diagnosis_id.has_value())
        return std::nullopt;

    const Diagnosis* d = find_diagnosis(*session.final_diagnosis_id);
    if (!d)
        return std::nullopt;

    return *d;
}

std::string Core::pick_text(
    const std::unordered_map<std::string, std::string>& texts,
    const std::string& language)
{
    auto it = texts.find(language);
    if (it != texts.end())
        return it->second;

    auto tr = texts.find("tr");
    if (tr != texts.end())
        return tr->second;

    auto en = texts.find("en");
    if (en != texts.end())
        return en->second;

    if (!texts.empty())
        return texts.begin()->second;

    return "";
}

// =========================
// Yukleme
// =========================

bool Core::load_questions(const std::string& dir)
{
    for (const auto& entry : fs::directory_iterator(dir))
    {
        if (!entry.is_regular_file() || entry.path().extension() != ".json")
            continue;

        json j = read_json_file(entry.path().string());

        Question q;
        q.id = j.at("id").get<std::string>();
        q.text = parse_text_map(j.at("text"));
        q.order = parse_question_order(j);

        if (j.contains("hint") && j["hint"].is_object())
            q.hint = parse_text_map(j["hint"]);

        if (j.contains("requires_question_id") && j["requires_question_id"].is_string())
            q.requires_question_id = j["requires_question_id"].get<std::string>();

        if (j.contains("requires_answer_id") && j["requires_answer_id"].is_string())
            q.requires_answer_id = j["requires_answer_id"].get<std::string>();

        for (const auto& item : j.at("answers"))
        {
            Answer a;
            a.id = item.at("id").get<std::string>();
            a.text = parse_text_map(item.at("text"));

            if (item.contains("image") && item["image"].is_string())
                a.image = item["image"].get<std::string>();

            a.scores = item.value("scores", std::unordered_map<std::string, int>{});

            q.answers.push_back(a);
        }

        questions_.push_back(q);
    }

    return true;
}

bool Core::load_diagnoses(const std::string& dir)
{
    for (const auto& entry : fs::directory_iterator(dir))
    {
        if (!entry.is_regular_file() || entry.path().extension() != ".json")
            continue;

        json j = read_json_file(entry.path().string());

        Diagnosis d;
        d.id = j.at("id").get<std::string>();
        d.name = parse_text_map(j.at("name"));
        d.min_score = j.value("min_score", 0);
        d.priority = parse_diagnosis_priority(j);
        d.early_finish = j.value("early_finish", false);

        if (j.contains("screen_id") && j["screen_id"].is_string())
            d.screen_id = j["screen_id"].get<std::string>();

        if (d.screen_id.empty() && j.contains("guidance_id") && j["guidance_id"].is_string())
            d.screen_id = j["guidance_id"].get<std::string>();

        if (j.contains("protocol_id") && j["protocol_id"].is_string())
            d.protocol_id = j["protocol_id"].get<std::string>();

        diagnoses_.push_back(d);
    }

    return true;
}

// =========================
// Soru akisi
// =========================

bool Core::is_question_visible(const Question& question, const Session& session) const
{
    if (question.requires_question_id.has_value() && question.requires_answer_id.has_value())
    {
        auto it = session.answers.find(*question.requires_question_id);
        if (it == session.answers.end())
            return false;

        if (it->second != *question.requires_answer_id)
            return false;
    }

    return true;
}

std::optional<Question> Core::select_next_question(const Session& session) const
{
    std::vector<Question> remaining;

    for (const auto& q : questions_)
    {
        if (session.asked_questions.count(q.id))
            continue;

        if (!is_question_visible(q, session))
            continue;

        remaining.push_back(q);
    }

    if (remaining.empty())
        return std::nullopt;

    const bool has_visible_branch_questions = std::any_of(
        remaining.begin(),
        remaining.end(),
        [](const Question& q)
        {
            return q.requires_question_id.has_value()
                && q.requires_answer_id.has_value();
        });

    if (has_visible_branch_questions)
    {
        remaining.erase(
            std::remove_if(
                remaining.begin(),
                remaining.end(),
                [](const Question& q)
                {
                    return !(q.requires_question_id.has_value()
                          && q.requires_answer_id.has_value());
                }),
            remaining.end()
        );
    }

    std::sort(
        remaining.begin(),
        remaining.end(),
        [](const Question& a, const Question& b)
        {
            if (a.order != b.order)
                return a.order < b.order;

            return a.id < b.id;
        });

    return remaining.front();
}

bool Core::apply_answer_by_ids(
    Session& session,
    const std::string& question_id,
    const std::string& answer_id)
{
    const Question* question = find_question(question_id);
    if (!question)
        return false;

    const Answer* answer = find_answer(*question, answer_id);
    if (!answer)
        return false;

    session.answers[question_id] = answer_id;
    session.asked_questions.insert(question_id);
    session.history.push_back({question_id, answer_id});

    add_scores(session, answer->scores);
    return true;
}

// =========================
// Olay secimi
// =========================

std::optional<Diagnosis> Core::find_early_finish_diagnosis(const Session& session) const
{
    std::optional<Diagnosis> best;
    int best_score = std::numeric_limits<int>::min();
    int best_priority = std::numeric_limits<int>::min();

    for (const auto& d : diagnoses_)
    {
        if (!d.early_finish)
            continue;

        if (d.min_score <= 0)
            continue;

        int score = 0;
        auto it = session.diagnosis_scores.find(d.id);
        if (it != session.diagnosis_scores.end())
            score = it->second;

        if (score < d.min_score)
            continue;

        if (!best.has_value()
            || score > best_score
            || (score == best_score && d.priority > best_priority)
            || (score == best_score && d.priority == best_priority && d.id < best->id))
        {
            best = d;
            best_score = score;
            best_priority = d.priority;
        }
    }

    return best;
}

std::optional<Diagnosis> Core::select_best_scored_diagnosis(const Session& session) const
{
    std::optional<Diagnosis> best_threshold;
    int best_threshold_score = std::numeric_limits<int>::min();
    int best_threshold_priority = std::numeric_limits<int>::min();

    for (const auto& d : diagnoses_)
    {
        if (d.min_score < 0)
            continue;

        int score = 0;
        auto it = session.diagnosis_scores.find(d.id);
        if (it != session.diagnosis_scores.end())
            score = it->second;

        if (score < d.min_score)
            continue;

        if (!best_threshold.has_value()
            || score > best_threshold_score
            || (score == best_threshold_score && d.priority > best_threshold_priority)
            || (score == best_threshold_score && d.priority == best_threshold_priority && d.id < best_threshold->id))
        {
            best_threshold = d;
            best_threshold_score = score;
            best_threshold_priority = d.priority;
        }
    }

    if (best_threshold.has_value())
        return best_threshold;

    std::optional<Diagnosis> best_positive;
    int best_positive_score = std::numeric_limits<int>::min();
    int best_positive_priority = std::numeric_limits<int>::min();

    for (const auto& d : diagnoses_)
    {
        int score = 0;
        auto it = session.diagnosis_scores.find(d.id);
        if (it != session.diagnosis_scores.end())
            score = it->second;

        if (score <= 0)
            continue;

        if (!best_positive.has_value()
            || score > best_positive_score
            || (score == best_positive_score && d.priority > best_positive_priority)
            || (score == best_positive_score && d.priority == best_positive_priority && d.id < best_positive->id))
        {
            best_positive = d;
            best_positive_score = score;
            best_positive_priority = d.priority;
        }
    }

    if (best_positive.has_value())
        return best_positive;

    std::optional<Diagnosis> fallback;
    int fallback_priority = std::numeric_limits<int>::min();

    for (const auto& d : diagnoses_)
    {
        if (d.min_score != 0)
            continue;

        if (!fallback.has_value()
            || d.priority > fallback_priority
            || (d.priority == fallback_priority && d.id < fallback->id))
        {
            fallback = d;
            fallback_priority = d.priority;
        }
    }

    return fallback;
}

void Core::finalize_session(
    Session& session,
    const std::optional<Diagnosis>& diagnosis)
{
    session.finished = true;

    if (!diagnosis.has_value())
    {
        session.final_diagnosis_id.reset();
        session.final_screen_id.reset();
        session.final_protocol_id.reset();
        return;
    }

    session.final_diagnosis_id = diagnosis->id;

    if (!diagnosis->screen_id.empty())
        session.final_screen_id = diagnosis->screen_id;
    else
        session.final_screen_id = "unknown_result";

    if (!diagnosis->protocol_id.empty())
        session.final_protocol_id = diagnosis->protocol_id;
    else
        session.final_protocol_id.reset();
}

// =========================
// Bulucular
// =========================

const Question* Core::find_question(const std::string& id) const
{
    for (const auto& q : questions_)
    {
        if (q.id == id)
            return &q;
    }

    return nullptr;
}

const Answer* Core::find_answer(const Question& question, const std::string& answer_id) const
{
    for (const auto& a : question.answers)
    {
        if (a.id == answer_id)
            return &a;
    }

    return nullptr;
}

const Diagnosis* Core::find_diagnosis(const std::string& id) const
{
    for (const auto& d : diagnoses_)
    {
        if (d.id == id)
            return &d;
    }

    return nullptr;
}

// =========================
// Yardimcilar
// =========================

void Core::add_scores(
    Session& session,
    const std::unordered_map<std::string, int>& scores)
{
    for (const auto& [diagnosis_id, delta] : scores)
        session.diagnosis_scores[diagnosis_id] += delta;
}

void Core::remove_scores(
    Session& session,
    const std::unordered_map<std::string, int>& scores)
{
    for (const auto& [diagnosis_id, delta] : scores)
    {
        auto it = session.diagnosis_scores.find(diagnosis_id);
        if (it != session.diagnosis_scores.end())
        {
            it->second -= delta;
            if (it->second == 0)
                session.diagnosis_scores.erase(it);
        }
    }
}
