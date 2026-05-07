#include "app_bridge.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QProcess>
#include <QUrl>
#include <QVariantMap>
#include <cmath>

namespace {
constexpr int kGasBcmLine = 17;
constexpr bool kGasActiveLow = true;
constexpr int kGasPollMs = 100;
constexpr qint64 kGasCooldownMs = 5000;
const char* kGasAlertAudioRelativePath = "/../ui/assets/gas_detector/gas_alert.wav";

constexpr int kHomeButtonBcmLine = 24;
constexpr int kBackButtonBcmLine = 25;
constexpr int kEncoderClkBcmLine = 27;
constexpr int kEncoderDtBcmLine = 22;
constexpr int kEncoderSwBcmLine = 23;

constexpr bool kUiButtonsActiveLow = true;
constexpr int kUiPollMs = 4;
constexpr qint64 kButtonDebounceMs = 180;
constexpr qint64 kEncoderPressDebounceMs = 180;
constexpr qint64 kEncoderStepDebounceMs = 35;

void releaseLine(gpiod_line*& line)
{
    if (line) {
        gpiod_line_release(line);
        line = nullptr;
    }
}

void closeChip(gpiod_chip*& chip)
{
    if (chip) {
        gpiod_chip_close(chip);
        chip = nullptr;
    }
}

bool requestInputLinePullUp(gpiod_chip* chip, int lineNumber, const char* consumer, gpiod_line** outLine)
{
    if (!chip || !outLine)
        return false;

    gpiod_line* line = gpiod_chip_get_line(chip, lineNumber);
    if (!line) {
        qWarning() << "GPIO line alinamadi:" << lineNumber;
        return false;
    }

    gpiod_line_request_config config = {};
    config.consumer = consumer;
    config.request_type = GPIOD_LINE_REQUEST_DIRECTION_INPUT;
    config.flags = GPIOD_LINE_REQUEST_FLAG_BIAS_PULL_UP;

    if (gpiod_line_request(line, &config, 0) < 0) {
        qWarning() << "GPIO input request basarisiz:" << lineNumber;
        return false;
    }

    *outLine = line;
    return true;
}
}

AppBridge::AppBridge(QObject* parent)
    : QObject(parent)
{
    connect(&vital_signs_, &VitalSignsService::changed,
            this, &AppBridge::onSensorChanged);

    // Sensör hatalarını terminale ve UI'ya yansıt
    connect(&vital_signs_, &VitalSignsService::errorOccurred,
            this, [this](const QString& msg) {
                qWarning() << "[VitalSigns ERROR]" << msg;
                emit errorOccurred(msg);
            });

    connect(&bleeding_controller_, &BleedingController::cprRequested,
            this, [this]() {
                bleeding_controller_.stop();
                screen_ = "cpr";
                emit screenChanged();
            });

    qInfo() << "[AppBridge] vital_signs_.startOptional() cagiriliyor...";
    const bool sensorOk = vital_signs_.startOptional();
    qInfo() << "[AppBridge] startOptional sonuc:" << sensorOk
            << "sensorRunning:" << vital_signs_.sensorRunning()
            << "statusText:" << vital_signs_.statusText();

    connect(&gasPollTimer_, &QTimer::timeout,
            this, &AppBridge::pollGasSensor);

    connect(&uiPollTimer_, &QTimer::timeout,
            this, &AppBridge::pollUiInputs);

    startGasMonitor();
    startUiInputMonitor();
}

AppBridge::~AppBridge()
{
    stopUiInputMonitor();
    stopGasMonitor();
}

QString AppBridge::screen() const
{
    return screen_;
}

void AppBridge::setScreen(const QString& screenName)
{
    if (screen_ == screenName)
        return;

    screen_ = screenName;
    emit screenChanged();
}

