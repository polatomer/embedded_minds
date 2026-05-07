#pragma once

#include <QObject>
#include <QElapsedTimer>
#include <QTimer>
#include <QString>

// Kolda ağır kanama yönlendirme controller'ı.
// Akış:
//   1) PressVideo     → "112 ara + kanamaya bası yap" videosu tam ekran oynar
//   2) PressPopup     → "Kanama durdu mu?" sesli soru oynar + EVET/HAYIR popup
//        EVET  → Monitor (tam ekran "Hastayı izle, ambulansı bekle" yazısı)
//        HAYIR → TourniquetVideo
//   3) TourniquetVideo → Turnike uygulama videosu tam ekran oynar
//   4) Monitor         → Tam ekran izleme/bekleme yazısı
//
// Üst barda sürekli nabız ve SpO2 değerleri görünür.
class BleedingController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString phase READ phase NOTIFY stateChanged)

    Q_PROPERTY(QString pulseText   READ pulseText   NOTIFY stateChanged)
    Q_PROPERTY(QString spo2Text    READ spo2Text    NOTIFY stateChanged)
    Q_PROPERTY(QString elapsedText READ elapsedText NOTIFY stateChanged)

    Q_PROPERTY(bool    showDecision        READ showDecision        NOTIFY stateChanged)
    Q_PROPERTY(QString questionText        READ questionText        NOTIFY stateChanged)
    Q_PROPERTY(QString primaryActionText   READ primaryActionText   NOTIFY stateChanged)
    Q_PROPERTY(QString secondaryActionText READ secondaryActionText NOTIFY stateChanged)

    Q_PROPERTY(bool    showMonitor READ showMonitor NOTIFY stateChanged)
    Q_PROPERTY(QString monitorText READ monitorText NOTIFY stateChanged)

    Q_PROPERTY(bool running READ running NOTIFY stateChanged)

    Q_PROPERTY(QString videoKey    READ videoKey    NOTIFY videoSerialChanged)
    Q_PROPERTY(int     videoSerial READ videoSerial NOTIFY videoSerialChanged)

    Q_PROPERTY(QString voiceCue    READ voiceCue    NOTIFY voiceSerialChanged)
    Q_PROPERTY(int     voiceSerial READ voiceSerial NOTIFY voiceSerialChanged)

public:
    explicit BleedingController(QObject* parent = nullptr);

    QString phase() const;

    QString pulseText()   const;
    QString spo2Text()    const;
    QString elapsedText() const;

    bool    showDecision()        const;
    QString questionText()        const;
    QString primaryActionText()   const;
    QString secondaryActionText() const;

    bool    showMonitor() const;
    QString monitorText() const;

    bool running() const;

    QString videoKey()    const;
    int     videoSerial() const;

    QString voiceCue()    const;
    int     voiceSerial() const;

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();
    Q_INVOKABLE void restart();

    Q_INVOKABLE void setPulseData(bool connected, int bpm);
    Q_INVOKABLE void setSpo2Data(bool connected, int spo2);
    Q_INVOKABLE void videoFinished();
    Q_INVOKABLE void voiceFinished();

    Q_INVOKABLE void choosePrimary();    // EVET
    Q_INVOKABLE void chooseSecondary();  // HAYIR

signals:
    void stateChanged();
    void videoSerialChanged();
    void voiceSerialChanged();
    void cprRequested();   // Sensörler CPR gerektiriyorsa üst katmana bildirim

private slots:
    void onTick();

private:
    enum class Phase {
        Idle,
        PressVideo,       // 112 ara + bası yap
        PressPopup,       // Kanama durdu mu? (sesli soru)
        TourniquetVideo,  // Turnike uygula
        Monitor,          // Hastayı izle / ambulansı bekle
        Paused
    };

    QString phaseString() const;
    void setPhase(Phase newPhase);

    void clearDecision();
    void setDecision(const QString& question,
                     const QString& primary,
                     const QString& secondary);

    void enterPressVideo();
    void enterPressPopup();
    void enterTourniquetVideo();
    void enterMonitor();

    void emitVideo(const QString& key);
    void emitVoice(const QString& cue);
    void updateElapsed(qint64 nowMs);
    void checkVitalAlert();
    bool sensorsShowDanger() const;

    bool hasReliablePulse() const;
    bool hasReliableSpo2() const;
    void resetDangerTimer();

private:
    QElapsedTimer clock_;
    QTimer        tickTimer_;

    Phase phase_            = Phase::Idle;
    Phase phaseBeforePause_ = Phase::Idle;

    bool pulseSensorConnected_ = false;
    int  pulseValue_           = -1;
    bool spo2SensorConnected_  = false;
    int  spo2Value_            = -1;
    bool vitalAlertShown_      = false;

    bool    showDecision_        = false;
    QString questionText_;
    QString primaryActionText_;
    QString secondaryActionText_;

    bool    showMonitor_ = false;
    QString monitorText_;

    QString videoKey_;
    int     videoSerial_ = 0;

    QString voiceCue_;
    int     voiceSerial_ = 0;

    int  elapsedSeconds_ = 0;
    bool running_        = false;

    qint64 dangerStartMs_ = -1;
    int    dangerHoldMs_  = 3000;   // 3 saniye kritik kalırsa CPR iste
};
