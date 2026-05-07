#include "cpr_controller.h"

#include <QtGlobal>

CprController::CprController(QObject* parent)
    : QObject(parent)
{
    tickTimer_.setInterval(200);
    tickTimer_.setTimerType(Qt::PreciseTimer);
    connect(&tickTimer_, &QTimer::timeout, this, &CprController::onTick);
}

QString CprController::phase() const { return phaseString(); }
QString CprController::centerLabel() const { return centerLabel_; }
QString CprController::centerSubLabel() const { return centerSubLabel_; }
QString CprController::coachText() const { return coachText_; }
QString CprController::feedbackText() const { return feedbackText_; }
QColor  CprController::feedbackColor() const { return feedbackColor_; }
int CprController::compressionCount() const { return compressionCount_; }
int CprController::compressionsPerCycle() const { return compressionsPerCycle_; }
int CprController::breathCount() const { return breathCount_; }
int CprController::breathsPerCycle() const { return breathsPerCycle_; }
int CprController::cycleCount() const { return cycleCount_; }
int CprController::targetBpm() const { return targetBpm_; }
int CprController::minBpm() const { return minBpm_; }
int CprController::maxBpm() const { return maxBpm_; }
int CprController::measuredCompressionBpm() const { return measuredCompressionBpm_; }
int CprController::beatSerial() const { return beatSerial_; }
bool CprController::running() const { return running_; }
bool CprController::showDecision() const { return showDecision_; }
QString CprController::questionText() const { return questionText_; }
QString CprController::primaryActionText() const { return primaryActionText_; }
QString CprController::secondaryActionText() const { return secondaryActionText_; }
QString CprController::voiceCue() const { return voiceCue_; }
int CprController::voiceSerial() const { return voiceSerial_; }
QString CprController::videoKey() const { return videoKey_; }
int CprController::videoSerial() const { return videoSerial_; }

QString CprController::pulseText() const
{
    if (!pulseSensorConnected_ || pulseValue_ <= 0)
        return "--";
    return QString::number(pulseValue_);
}

QString CprController::spo2Text() const
{
    if (!spo2SensorConnected_ || spo2Value_ <= 0)
        return "--";
    return QString("%1%").arg(spo2Value_);
}

QString CprController::elapsedText() const
{
    const int m = elapsedSeconds_ / 60;
    const int s = elapsedSeconds_ % 60;
    return QString("%1:%2")
        .arg(m, 2, 10, QLatin1Char('0'))
        .arg(s, 2, 10, QLatin1Char('0'));
}

QString CprController::phaseString() const
{
    switch (phase_) {
    case Phase::Idle:         return "idle";
    case Phase::Call112Video: return "call112_video";
    case Phase::Call112Popup: return "call112_popup";
    case Phase::IntroVideo:   return "intro_video";
    case Phase::IntroPopup:   return "intro_popup";
    case Phase::CprLoopVideo: return "cpr_loop_video";
    case Phase::CheckPopup:   return "check_popup";
    case Phase::RecoveryVideo:return "recovery_video";
    case Phase::Completed:    return "completed";
    case Phase::Paused:       return "paused";
    }
    return "idle";
}

void CprController::setPhase(Phase newPhase)
{
    if (phase_ == newPhase)
        return;
    phase_ = newPhase;
    emit stateChanged();
}

void CprController::clearDecision()
{
    showDecision_ = false;
    questionText_.clear();
    primaryActionText_.clear();
    secondaryActionText_.clear();
}

void CprController::setDecision(const QString& question,
                                const QString& primary,
                                const QString& secondary)
{
    showDecision_ = true;
    questionText_ = question;
    primaryActionText_ = primary;
    secondaryActionText_ = secondary;
}

void CprController::emitVoice(const QString& cue)
{
    voiceCue_ = cue;
    voiceSerial_ += 1;
    emit voiceSerialChanged();
}

void CprController::emitVideo(const QString& key)
{
    videoKey_ = key;
    videoSerial_ += 1;
    emit videoSerialChanged();
}

void CprController::start()
{
    stop();

    running_ = true;
    elapsedSeconds_ = 0;
    beatSerial_ = 0;
    compressionCount_ = 0;
    breathCount_ = 0;
    cycleCount_ = 0;
    cprLoopCompletedCount_ = 0;
    lastRhythmCueMs_ = -100000;

    clearDecision();

    clock_.start();
    tickTimer_.start();

    enterCall112Video();
    emit stateChanged();
}

void CprController::stop()
{
    tickTimer_.stop();
    running_ = false;

    phase_ = Phase::Idle;
    phaseBeforePause_ = Phase::Idle;

    elapsedSeconds_ = 0;
    compressionCount_ = 0;
    breathCount_ = 0;
    cycleCount_ = 0;
    cprLoopCompletedCount_ = 0;
    beatSerial_ = 0;
    lastRhythmCueMs_ = -100000;

    clearDecision();

    centerLabel_.clear();
    centerSubLabel_.clear();
    coachText_.clear();
    feedbackText_.clear();
    feedbackColor_ = QColor("#2563EB");
    voiceCue_.clear();
    videoKey_.clear();

    emit stateChanged();
}

void CprController::pause()
{
    if (!running_ || phase_ == Phase::Paused)
        return;

    phaseBeforePause_ = phase_;
    setPhase(Phase::Paused);
    tickTimer_.stop();
}

void CprController::resume()
{
    if (!running_ || phase_ != Phase::Paused)
        return;

    phase_ = phaseBeforePause_;
    tickTimer_.start();
    emit stateChanged();
}

void CprController::restart()
{
    start();
}