void AppBridge::restartQuestionsKeepRecording()
{
    if (!initialized_) {
        emit errorOccurred("Önce veri yüklenmeli.");
        return;
    }

    cpr_controller_.stop();
    bleeding_controller_.stop();

    event_recorder_.logDecision(
        "cpr_pulse_check",
        "Nabız ve solunum var - soru ekranına dönüldü",
        "kullanici_onayladi"
    );

    session_ = Session{};
    session_.language = language_.toStdString();

    clearResultState();

    StartResult result = core_.start_session(session_);
    current_question_ = result.first_question;

    if (session_.finished) {
        clearQuestionState();
        updateResultState();
        openFinalScreen();
        emit questionChanged();
        emit guidanceChanged();
        emit screenChanged();
        return;
    }

    selected_answer_index_ = 0;
    emit selectedAnswerIndexChanged();

    updateQuestionState();
    screen_ = "question";
    emit questionChanged();
    emit guidanceChanged();
    emit screenChanged();
}

void AppBridge::navigateToCpr()
{
    cpr_controller_.stop();
    bleeding_controller_.stop();

    event_recorder_.logGuidance("cpr", "vital_alert_nabiz_cok_dusuk");

    screen_ = "cpr";
    emit screenChanged();
}

void AppBridge::navigateToLowSpo2()
{
    cpr_controller_.stop();
    bleeding_controller_.stop();

    event_recorder_.logGuidance("low_spo2", "vital_alert_spo2_cok_dusuk");

    screen_ = "low_spo2";
    emit screenChanged();
}

QString AppBridge::language() const
{
    return language_;
}

void AppBridge::setLanguage(const QString& lang)
{
    if (language_ == lang)
        return;

    language_ = lang;
    session_.language = language_.toStdString();

    emit languageChanged();
    emit questionChanged();
    emit guidanceChanged();
}

QString AppBridge::mediaBaseUrl() const
{
    return media_base_url_;
}

QString AppBridge::currentQuestionText() const
{
    if (!current_question_.has_value())
        return "";

    return QString::fromStdString(
        Core::pick_text(current_question_->text, session_.language)
    );
}

QString AppBridge::currentQuestionHint() const
{
    if (!current_question_.has_value())
        return "";

    return QString::fromStdString(
        Core::pick_text(current_question_->hint, session_.language)
    );
}

QStringList AppBridge::currentAnswers() const
{
    QStringList result;

    if (!current_question_.has_value())
        return result;

    for (const auto& ans : current_question_->answers) {
        result << QString::fromStdString(
            Core::pick_text(ans.text, session_.language)
        );
    }

    return result;
}

QVariantList AppBridge::currentAnswerItems() const
{
    QVariantList result;

    if (!current_question_.has_value())
        return result;

    for (const auto& ans : current_question_->answers) {
        QVariantMap item;
        item["id"] = QString::fromStdString(ans.id);
        item["text"] = QString::fromStdString(Core::pick_text(ans.text, session_.language));
        item["image"] = QString::fromStdString(ans.image);
        result << item;
    }

    return result;
}

int AppBridge::selectedAnswerIndex() const
{
    return selected_answer_index_;
}

QString AppBridge::finalDiagnosis() const
{
    if (!final_diagnosis_.has_value())
        return "";

    return QString::fromStdString(
        Core::pick_text(final_diagnosis_->name, session_.language)
    );
}

QString AppBridge::finalScreenId() const
{
    return final_screen_id_.has_value()
           ? QString::fromStdString(*final_screen_id_)
           : "";
}

QString AppBridge::finalProtocolId() const
{
    return final_protocol_id_.has_value()
           ? QString::fromStdString(*final_protocol_id_)
           : "";
}

QObject* AppBridge::cprController()
{
    return &cpr_controller_;
}

QObject* AppBridge::bleedingController()
{
    return &bleeding_controller_;
}

QObject* AppBridge::vitalSigns()
{
    return &vital_signs_;
}

QObject* AppBridge::eventRecorder()
{
    return &event_recorder_;
}

