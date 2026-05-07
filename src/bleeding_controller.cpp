#include "bleeding_controller.h"

#include <QtGlobal>

BleedingController::BleedingController(QObject* parent)
    : QObject(parent)
{
    tickTimer_.setInterval(200);
    tickTimer_.setTimerType(Qt::PreciseTimer);
    connect(&tickTimer_, &QTimer::timeout, this, &BleedingController::onTick);
}

// ── Getter'lar ────────────────────────────────────────────────
QString BleedingController::phase()                const { return phaseString(); }
bool    BleedingController::showDecision()         const { return showDecision_; }
QString BleedingController::questionText()         const { return questionText_; }
QString BleedingController::primaryActionText()    const { return primaryActionText_; }
QString BleedingController::secondaryActionText()  const { return secondaryActionText_; }
bool    BleedingController::showMonitor()          const { return showMonitor_; }
QString BleedingController::monitorText()          const { return monitorText_; }
bool    BleedingController::running()              const { return running_; }
QString BleedingController::videoKey()             const { return videoKey_; }
int     BleedingController::videoSerial()          const { return videoSerial_; }
QString BleedingController::voiceCue()             const { return voiceCue_; }
int     BleedingController::voiceSerial()          const { return voiceSerial_; }

QString BleedingController::pulseText() const
{
    if (!pulseSensorConnected_ || pulseValue_ <= 0)
        return "--";
    return QString::number(pulseValue_);
}

QString BleedingController::spo2Text() const
{
    if (!spo2SensorConnected_ || spo2Value_ <= 0)
        return "--";
    return QString("%1%").arg(spo2Value_);
}

QString BleedingController::elapsedText() const
{
    const int m = elapsedSeconds_ / 60;
    const int s = elapsedSeconds_ % 60;
    return QString("%1:%2")
        .arg(m, 2, 10, QLatin1Char('0'))
        .arg(s, 2, 10, QLatin1Char('0'));
}

QString BleedingController::phaseString() const
{
    switch (phase_) {
    case Phase::Idle:            return "idle";
    case Phase::PressVideo:      return "press_video";
    case Phase::PressPopup:      return "press_popup";
    case Phase::TourniquetVideo: return "tourniquet_video";
    case Phase::Monitor:         return "monitor";
    case Phase::Paused:          return "paused";
    }
    return "idle";
}

void BleedingController::setPhase(Phase newPhase)
{
    if (phase_ == newPhase)
        return;
    phase_ = newPhase;
    emit stateChanged();
}

// ── Karar popup ──────────────────────────────────────────────
void BleedingController::clearDecision()
{
    showDecision_ = false;
    questionText_.clear();
    primaryActionText_.clear();
    secondaryActionText_.clear();
}

void BleedingController::setDecision(const QString& question,
                                     const QString& primary,
                                     const QString& secondary)
{
    showDecision_        = true;
    questionText_        = question;
    primaryActionText_   = primary;
    secondaryActionText_ = secondary;
}

// ── Video / Voice ────────────────────────────────────────────
void BleedingController::emitVideo(const QString& key)
{
    videoKey_ = key;
    videoSerial_ += 1;
    emit videoSerialChanged();
}

void BleedingController::emitVoice(const QString& cue)
{
    voiceCue_ = cue;
    voiceSerial_ += 1;
    emit voiceSerialChanged();
}

// ── Ana akış ─────────────────────────────────────────────────
void BleedingController::start()
{
    stop();

    running_         = true;
    elapsedSeconds_  = 0;
    vitalAlertShown_ = false;
    resetDangerTimer();

    clearDecision();
    showMonitor_ = false;
    monitorText_.clear();

    clock_.start();
    tickTimer_.start();

    enterPressVideo();
    emit stateChanged();
}

void BleedingController::stop()
{
    tickTimer_.stop();
    running_ = false;

    phase_            = Phase::Idle;
    phaseBeforePause_ = Phase::Idle;

    elapsedSeconds_  = 0;
    vitalAlertShown_ = false;
    resetDangerTimer();

    clearDecision();
    showMonitor_ = false;
    monitorText_.clear();
    videoKey_.clear();
    voiceCue_.clear();

    emit stateChanged();
}

void BleedingController::pause()
{
    if (!running_ || phase_ == Phase::Paused)
        return;

    phaseBeforePause_ = phase_;
    setPhase(Phase::Paused);
    tickTimer_.stop();
    resetDangerTimer();
}

void BleedingController::resume()
{
    if (!running_ || phase_ != Phase::Paused)
        return;

    phase_ = phaseBeforePause_;
    tickTimer_.start();
    emit stateChanged();
}

void BleedingController::restart()
{
    start();
}

void BleedingController::setPulseData(bool connected, int bpm)
{
    pulseSensorConnected_ = connected;
    pulseValue_ = bpm;
    checkVitalAlert();
    emit stateChanged();
}

