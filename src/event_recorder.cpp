#include "event_recorder.h"

#ifdef Q_OS_UNIX
#include <unistd.h>
#endif

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QStandardPaths>
#include <QUrl>

namespace {
constexpr const char* kCameraDevice   = "/dev/video0";
constexpr const char* kVideoSize      = "640x480";
constexpr const char* kVideoFramerate = "15";
constexpr int kSegmentSeconds         = 60;
constexpr int kVitalsIntervalMs = 10000;

QString dateFormatDisplay(const QDateTime& dt)
{
    return dt.toString("dd.MM.yyyy HH:mm:ss");
}
}

EventRecorder::EventRecorder(QObject* parent)
    : QObject(parent)
{
    vitalsTimer_.setInterval(kVitalsIntervalMs);
    connect(&vitalsTimer_, &QTimer::timeout,
            this, &EventRecorder::onVitalsTimer);
}

EventRecorder::~EventRecorder()
{
    if (recording_)
        endEvent();
}

bool EventRecorder::recording() const { return recording_; }
QString EventRecorder::currentEventId() const { return currentEventId_; }

QString EventRecorder::eventsRootDir() const
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return QDir(base).filePath("events");
}

QString EventRecorder::eventPath(const QString& id) const
{
    return QDir(eventsRootDir()).filePath(id);
}

QString EventRecorder::formatEventIdFromNow()
{
    return QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
}

QString EventRecorder::prettyDateFromId(const QString& id)
{
    const QDateTime dt = QDateTime::fromString(id, "yyyyMMdd_HHmmss");
    if (dt.isValid())
        return dateFormatDisplay(dt);
    return id;
}

void EventRecorder::writeLogLine(const QVariantMap& obj)
{
    if (!logFile_.isOpen())
        return;

    QJsonObject jo = QJsonObject::fromVariantMap(obj);
    QJsonDocument doc(jo);
    QByteArray line = doc.toJson(QJsonDocument::Compact) + "\n";

    logFile_.write(line);
    logFile_.flush();

    const int fd = logFile_.handle();
    if (fd >= 0) {
#ifdef Q_OS_UNIX
        ::fsync(fd);
#endif
    }
}

qint64 EventRecorder::eventElapsedSec() const
{
    return clock_.isValid() ? (clock_.elapsed() / 1000) : 0;
}