void AppBridge::onSensorChanged()
{
    const bool fingerOn = vital_signs_.fingerPresent();
    const bool pulseDetected = vital_signs_.pulseDetected();

    const int bpm = pulseDetected
                    ? static_cast<int>(std::round(vital_signs_.heartRateBpm()))
                    : 0;

    const bool spo2Stable = vital_signs_.signalStable();
    const int spo2 = spo2Stable
                     ? static_cast<int>(std::round(vital_signs_.spo2()))
                     : 0;

    cpr_controller_.setPulseData(fingerOn, bpm);
    cpr_controller_.setSpo2Data(spo2Stable, spo2);

    bleeding_controller_.setPulseData(fingerOn, bpm);
    bleeding_controller_.setSpo2Data(spo2Stable, spo2);

    event_recorder_.updateVitals(fingerOn, bpm, spo2Stable, spo2);
}

void AppBridge::startGasMonitor()
{
    if (!setupGasGpio()) {
        emit errorOccurred("Gaz modulu GPIO baslatilamadi.");
        return;
    }

    gasPollTimer_.setInterval(kGasPollMs);
    gasPollTimer_.start();
}

void AppBridge::stopGasMonitor()
{
    gasPollTimer_.stop();
    releaseLine(gasLine_);
    closeChip(gasChip_);
}

bool AppBridge::setupGasGpio()
{
    stopGasMonitor();

    gasChip_ = gpiod_chip_open("/dev/gpiochip0");
    if (!gasChip_) {
        qWarning() << "gpiod_chip_open basarisiz";
        return false;
    }

    gasLine_ = gpiod_chip_get_line(gasChip_, kGasBcmLine);
    if (!gasLine_) {
        qWarning() << "GPIO line alinamadi:" << kGasBcmLine;
        closeChip(gasChip_);
        return false;
    }

    gpiod_line_request_config config = {};
    config.consumer = "aks_gas_monitor";
    config.request_type = GPIOD_LINE_REQUEST_DIRECTION_INPUT;
    config.flags = GPIOD_LINE_REQUEST_FLAG_BIAS_PULL_UP;

    if (gpiod_line_request(gasLine_, &config, 0) < 0) {
        qWarning() << "GPIO input request basarisiz:" << kGasBcmLine;
        gasLine_ = nullptr;
        closeChip(gasChip_);
        return false;
    }

    gasDetectedLast_ = false;
    lastGasAlertMs_ = 0;

    return true;
}

void AppBridge::pollGasSensor()
{
    if (!gasLine_)
        return;

    const int raw = gpiod_line_get_value(gasLine_);
    if (raw < 0) {
        qWarning() << "Gaz GPIO okunamadi";
        return;
    }

    const bool detected = kGasActiveLow ? (raw == 0) : (raw == 1);
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();

    if (detected && !gasDetectedLast_) {
        if ((nowMs - lastGasAlertMs_) >= kGasCooldownMs) {
            playGasAlert();
            lastGasAlertMs_ = nowMs;
        }
    }

    gasDetectedLast_ = detected;
}

void AppBridge::playGasAlert()
{
    const QString audioPath =
        QDir::currentPath() + QString::fromUtf8(kGasAlertAudioRelativePath);

    if (!QFileInfo::exists(audioPath)) {
        emit errorOccurred("Gaz alarm ses dosyasi bulunamadi: " + audioPath);
        return;
    }

    QProcess::startDetached("aplay", QStringList() << "-q" << audioPath);
    qDebug() << "Gaz algilandi, alarm sesi oynatildi:" << audioPath;
}

void AppBridge::startUiInputMonitor()
{
    if (!setupUiInputGpio()) {
        emit errorOccurred("Buton veya rotary GPIO baslatilamadi.");
        return;
    }

    uiPollTimer_.setInterval(kUiPollMs);
    uiPollTimer_.start();
}

void AppBridge::stopUiInputMonitor()
{
    uiPollTimer_.stop();

    releaseLine(homeButtonLine_);
    releaseLine(backButtonLine_);
    releaseLine(encoderClkLine_);
    releaseLine(encoderDtLine_);
    releaseLine(encoderSwLine_);
    closeChip(uiChip_);
}

