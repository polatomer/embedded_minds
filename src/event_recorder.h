#pragma once

#include <QObject>
#include <QElapsedTimer>
#include <QFile>
#include <QProcess>
#include <QString>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

// Acil durum olayı kayıt yöneticisi.
//
// Her acil durum başlatıldığında:
//   * ~/.local/share/AKS/events/<YYYYMMDD_HHMMSS>/ klasörü açılır
//   * events.jsonl (append-only, her satırda bir JSON) log dosyası
//   * video/segment_XXX.mkv dosyalarına ffmpeg ile USB kamera kaydı
//
// Crash safety:
//   * events.jsonl her yazıdan sonra fsync'lenir → pil bitse bile kayıp yok
//   * MKV container finalize gerektirmez → son segment de oynatılabilir
//   * 1 dakikalık segmentler → elektrik kesilse bile tamamlanmış segmentler kalır
class EventRecorder : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(QString currentEventId READ currentEventId NOTIFY currentEventIdChanged)

public:
    explicit EventRecorder(QObject* parent = nullptr);
    ~EventRecorder() override;

    bool recording() const;
    QString currentEventId() const;

    // ── Kayıt başlat / bitir ─────────────────────────────────
    // startEvent: Acil durum başladığında çağrılır. Yeni event klasörü
    //   oluşturur, JSONL açar, ffmpeg'i başlatır, 10s vitals timer'ını başlatır.
    // endEvent: Olay biter (Ana Sayfa'ya dönüş) - ffmpeg kapatılır,
    //   son vitals kaydı atılır, "end" satırı JSONL'ye eklenir.
    Q_INVOKABLE void startEvent();
    Q_INVOKABLE void endEvent();

    // ── Log API'leri ─────────────────────────────────────────
    // Controller / AppBridge bunları çağırır. Sadece recording ise etkili.
    void logQuestion(const QString& questionText, const QString& answerText);
    void logGuidance(const QString& screenId, const QString& diagnosis);
    void logDecision(const QString& category, const QString& questionText,
                     const QString& answerText);

    // ── Vital değerleri (AppBridge sürekli günceller, biz 10s'de bir yazarız)
    void updateVitals(bool pulseConnected, int pulse,
                      bool spo2Connected, int spo2);

    // ── UI için listeleme ────────────────────────────────────
    Q_INVOKABLE QVariantList listEvents() const;       // özet: id, tarih, süre, yönlendirme
    Q_INVOKABLE QVariantMap  loadEvent(const QString& eventId) const;  // tüm detay
    Q_INVOKABLE QString      videoDir(const QString& eventId) const;   // mutlak yol (file://)
    Q_INVOKABLE QStringList  listSegmentUrls(const QString& eventId) const;
    Q_INVOKABLE void         deleteEvent(const QString& eventId);
    Q_INVOKABLE bool         deleteAllEvents();

signals:
    void recordingChanged();
    void currentEventIdChanged();
    void eventsListChanged();

private slots:
    void onVitalsTimer();
    void onFfmpegStateChanged(QProcess::ProcessState state);
    void onFfmpegError(QProcess::ProcessError error);

private:
    QString eventsRootDir() const;
    QString eventPath(const QString& id) const;
    void    writeLogLine(const QVariantMap& obj);
    qint64  eventElapsedSec() const;
    void    startVideoRecording();
    void    stopVideoRecording();

    static QString formatEventIdFromNow();
    static QString prettyDateFromId(const QString& id);

private:
    bool recording_ = false;
    QString currentEventId_;
    QString currentEventDir_;

    QFile logFile_;                // events.jsonl - append-only
    QElapsedTimer clock_;          // event başından itibaren geçen süre
    QTimer vitalsTimer_;           // 10s periyot

    // En son güncel vital değerler (AppBridge sensörden günceller)
    bool lastPulseConnected_ = false;
    int  lastPulse_          = -1;
    bool lastSpo2Connected_  = false;
    int  lastSpo2_           = -1;

    QProcess* ffmpeg_ = nullptr;

    // Özet: kaydın sonundaki/son yönlendirmesi ve son Q&A'lar (quick-look için)
    QString lastGuidanceScreen_;
    QString lastGuidanceDiagnosis_;
};