void CprController::setPulseData(bool connected, int bpm)
{
    pulseSensorConnected_ = connected;
    pulseValue_ = bpm;
    measuredCompressionBpm_ = bpm;

    if (running_ && clock_.isValid())
        evaluateRhythmCue(clock_.elapsed());

    emit stateChanged();
}

void CprController::setSpo2Data(bool connected, int spo2)
{
    spo2SensorConnected_ = connected;
    spo2Value_ = spo2;
    emit stateChanged();
}

void CprController::setRateData(bool connected, int bpm)
{
    rateSensorConnected_ = connected;
    measuredCompressionBpm_ = bpm;
    emit stateChanged();
}

void CprController::voiceFinished()
{
}

void CprController::videoFinished()
{
    if (!running_)
        return;

    switch (phase_) {
    case Phase::Call112Video:
        enterCall112Popup();
        break;
    case Phase::IntroVideo:
        enterIntroPopup();
        break;
    case Phase::CprLoopVideo:
        cprLoopCompletedCount_ += 1;
        cycleCount_ = cprLoopCompletedCount_;
        compressionCount_ = cprLoopCompletedCount_;

        if (cprLoopCompletedCount_ >= 3)
            enterCheckPopup();
        else
            emitVideo("loop");

        emit stateChanged();
        break;
    case Phase::RecoveryVideo:
        finishRecovery();
        break;
    case Phase::Call112Popup:
    case Phase::IntroPopup:
    case Phase::CheckPopup:
    case Phase::Completed:
    case Phase::Paused:
    case Phase::Idle:
        break;
    }
}

void CprController::choosePrimary()
{
    if (!showDecision_)
        return;

    switch (phase_) {
    case Phase::Call112Popup:
        clearDecision();
        enterIntroVideo();
        break;
    case Phase::IntroPopup:
        clearDecision();
        enterCprLoopVideo(true);
        break;
    case Phase::CheckPopup:
        clearDecision();
        enterRecoveryVideo();
        break;
    default:
        break;
    }
}

void CprController::chooseSecondary()
{
    if (!showDecision_)
        return;

    switch (phase_) {
    case Phase::Call112Popup:
        clearDecision();
        enterCall112Video();
        break;
    case Phase::IntroPopup:
        clearDecision();
        enterIntroVideo();
        break;
    case Phase::CheckPopup:
        clearDecision();
        enterCprLoopVideo(true);
        break;
    default:
        break;
    }
}

void CprController::enterCall112Video()
{
    setPhase(Phase::Call112Video);
    centerLabel_.clear();
    centerSubLabel_.clear();
    coachText_.clear();
    feedbackText_.clear();
    emitVideo("call112");
    emit stateChanged();
}

void CprController::enterCall112Popup()
{
    setPhase(Phase::Call112Popup);
    setDecision(QString(),
                QString::fromUtf8("DEVAM ET"),
                QString::fromUtf8("TEKRAR DİNLE"));
    emit stateChanged();
}

void CprController::enterIntroVideo()
{
    setPhase(Phase::IntroVideo);
    centerLabel_.clear();
    centerSubLabel_.clear();
    coachText_.clear();
    feedbackText_.clear();
    emitVideo("intro");
    emit stateChanged();
}

void CprController::enterIntroPopup()
{
    setPhase(Phase::IntroPopup);
    setDecision(QString(),
                QString::fromUtf8("DEVAM ET"),
                QString::fromUtf8("TEKRAR DİNLE"));
    emit stateChanged();
}

void CprController::enterCprLoopVideo(bool resetCounter)
{
    setPhase(Phase::CprLoopVideo);

    if (resetCounter)
        cprLoopCompletedCount_ = 0;

    cycleCount_ = cprLoopCompletedCount_;
    compressionCount_ = cprLoopCompletedCount_;
    breathCount_ = 0;

    centerLabel_.clear();
    centerSubLabel_.clear();
    coachText_.clear();
    feedbackText_.clear();

    emitVideo("loop");
    emit stateChanged();
}

void CprController::enterCheckPopup()
{
    setPhase(Phase::CheckPopup);
    setDecision(QString(),
                QString::fromUtf8("VAR"),
                QString::fromUtf8("YOK"));
    emitVoice("question");
    emit stateChanged();
}

void CprController::enterRecoveryVideo()
{
    setPhase(Phase::RecoveryVideo);
    emitVideo("recovery");
    emit stateChanged();
}

void CprController::finishRecovery()
{
    setPhase(Phase::Completed);
    emit stateChanged();
}

void CprController::updateElapsed(qint64 nowMs)
{
    const int newElapsed = int(nowMs / 1000);
    if (newElapsed != elapsedSeconds_) {
        elapsedSeconds_ = newElapsed;
        emit stateChanged();
    }
}

void CprController::evaluateRhythmCue(qint64 nowMs)
{
    if (phase_ != Phase::CprLoopVideo)
        return;

    if (!pulseSensorConnected_ || pulseValue_ <= 0)
        return;

    if (nowMs - lastRhythmCueMs_ < rhythmCueCooldownMs_)
        return;

    if (pulseValue_ < minBpm_) {
        lastRhythmCueMs_ = nowMs;
        emitVoice("speed_up");
    } else if (pulseValue_ > maxBpm_) {
        lastRhythmCueMs_ = nowMs;
        emitVoice("slow_down");
    }
}

void CprController::onTick()
{
    if (!running_ || !tickTimer_.isActive() || !clock_.isValid())
        return;

    const qint64 nowMs = clock_.elapsed();
    updateElapsed(nowMs);
    evaluateRhythmCue(nowMs);
}