bool AppBridge::setupUiInputGpio()
{
    stopUiInputMonitor();

    uiChip_ = gpiod_chip_open("/dev/gpiochip0");
    if (!uiChip_) {
        qWarning() << "ui gpiochip acilamadi";
        return false;
    }

    if (!requestInputLinePullUp(uiChip_, kHomeButtonBcmLine, "aks_home_button", &homeButtonLine_)) {
        stopUiInputMonitor();
        return false;
    }

    if (!requestInputLinePullUp(uiChip_, kBackButtonBcmLine, "aks_back_button", &backButtonLine_)) {
        stopUiInputMonitor();
        return false;
    }

    if (!requestInputLinePullUp(uiChip_, kEncoderClkBcmLine, "aks_encoder_clk", &encoderClkLine_)) {
        stopUiInputMonitor();
        return false;
    }

    if (!requestInputLinePullUp(uiChip_, kEncoderDtBcmLine, "aks_encoder_dt", &encoderDtLine_)) {
        stopUiInputMonitor();
        return false;
    }

    if (!requestInputLinePullUp(uiChip_, kEncoderSwBcmLine, "aks_encoder_sw", &encoderSwLine_)) {
        stopUiInputMonitor();
        return false;
    }

    const int homeRaw = gpiod_line_get_value(homeButtonLine_);
    const int backRaw = gpiod_line_get_value(backButtonLine_);
    const int swRaw = gpiod_line_get_value(encoderSwLine_);
    const int clkRaw = gpiod_line_get_value(encoderClkLine_);
    const int dtRaw = gpiod_line_get_value(encoderDtLine_);

    if (homeRaw < 0 || backRaw < 0 || swRaw < 0 || clkRaw < 0 || dtRaw < 0) {
        qWarning() << "baslangic gpio degerleri okunamadi";
        stopUiInputMonitor();
        return false;
    }

    homeButtonLastPressed_ = kUiButtonsActiveLow ? (homeRaw == 0) : (homeRaw == 1);
    backButtonLastPressed_ = kUiButtonsActiveLow ? (backRaw == 0) : (backRaw == 1);
    encoderSwLastPressed_ = kUiButtonsActiveLow ? (swRaw == 0) : (swRaw == 1);
    encoderClkLastRaw_ = clkRaw;
    encoderDtLastRaw_ = dtRaw;

    lastHomeButtonMs_ = 0;
    lastBackButtonMs_ = 0;
    lastEncoderPressMs_ = 0;
    lastEncoderStepMs_ = 0;

    return true;
}

void AppBridge::pollUiInputs()
{
    if (!homeButtonLine_ || !backButtonLine_ || !encoderClkLine_ || !encoderDtLine_ || !encoderSwLine_)
        return;

    const int homeRaw = gpiod_line_get_value(homeButtonLine_);
    const int backRaw = gpiod_line_get_value(backButtonLine_);
    const int clkRaw = gpiod_line_get_value(encoderClkLine_);
    const int dtRaw = gpiod_line_get_value(encoderDtLine_);
    const int swRaw = gpiod_line_get_value(encoderSwLine_);

    if (homeRaw < 0 || backRaw < 0 || clkRaw < 0 || dtRaw < 0 || swRaw < 0) {
        qWarning() << "ui gpio okunamadi";
        return;
    }

    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();

    const bool homePressed = kUiButtonsActiveLow ? (homeRaw == 0) : (homeRaw == 1);
    const bool backPressed = kUiButtonsActiveLow ? (backRaw == 0) : (backRaw == 1);
    const bool swPressed = kUiButtonsActiveLow ? (swRaw == 0) : (swRaw == 1);

    if (homePressed && !homeButtonLastPressed_ &&
        (nowMs - lastHomeButtonMs_) >= kButtonDebounceMs) {
        handleHomeButtonPressed();
        lastHomeButtonMs_ = nowMs;
    }

    if (backPressed && !backButtonLastPressed_ &&
        (nowMs - lastBackButtonMs_) >= kButtonDebounceMs) {
        handleBackButtonPressed();
        lastBackButtonMs_ = nowMs;
    }

    if (swPressed && !encoderSwLastPressed_ &&
        (nowMs - lastEncoderPressMs_) >= kEncoderPressDebounceMs) {
        handleEncoderPressed();
        lastEncoderPressMs_ = nowMs;
    }

    if (clkRaw != encoderClkLastRaw_) {
        const bool fallingEdge = (encoderClkLastRaw_ == 1 && clkRaw == 0);

        if (fallingEdge && (nowMs - lastEncoderStepMs_) >= kEncoderStepDebounceMs) {
            if (dtRaw != clkRaw)
                handleEncoderRotate(+1);
            else
                handleEncoderRotate(-1);

            lastEncoderStepMs_ = nowMs;
        }

        encoderClkLastRaw_ = clkRaw;
    }

    encoderDtLastRaw_ = dtRaw;
    homeButtonLastPressed_ = homePressed;
    backButtonLastPressed_ = backPressed;
    encoderSwLastPressed_ = swPressed;
}