void EventRecorder::startEvent()
{
    if (recording_)
        endEvent();

    const QString id = formatEventIdFromNow();
    const QString dirPath = eventPath(id);
    QDir().mkpath(dirPath);
    QDir().mkpath(QDir(dirPath).filePath("video"));

    currentEventId_  = id;
    currentEventDir_ = dirPath;

    logFile_.setFileName(QDir(dirPath).filePath("events.jsonl"));
    if (!logFile_.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        qWarning() << "Log dosyasi acilamadi:" << logFile_.fileName();
        return;
    }

    clock_.start();
    recording_ = true;

    QVariantMap start;
    start["t"]    = 0;
    start["type"] = "start";
    start["wall"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    writeLogLine(start);

    startVideoRecording();
    vitalsTimer_.start();

    lastGuidanceScreen_.clear();
    lastGuidanceDiagnosis_.clear();

    emit recordingChanged();
    emit currentEventIdChanged();
}

void EventRecorder::endEvent()
{
    if (!recording_)
        return;

    vitalsTimer_.stop();

    if (logFile_.isOpen()) {
        QVariantMap vm;
        vm["t"]     = eventElapsedSec();
        vm["type"]  = "vitals";
        vm["pulse"] = (lastPulseConnected_ && lastPulse_ > 0) ? lastPulse_ : -1;
        vm["spo2"]  = (lastSpo2Connected_  && lastSpo2_  > 0) ? lastSpo2_  : -1;
        writeLogLine(vm);

        QVariantMap endObj;
        endObj["t"]    = eventElapsedSec();
        endObj["type"] = "end";
        writeLogLine(endObj);

        logFile_.close();
    }

    stopVideoRecording();

    recording_ = false;
    currentEventId_.clear();
    currentEventDir_.clear();

    emit recordingChanged();
    emit currentEventIdChanged();
    emit eventsListChanged();
}

void EventRecorder::logQuestion(const QString& q, const QString& a)
{
    if (!recording_) return;
    QVariantMap m;
    m["t"]    = eventElapsedSec();
    m["type"] = "question";
    m["q"]    = q;
    m["a"]    = a;
    writeLogLine(m);
}

void EventRecorder::logGuidance(const QString& screenId, const QString& diagnosis)
{
    if (!recording_) return;
    lastGuidanceScreen_    = screenId;
    lastGuidanceDiagnosis_ = diagnosis;

    QVariantMap m;
    m["t"]         = eventElapsedSec();
    m["type"]      = "guidance";
    m["screen"]    = screenId;
    m["diagnosis"] = diagnosis;
    writeLogLine(m);
}

void EventRecorder::logDecision(const QString& category,
                                const QString& q, const QString& a)
{
    if (!recording_) return;
    QVariantMap m;
    m["t"]        = eventElapsedSec();
    m["type"]     = "decision";
    m["category"] = category;
    m["q"]        = q;
    m["a"]        = a;
    writeLogLine(m);
}

void EventRecorder::updateVitals(bool pulseConnected, int pulse,
                                 bool spo2Connected, int spo2)
{
    if (!pulseConnected) {
        lastPulseConnected_ = false;
        lastPulse_ = -1;
    } else {
        lastPulseConnected_ = true;
        if (pulse > 0)
            lastPulse_ = pulse;
    }

    if (!spo2Connected) {
        lastSpo2Connected_ = false;
        lastSpo2_ = -1;
    } else {
        lastSpo2Connected_ = true;
        if (spo2 > 0)
            lastSpo2_ = spo2;
    }
}

void EventRecorder::onVitalsTimer()
{
    if (!recording_) return;

    QVariantMap m;
    m["t"]     = eventElapsedSec();
    m["type"]  = "vitals";
    m["pulse"] = (lastPulseConnected_ && lastPulse_ > 0) ? lastPulse_ : -1;
    m["spo2"]  = (lastSpo2Connected_  && lastSpo2_  > 0) ? lastSpo2_  : -1;
    writeLogLine(m);
}

void EventRecorder::startVideoRecording()
{
    if (ffmpeg_) {
        stopVideoRecording();
    }

    if (!QFileInfo::exists(kCameraDevice)) {
        qWarning() << "Kamera bulunamadi:" << kCameraDevice
                   << "- video kaydi yapilmayacak";
        return;
    }

    const QString videoPattern = QDir(currentEventDir_).filePath("video/segment_%03d.mkv");

    QStringList args;
    args << "-y"
         << "-hide_banner"
         << "-loglevel" << "warning"
         << "-f" << "v4l2"
         << "-framerate" << kVideoFramerate
         << "-video_size" << kVideoSize
         << "-i" << kCameraDevice
         << "-c:v" << "libx264"
         << "-preset" << "ultrafast"
         << "-tune" << "zerolatency"
         << "-pix_fmt" << "yuv420p"
         << "-g" << kVideoFramerate
         << "-f" << "segment"
         << "-segment_time" << QString::number(kSegmentSeconds)
         << "-segment_format" << "matroska"
         << "-reset_timestamps" << "1"
         << "-strftime" << "0"
         << videoPattern;

    ffmpeg_ = new QProcess(this);
    ffmpeg_->setProcessChannelMode(QProcess::MergedChannels);

    connect(ffmpeg_, &QProcess::stateChanged,
            this, &EventRecorder::onFfmpegStateChanged);
    connect(ffmpeg_, &QProcess::errorOccurred,
            this, &EventRecorder::onFfmpegError);

    ffmpeg_->start("ffmpeg", args);

    if (!ffmpeg_->waitForStarted(3000)) {
        qWarning() << "ffmpeg baslatilamadi:" << ffmpeg_->errorString();
        ffmpeg_->deleteLater();
        ffmpeg_ = nullptr;
    } else {
        qInfo() << "Video kaydi basladi:" << videoPattern;
    }
}

void EventRecorder::stopVideoRecording()
{
    if (!ffmpeg_) return;

    if (ffmpeg_->state() == QProcess::Running) {
        ffmpeg_->write("q\n");
        ffmpeg_->closeWriteChannel();

        if (!ffmpeg_->waitForFinished(5000)) {
            qWarning() << "ffmpeg graceful kapanmadi, terminate ediliyor";
            ffmpeg_->terminate();
            if (!ffmpeg_->waitForFinished(2000)) {
                ffmpeg_->kill();
                ffmpeg_->waitForFinished(1000);
            }
        }
    }

    ffmpeg_->deleteLater();
    ffmpeg_ = nullptr;
}

void EventRecorder::onFfmpegStateChanged(QProcess::ProcessState state)
{
    qDebug() << "ffmpeg state:" << state;
}

void EventRecorder::onFfmpegError(QProcess::ProcessError error)
{
    qWarning() << "ffmpeg error:" << error
               << (ffmpeg_ ? ffmpeg_->errorString() : QString());
}

QVariantList EventRecorder::listEvents() const
{
    QVariantList list;
    QDir root(eventsRootDir());
    if (!root.exists()) return list;

    QStringList ids = root.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    std::sort(ids.begin(), ids.end(), std::greater<QString>());

    for (const QString& id : ids) {
        if (recording_ && id == currentEventId_)
            continue;

        QVariantMap summary;
        summary["id"]          = id;
        summary["date"]        = prettyDateFromId(id);
        summary["diagnosis"]   = "";
        summary["screen"]      = "";
        summary["durationSec"] = 0;
        summary["segments"]    = 0;

        QFile f(QDir(eventPath(id)).filePath("events.jsonl"));
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            qint64 lastT = 0;
            while (!f.atEnd()) {
                QByteArray line = f.readLine().trimmed();
                if (line.isEmpty()) continue;
                QJsonDocument doc = QJsonDocument::fromJson(line);
                if (!doc.isObject()) continue;
                QJsonObject o = doc.object();
                const QString type = o.value("type").toString();

                if (o.contains("t"))
                    lastT = o.value("t").toVariant().toLongLong();

                if (type == "guidance") {
                    summary["diagnosis"] = o.value("diagnosis").toString();
                    summary["screen"]    = o.value("screen").toString();
                }
            }
            summary["durationSec"] = lastT;
        }

        QDir videoDir(QDir(eventPath(id)).filePath("video"));
        summary["segments"] = videoDir.entryList(QStringList() << "segment_*.mkv",
                                                 QDir::Files).size();

        list << summary;
    }

    return list;
}