void BleedingController::setSpo2Data(bool connected, int spo2)
{
    spo2SensorConnected_ = connected;
    spo2Value_ = spo2;
    checkVitalAlert();
    emit stateChanged();
}

// ── Video / Voice bitti ──────────────────────────────────────
void BleedingController::videoFinished()
{
    if (!running_)
        return;

    switch (phase_) {
    case Phase::PressVideo:
        enterPressPopup();
        break;
    case Phase::TourniquetVideo:
        enterMonitor();
        break;
    default:
        break;
    }
}

void BleedingController::voiceFinished()
{
    // Soru sesi bittikten sonra yapacak iş yok; kullanıcı EVET/HAYIR'a basana kadar bekler.
}

// ── Popup seçimleri ──────────────────────────────────────────
void BleedingController::choosePrimary()   // EVET
{
    if (!showDecision_)
        return;

    if (phase_ == Phase::PressPopup) {
        clearDecision();
        enterMonitor();
        return;
    }
}

void BleedingController::chooseSecondary() // HAYIR
{
    if (!showDecision_)
        return;

    if (phase_ == Phase::PressPopup) {
        clearDecision();
        enterTourniquetVideo();
        return;
    }
}

// ── Faz geçişleri ────────────────────────────────────────────
void BleedingController::enterPressVideo()
{
    setPhase(Phase::PressVideo);
    showMonitor_ = false;
    monitorText_.clear();
    clearDecision();
    emitVideo("press");
    emit stateChanged();
}

void BleedingController::enterPressPopup()
{
    setPhase(Phase::PressPopup);
    setDecision(QString::fromUtf8("Kanama durdu mu?"),
                QString::fromUtf8("EVET"),
                QString::fromUtf8("HAYIR"));
    emitVoice("question_bleeding_stopped");
    emit stateChanged();
}

void BleedingController::enterTourniquetVideo()
{
    setPhase(Phase::TourniquetVideo);
    clearDecision();
    showMonitor_ = false;
    monitorText_.clear();
    emitVideo("tourniquet");
    emit stateChanged();
}

void BleedingController::enterMonitor()
{
    setPhase(Phase::Monitor);
    clearDecision();
    videoKey_.clear();
    showMonitor_ = true;
    monitorText_ = QString::fromUtf8(
        "Hastayı izle.\n"
        "Kanamayı kontrol altında tut.\n"
        "Ambulansı bekle."
    );
    emit stateChanged();
}

// ── Zaman ────────────────────────────────────────────────────
void BleedingController::updateElapsed(qint64 nowMs)
{
    const int newElapsed = int(nowMs / 1000);
    if (newElapsed != elapsedSeconds_) {
        elapsedSeconds_ = newElapsed;
        emit stateChanged();
    }
}

void BleedingController::onTick()
{
    if (!running_ || !tickTimer_.isActive() || !clock_.isValid())
        return;

    const qint64 nowMs = clock_.elapsed();
    updateElapsed(nowMs);
    checkVitalAlert();
}

// ── Vital alert (opsiyonel CPR yönlendirmesi) ────────────────
bool BleedingController::hasReliablePulse() const
{
    return pulseSensorConnected_ &&
           pulseValue_ >= 25 &&
           pulseValue_ <= 220;
}

bool BleedingController::hasReliableSpo2() const
{
    return spo2SensorConnected_ &&
           spo2Value_ >= 70 &&
           spo2Value_ <= 100;
}

void BleedingController::resetDangerTimer()
{
    dangerStartMs_ = -1;
}

bool BleedingController::sensorsShowDanger() const
{
    const bool pulseDanger = hasReliablePulse() && (pulseValue_ < 40);
    const bool spo2Danger  = hasReliableSpo2()  && (spo2Value_ < 90);

    return pulseDanger || spo2Danger;
}

void BleedingController::checkVitalAlert()
{
    if (!running_)               return;
    if (vitalAlertShown_)        return;
    if (showDecision_)           return;
    if (phase_ == Phase::Paused) return;
    if (!clock_.isValid())       return;

    // Güvenilir hiçbir veri yoksa CPR kararı verme.
    if (!hasReliablePulse() && !hasReliableSpo2()) {
        resetDangerTimer();
        return;
    }

    // Kritik durum yoksa sayaç sıfırlansın.
    if (!sensorsShowDanger()) {
        resetDangerTimer();
        return;
    }

    const qint64 nowMs = clock_.elapsed();

    // İlk kritik anı işaretle.
    if (dangerStartMs_ < 0) {
        dangerStartMs_ = nowMs;
        return;
    }

    // Kritik durum belirli süre devam etmeden CPR isteme.
    if ((nowMs - dangerStartMs_) < dangerHoldMs_)
        return;

    vitalAlertShown_ = true;
    resetDangerTimer();
    emit cprRequested();
}