void AppBridge::handleHomeButtonPressed()
{
    goHome();
}

void AppBridge::handleBackButtonPressed()
{
    if (screen_ == "question") {
        previousQuestion();
        return;
    }

    emit uiBackRequested();
}

void AppBridge::handleEncoderPressed()
{
    if (screen_ == "question") {
        activateSelectedAnswer();
        return;
    }

    emit uiEncoderPressed();
}

void AppBridge::handleEncoderRotate(int direction)
{
    if (screen_ == "question") {
        if (direction > 0)
            moveSelectionRight();
        else if (direction < 0)
            moveSelectionLeft();
        return;
    }

    if (direction != 0)
        emit uiEncoderRotated(direction);
}

bool AppBridge::initialize(const QString& basePath)
{
    try {
        const QString assetsPath = QDir(basePath).filePath("ui/assets");
        media_base_url_ = QUrl::fromLocalFile(assetsPath).toString();
        emit mediaBaseUrlChanged();

        initialized_ = core_.load_all(
            QDir(basePath).filePath("data/questions").toStdString(),
            QDir(basePath).filePath("data/diagnoses").toStdString(),
            QDir(basePath).filePath("data/guidance").toStdString()
        );

        session_ = Session{};
        session_.language = language_.toStdString();

        if (!initialized_)
            emit errorOccurred("Veriler yüklenemedi.");

        return initialized_;
    } catch (const std::exception& e) {
        initialized_ = false;
        emit errorOccurred(QString::fromUtf8(e.what()));
        return false;
    }
}

void AppBridge::goHome()
{
    cpr_controller_.stop();
    bleeding_controller_.stop();

    event_recorder_.endEvent();

    session_ = Session{};
    session_.language = language_.toStdString();

    clearQuestionState();
    clearResultState();

    selected_answer_index_ = 0;
    emit selectedAnswerIndexChanged();

    screen_ = "home";
    emit screenChanged();
}

void AppBridge::openSettings()
{
    cpr_controller_.stop();
    bleeding_controller_.stop();

    screen_ = "settings";
    emit screenChanged();
}

void AppBridge::openRecords()
{
    cpr_controller_.stop();
    bleeding_controller_.stop();

    screen_ = "records";
    emit screenChanged();
}

void AppBridge::openEventDetail(const QString& eventId)
{
    Q_UNUSED(eventId)
    screen_ = "event_detail";
    emit screenChanged();
}