QVariantMap EventRecorder::loadEvent(const QString& eventId) const
{
    QVariantMap result;
    result["id"]        = eventId;
    result["date"]      = prettyDateFromId(eventId);
    result["entries"]   = QVariantList();
    result["vitals"]    = QVariantList();
    result["questions"] = QVariantList();
    result["decisions"] = QVariantList();
    result["guidance"]  = QVariantMap();
    result["segments"]  = listSegmentUrls(eventId);

    QFile f(QDir(eventPath(eventId)).filePath("events.jsonl"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return result;

    QVariantList entries, vitals, questions, decisions;
    QVariantMap guidance;
    qint64 lastT = 0;

    while (!f.atEnd()) {
        QByteArray line = f.readLine().trimmed();
        if (line.isEmpty()) continue;
        QJsonDocument doc = QJsonDocument::fromJson(line);
        if (!doc.isObject()) continue;

        QVariantMap obj = doc.object().toVariantMap();
        const QString type = obj.value("type").toString();
        const qint64 t = obj.value("t").toLongLong();
        lastT = std::max(lastT, t);

        entries << obj;

        if (type == "vitals") {
            vitals << obj;
        } else if (type == "question") {
            questions << obj;
        } else if (type == "decision") {
            decisions << obj;
        } else if (type == "guidance") {
            guidance = obj;
        }
    }

    result["entries"]     = entries;
    result["vitals"]      = vitals;
    result["questions"]   = questions;
    result["decisions"]   = decisions;
    result["guidance"]    = guidance;
    result["durationSec"] = lastT;

    return result;
}

QString EventRecorder::videoDir(const QString& eventId) const
{
    return QDir(eventPath(eventId)).filePath("video");
}

QStringList EventRecorder::listSegmentUrls(const QString& eventId) const
{
    QStringList urls;
    QDir videoDir(QDir(eventPath(eventId)).filePath("video"));
    if (!videoDir.exists()) return urls;

    QStringList files = videoDir.entryList(QStringList() << "segment_*.mkv",
                                           QDir::Files, QDir::Name);
    for (const QString& name : files) {
        urls << QUrl::fromLocalFile(videoDir.filePath(name)).toString();
    }
    return urls;
}

void EventRecorder::deleteEvent(const QString& eventId)
{
    if (eventId.isEmpty()) return;
    if (recording_ && eventId == currentEventId_) {
        qWarning() << "Aktif kayit silinemiyor:" << eventId;
        return;
    }

    QDir d(eventPath(eventId));
    if (d.exists()) {
        d.removeRecursively();
        emit eventsListChanged();
    }
}

bool EventRecorder::deleteAllEvents()
{
    if (recording_) {
        qWarning() << "Aktif kayit varken tum veritabani silinemez";
        return false;
    }

    QDir root(eventsRootDir());
    if (!root.exists()) {
        emit eventsListChanged();
        return true;
    }

    bool ok = true;

    const QStringList dirs = root.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QString& name : dirs) {
        QDir d(root.filePath(name));
        if (!d.removeRecursively()) {
            ok = false;
            qWarning() << "Silinemeyen event klasoru:" << d.path();
        }
    }

    emit eventsListChanged();
    return ok;
}
