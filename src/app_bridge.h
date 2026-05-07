#pragma once

#include "bleeding_controller.h"
#include "core.h"
#include "cpr_controller.h"
#include "event_recorder.h"
#include "vital_signs_service.h"
#include "voice_command_server.h"

#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <gpiod.h>
#include <optional>

class AppBridge : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString screen READ screen NOTIFY screenChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(QString mediaBaseUrl READ mediaBaseUrl NOTIFY mediaBaseUrlChanged)

    Q_PROPERTY(QString currentQuestionText READ currentQuestionText NOTIFY questionChanged)
    Q_PROPERTY(QString currentQuestionHint READ currentQuestionHint NOTIFY questionChanged)
    Q_PROPERTY(QStringList currentAnswers READ currentAnswers NOTIFY questionChanged)
    Q_PROPERTY(QVariantList currentAnswerItems READ currentAnswerItems NOTIFY questionChanged)
    Q_PROPERTY(int selectedAnswerIndex READ selectedAnswerIndex NOTIFY selectedAnswerIndexChanged)

    Q_PROPERTY(QString finalDiagnosis READ finalDiagnosis NOTIFY guidanceChanged)
    Q_PROPERTY(QString finalScreenId READ finalScreenId NOTIFY guidanceChanged)
    Q_PROPERTY(QString finalProtocolId READ finalProtocolId NOTIFY guidanceChanged)

    Q_PROPERTY(QObject* cprController READ cprController CONSTANT)
    Q_PROPERTY(QObject* bleedingController READ bleedingController CONSTANT)
    Q_PROPERTY(QObject* vitalSigns READ vitalSigns CONSTANT)
    Q_PROPERTY(QObject* eventRecorder READ eventRecorder CONSTANT)

public:
    explicit AppBridge(QObject* parent = nullptr);
    ~AppBridge() override;

    QString screen() const;
    QString language() const;
    void setLanguage(const QString& lang);
    QString mediaBaseUrl() const;

    QString currentQuestionText() const;
    QString currentQuestionHint() const;
    QStringList currentAnswers() const;
    QVariantList currentAnswerItems() const;
    int selectedAnswerIndex() const;

    QString finalDiagnosis() const;
    QString finalScreenId() const;
    QString finalProtocolId() const;

    QObject* cprController();
    QObject* bleedingController();
    QObject* vitalSigns();
    QObject* eventRecorder();

    Q_INVOKABLE void setScreen(const QString& screenName);
    Q_INVOKABLE void restartQuestionsKeepRecording();
    Q_INVOKABLE void navigateToCpr();
    Q_INVOKABLE void navigateToLowSpo2();

    Q_INVOKABLE bool initialize(const QString& basePath);
    Q_INVOKABLE void goHome();
    Q_INVOKABLE void openSettings();
    Q_INVOKABLE void openRecords();
    Q_INVOKABLE void openEventDetail(const QString& eventId);
    Q_INVOKABLE void startEmergency();
    Q_INVOKABLE void submitAnswer(int index);
    Q_INVOKABLE void previousQuestion();
    Q_INVOKABLE void moveSelectionLeft();
    Q_INVOKABLE void moveSelectionRight();
    Q_INVOKABLE void activateSelectedAnswer();

signals:
    void screenChanged();
    void languageChanged();
    void mediaBaseUrlChanged();
    void questionChanged();
    void guidanceChanged();
    void selectedAnswerIndexChanged();
    void errorOccurred(const QString& message);

    // Fiziksel giriş sinyalleri
    void uiBackRequested();
    void uiEncoderPressed();
    void uiEncoderRotated(int direction);

    // ── Sesli komut sinyalleri — main.qml tarafından yakalanır ───────────────

    // Onay / Ret (popup'larda ve soru ekranında)
    void voiceYesRequested();
    void voiceNoRequested();

    // Kanama bölgesi seçimi (QuestionScreen'de q_bleeding_location)
    void voiceKolRequested();
    void voiceBacakRequested();
    void voiceVucutRequested();

    // Özel eylemler
    void voiceAmbulansAraRequested();
    void voiceYardimRequested();
    void voiceVeriKaydiniSilRequested();

private:
    // Sesli komut işleyici
    void handleVoiceCommand(const QString& command);
    int  findAnswerByNormalizedText(const QString& normalized) const;

    // Yardımcılar
    void clearQuestionState();
    void clearResultState();
    void updateQuestionState();
    void updateResultState();
    void openFinalScreen();
    void onSensorChanged();
    int  findAnswerIndexById(const std::string& answerId) const;

    // Gaz monitörü
    void startGasMonitor();
    void stopGasMonitor();
    bool setupGasGpio();
    void pollGasSensor();
    void playGasAlert();

    // Fiziksel giriş monitörü
    void startUiInputMonitor();
    void stopUiInputMonitor();
    bool setupUiInputGpio();
    void pollUiInputs();

    void handleHomeButtonPressed();
    void handleBackButtonPressed();
    void handleEncoderPressed();
    void handleEncoderRotate(int direction);

private:
    Core              core_;
    CprController     cpr_controller_;
    BleedingController bleeding_controller_;
    VitalSignsService vital_signs_;
    Session           session_;
    EventRecorder     event_recorder_;
    VoiceCommandServer voice_server_;

    QString screen_         = "home";
    QString language_       = "tr";
    QString media_base_url_;
    bool    initialized_    = false;

    std::optional<Question>     current_question_;
    std::optional<Diagnosis>    final_diagnosis_;
    std::optional<std::string>  final_screen_id_;
    std::optional<std::string>  final_protocol_id_;

    int selected_answer_index_ = 0;

    // Gaz sensörü GPIO
    QTimer       gasPollTimer_;
    gpiod_chip*  gasChip_          = nullptr;
    gpiod_line*  gasLine_          = nullptr;
    bool         gasDetectedLast_  = false;
    qint64       lastGasAlertMs_   = 0;

    // UI giriş GPIO
    QTimer       uiPollTimer_;
    gpiod_chip*  uiChip_              = nullptr;
    gpiod_line*  homeButtonLine_      = nullptr;
    gpiod_line*  backButtonLine_      = nullptr;
    gpiod_line*  encoderClkLine_      = nullptr;
    gpiod_line*  encoderDtLine_       = nullptr;
    gpiod_line*  encoderSwLine_       = nullptr;

    bool   homeButtonLastPressed_  = false;
    bool   backButtonLastPressed_  = false;
    bool   encoderSwLastPressed_   = false;
    int    encoderClkLastRaw_      = 1;
    int    encoderDtLastRaw_       = 1;

    qint64 lastHomeButtonMs_    = 0;
    qint64 lastBackButtonMs_    = 0;
    qint64 lastEncoderPressMs_  = 0;
    qint64 lastEncoderStepMs_   = 0;
};