void AppBridge::startEmergency()
{
    if (!initialized_) {
        emit errorOccurred("Önce veri yüklenmeli.");
        return;
    }

    cpr_controller_.stop();
    bleeding_controller_.stop();

    event_recorder_.startEvent();

    session_ = Session{};
    session_.language = language_.toStdString();

    clearResultState();

    StartResult result = core_.start_session(session_);
    current_question_ = result.first_question;

    if (session_.finished) {
        clearQuestionState();
        updateResultState();
        openFinalScreen();
        emit questionChanged();
        emit guidanceChanged();
        emit screenChanged();
        return;
    }

    selected_answer_index_ = 0;
    emit selectedAnswerIndexChanged();

    updateQuestionState();
    screen_ = "question";
    emit questionChanged();
    emit guidanceChanged();
    emit screenChanged();
}

void AppBridge::submitAnswer(int index)
{
    if (!current_question_.has_value())
        return;

    if (index < 0 || index >= static_cast<int>(current_question_->answers.size()))
        return;

    {
        const QString qText = currentQuestionText();
        const QStringList answers = currentAnswers();
        const QString aText = (index < answers.size()) ? answers.at(index) : QString();
        event_recorder_.logQuestion(qText, aText);
    }

    SubmitResult result = core_.submit_answer(
        session_,
        current_question_->id,
        current_question_->answers[index].id
    );

    current_question_ = result.next_question;

    if (session_.finished) {
        selected_answer_index_ = 0;
        emit selectedAnswerIndexChanged();

        clearQuestionState();
        updateResultState();
        openFinalScreen();
        emit questionChanged();
        emit guidanceChanged();
        emit screenChanged();
        return;
    }

    selected_answer_index_ = 0;
    emit selectedAnswerIndexChanged();

    updateQuestionState();
    emit questionChanged();
}

void AppBridge::previousQuestion()
{
    if (screen_ != "question")
        return;

    std::optional<Question> previousQuestionValue;
    std::optional<std::string> previousAnswerId;

    if (!core_.go_to_previous_question(session_, previousQuestionValue, previousAnswerId))
        return;

    current_question_ = previousQuestionValue;
    clearResultState();

    selected_answer_index_ = 0;
    if (previousAnswerId.has_value())
        selected_answer_index_ = findAnswerIndexById(*previousAnswerId);

    emit selectedAnswerIndexChanged();
    emit questionChanged();
    emit guidanceChanged();
}

void AppBridge::moveSelectionLeft()
{
    if (screen_ != "question" || !current_question_.has_value())
        return;

    if (selected_answer_index_ > 0) {
        selected_answer_index_--;
        emit selectedAnswerIndexChanged();
    }
}

void AppBridge::moveSelectionRight()
{
    if (screen_ != "question" || !current_question_.has_value())
        return;

    const int maxIndex = static_cast<int>(current_question_->answers.size()) - 1;
    if (selected_answer_index_ < maxIndex) {
        selected_answer_index_++;
        emit selectedAnswerIndexChanged();
    }
}

void AppBridge::activateSelectedAnswer()
{
    if (screen_ != "question")
        return;

    submitAnswer(selected_answer_index_);
}

void AppBridge::clearQuestionState()
{
    current_question_.reset();
}

void AppBridge::clearResultState()
{
    final_diagnosis_.reset();
    final_screen_id_.reset();
    final_protocol_id_.reset();
}

void AppBridge::updateQuestionState()
{
}

void AppBridge::updateResultState()
{
    final_diagnosis_ = core_.get_final_diagnosis(session_);
    final_screen_id_ = session_.final_screen_id;
    final_protocol_id_ = session_.final_protocol_id;
}

void AppBridge::openFinalScreen()
{
    if (final_screen_id_.has_value() && !final_screen_id_->empty())
        screen_ = QString::fromStdString(*final_screen_id_);
    else
        screen_ = "unknown_result";

    qDebug() << "Final diagnosis screen =" << screen_;

    event_recorder_.logGuidance(screen_, finalDiagnosis());
}

int AppBridge::findAnswerIndexById(const std::string& answerId) const
{
    if (!current_question_.has_value())
        return 0;

    for (int i = 0; i < static_cast<int>(current_question_->answers.size()); ++i) {
        if (current_question_->answers[i].id == answerId)
            return i;
    }

    return 0;
}
