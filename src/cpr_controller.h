#pragma once

#include <QObject>
#include <QColor>
#include <QElapsedTimer>
#include <QTimer>
#include <QString>

class CprController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString phase READ phase NOTIFY stateChanged)
    Q_PROPERTY(QString centerLabel READ centerLabel NOTIFY stateChanged)
    Q_PROPERTY(QString centerSubLabel READ centerSubLabel NOTIFY stateChanged)
    Q_PROPERTY(QString coachText READ coachText NOTIFY stateChanged)
    Q_PROPERTY(QString feedbackText READ feedbackText NOTIFY stateChanged)
    Q_PROPERTY(QColor feedbackColor READ feedbackColor NOTIFY stateChanged)
    Q_PROPERTY(QString pulseText READ pulseText NOTIFY stateChanged)
    Q_PROPERTY(QString spo2Text READ spo2Text NOTIFY stateChanged)
    Q_PROPERTY(QString elapsedText READ elapsedText NOTIFY stateChanged)

    Q_PROPERTY(bool showDecision READ showDecision NOTIFY stateChanged)
    Q_PROPERTY(QString questionText READ questionText NOTIFY stateChanged)
    Q_PROPERTY(QString primaryActionText READ primaryActionText NOTIFY stateChanged)
    Q_PROPERTY(QString secondaryActionText READ secondaryActionText NOTIFY stateChanged)

    Q_PROPERTY(int compressionCount READ compressionCount NOTIFY stateChanged)
    Q_PROPERTY(int compressionsPerCycle READ compressionsPerCycle NOTIFY stateChanged)
    Q_PROPERTY(int breathCount READ breathCount NOTIFY stateChanged)
    Q_PROPERTY(int breathsPerCycle READ breathsPerCycle NOTIFY stateChanged)
    Q_PROPERTY(int cycleCount READ cycleCount NOTIFY stateChanged)
    Q_PROPERTY(int targetBpm READ targetBpm NOTIFY stateChanged)
    Q_PROPERTY(int minBpm READ minBpm NOTIFY stateChanged)
    Q_PROPERTY(int maxBpm READ maxBpm NOTIFY stateChanged)
    Q_PROPERTY(int measuredCompressionBpm READ measuredCompressionBpm NOTIFY stateChanged)
    Q_PROPERTY(int beatSerial READ beatSerial NOTIFY beatSerialChanged)
    Q_PROPERTY(bool running READ running NOTIFY stateChanged)

    Q_PROPERTY(QString voiceCue READ voiceCue NOTIFY voiceSerialChanged)
    Q_PROPERTY(int voiceSerial READ voiceSerial NOTIFY voiceSerialChanged)

    Q_PROPERTY(QString videoKey READ videoKey NOTIFY videoSerialChanged)
    Q_PROPERTY(int videoSerial READ videoSerial NOTIFY videoSerialChanged)

public:
    explicit CprController(QObject* parent = nullptr);

    QString phase() const;
    QString centerLabel() const;
    QString centerSubLabel() const;
    QString coachText() const;
    QString feedbackText() const;
    QColor feedbackColor() const;
    QString pulseText() const;
    QString spo2Text() const;
    QString elapsedText() const;

    int compressionCount() const;
    int compressionsPerCycle() const;
    int breathCount() const;
    int breathsPerCycle() const;
    int cycleCount() const;
    int targetBpm() const;
    int minBpm() const;
    int maxBpm() const;
    int measuredCompressionBpm() const;
    int beatSerial() const;
    bool running() const;

    bool showDecision() const;
    QString questionText() const;
    QString primaryActionText() const;
    QString secondaryActionText() const;

    QString voiceCue() const;
    int voiceSerial() const;

    QString videoKey() const;
    int videoSerial() const;

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();
    Q_INVOKABLE void restart();

    Q_INVOKABLE void setPulseData(bool connected, int bpm);
    Q_INVOKABLE void setSpo2Data(bool connected, int spo2);
    Q_INVOKABLE void setRateData(bool connected, int bpm);
    Q_INVOKABLE void voiceFinished();
    Q_INVOKABLE void videoFinished();

    Q_INVOKABLE void choosePrimary();
    Q_INVOKABLE void chooseSecondary();

signals:
    void stateChanged();
    void beatSerialChanged();
    void voiceSerialChanged();
    void videoSerialChanged();

private slots:
    void onTick();

private:
    enum class Phase {
        Idle,
        Call112Video,
        Call112Popup,
        IntroVideo,
        IntroPopup,
        CprLoopVideo,
        CheckPopup,
        RecoveryVideo,
        Completed,
        Paused
    };

    QString phaseString() const;
    void setPhase(Phase newPhase);

    void clearDecision();
    void setDecision(const QString& question,
                     const QString& primary,
                     const QString& secondary = QString());

    void enterCall112Video();
    void enterCall112Popup();
    void enterIntroVideo();
    void enterIntroPopup();
    void enterCprLoopVideo(bool resetCounter);
    void enterCheckPopup();
    void enterRecoveryVideo();
    void finishRecovery();

    void emitVoice(const QString& cue);
    void emitVideo(const QString& key);
    void updateElapsed(qint64 nowMs);
    void evaluateRhythmCue(qint64 nowMs);

private:
    QElapsedTimer clock_;
    QTimer tickTimer_;

    Phase phase_ = Phase::Idle;
    Phase phaseBeforePause_ = Phase::Idle;

    bool pulseSensorConnected_ = false;
    int pulseValue_ = -1;
    bool spo2SensorConnected_ = false;
    int spo2Value_ = -1;
    bool rateSensorConnected_ = false;
    int measuredCompressionBpm_ = 0;

    bool showDecision_ = false;
    QString questionText_;
    QString primaryActionText_;
    QString secondaryActionText_;

    QString centerLabel_;
    QString centerSubLabel_;
    QString coachText_;
    QString feedbackText_;
    QColor feedbackColor_ = QColor("#2563EB");

    QString voiceCue_;
    int voiceSerial_ = 0;

    QString videoKey_;
    int videoSerial_ = 0;

    int targetBpm_ = 100;
    int minBpm_ = 60;
    int maxBpm_ = 130;
    int compressionsPerCycle_ = 30;
    int breathsPerCycle_ = 2;

    int compressionCount_ = 0;
    int breathCount_ = 0;
    int cycleCount_ = 0;
    int elapsedSeconds_ = 0;
    int beatSerial_ = 0;

    bool running_ = false;
    int cprLoopCompletedCount_ = 0;

    qint64 lastRhythmCueMs_ = -100000;
    int rhythmCueCooldownMs_ = 4000;
};
