#include "max30102_sensor.h"

#include <QDebug>

#include <algorithm>
#include <cmath>
#include <cerrno>
#include <cstring>
#include <vector>

#include <fcntl.h>
#include <linux/i2c-dev.h>
#include <sys/ioctl.h>
#include <unistd.h>

namespace {

constexpr int kPollMs = 10;

struct BpmResult {
    bool valid = false;
    double bpm = 0.0;
    int beatCount = 0;
    double bpmStd = 0.0;
    double confidence = 0.0;
};

struct Spo2Result {
    bool valid = false;
    double spo2 = 0.0;
    double r = 0.0;
    double irAc = 0.0;
    double redAc = 0.0;
};

double meanDeque(const std::deque<uint32_t>& values)
{
    if (values.empty())
        return 0.0;

    double sum = 0.0;
    for (uint32_t v : values)
        sum += static_cast<double>(v);

    return sum / static_cast<double>(values.size());
}

double meanVector(const std::vector<double>& values)
{
    if (values.empty())
        return 0.0;

    double sum = 0.0;
    for (double v : values)
        sum += v;

    return sum / static_cast<double>(values.size());
}

double stdVector(const std::vector<double>& values)
{
    if (values.size() < 2)
        return 0.0;

    const double m = meanVector(values);

    double acc = 0.0;
    for (double v : values) {
        const double d = v - m;
        acc += d * d;
    }

    return std::sqrt(acc / static_cast<double>(values.size()));
}

std::vector<double> highPassDeque(const std::deque<uint32_t>& values)
{
    std::vector<double> out;

    if (values.size() < 10)
        return out;

    const int n = static_cast<int>(values.size());
    const int window = 75;
    const int half = window / 2;

    std::vector<double> prefix;
    prefix.reserve(n + 1);
    prefix.push_back(0.0);

    for (uint32_t v : values)
        prefix.push_back(prefix.back() + static_cast<double>(v));

    out.reserve(n);

    for (int i = 0; i < n; ++i) {
        const int left = std::max(0, i - half);
        const int right = std::min(n, i + half + 1);
        const double dc = (prefix[right] - prefix[left]) /
                          static_cast<double>(right - left);
        out.push_back(static_cast<double>(values[i]) - dc);
    }

    return out;
}

std::vector<double> smoothVector(const std::vector<double>& values, int width = 5)
{
    if (values.size() < static_cast<size_t>(width))
        return values;

    const int n = static_cast<int>(values.size());
    const int half = width / 2;

    std::vector<double> prefix;
    prefix.reserve(n + 1);
    prefix.push_back(0.0);

    for (double v : values)
        prefix.push_back(prefix.back() + v);

    std::vector<double> out;
    out.reserve(n);

    for (int i = 0; i < n; ++i) {
        const int left = std::max(0, i - half);
        const int right = std::min(n, i + half + 1);
        out.push_back((prefix[right] - prefix[left]) /
                      static_cast<double>(right - left));
    }

    return out;
}

BpmResult estimateBpmByPeaks(const std::vector<double>& ac)
{
    BpmResult result;

    constexpr double fs = 100.0;

    if (ac.size() < 600)
        return result;

    const double acStd = stdVector(ac);

    if (acStd < 6.0)
        return result;

    const double threshold = std::max(5.0, acStd * 0.25);

    const int minDist = static_cast<int>(fs * 0.32);
    const int maxDist = static_cast<int>(fs * 1.70);

    std::vector<int> peaks;
    int lastPeak = -999999;

    for (int i = 1; i < static_cast<int>(ac.size()) - 1; ++i) {
        if (ac[i] > threshold &&
            ac[i] >= ac[i - 1] &&
            ac[i] > ac[i + 1]) {

            if ((i - lastPeak) >= minDist) {
                peaks.push_back(i);
                lastPeak = i;
            }
        }
    }

    std::vector<double> bpms;

    for (int i = 1; i < static_cast<int>(peaks.size()); ++i) {
        const int d = peaks[i] - peaks[i - 1];

        if (d >= minDist && d <= maxDist) {
            const double bpm = 60.0 * fs / static_cast<double>(d);

            if (bpm >= 35.0 && bpm <= 180.0)
                bpms.push_back(bpm);
        }
    }

    if (bpms.size() < 4)
        return result;

    std::vector<double> sorted = bpms;
    std::sort(sorted.begin(), sorted.end());

    double median = 0.0;
    const size_t mid = sorted.size() / 2;

    if (sorted.size() % 2 == 0)
        median = (sorted[mid - 1] + sorted[mid]) / 2.0;
    else
        median = sorted[mid];

    std::vector<double> filtered;

    for (double b : bpms) {
        if (std::abs(b - median) <= std::max(10.0, median * 0.14))
            filtered.push_back(b);
    }

    if (filtered.size() < 4)
        return result;

    const double bpmStd = stdVector(filtered);

    if (bpmStd > 18.0)
        return result;

    result.valid = true;
    result.bpm = meanVector(filtered);
    result.beatCount = static_cast<int>(filtered.size());
    result.bpmStd = bpmStd;
    result.confidence = std::max(0.0, 1.0 - bpmStd / 18.0);

    return result;
}

BpmResult estimateBpmByAutocorrelation(const std::vector<double>& ac)
{
    BpmResult result;

    constexpr double fs = 100.0;

    if (ac.size() < 600)
        return result;

    const double acStd = stdVector(ac);

    if (acStd < 6.0)
        return result;

    const int minLag = static_cast<int>(fs * 60.0 / 180.0);
    const int maxLag = static_cast<int>(fs * 60.0 / 35.0);

    double bestCorr = -1.0;
    int bestLag = 0;

    for (int lag = minLag; lag <= maxLag; ++lag) {
        double xy = 0.0;
        double xx = 0.0;
        double yy = 0.0;

        for (int i = lag; i < static_cast<int>(ac.size()); ++i) {
            const double a = ac[i];
            const double b = ac[i - lag];

            xy += a * b;
            xx += a * a;
            yy += b * b;
        }

        if (xx <= 1e-9 || yy <= 1e-9)
            continue;

        const double corr = xy / std::sqrt(xx * yy);

        if (corr > bestCorr) {
            bestCorr = corr;
            bestLag = lag;
        }
    }

    if (bestLag <= 0 || bestCorr < 0.14)
        return result;

    const double bpm = 60.0 * fs / static_cast<double>(bestLag);

    if (bpm < 35.0 || bpm > 180.0)
        return result;

    result.valid = true;
    result.bpm = bpm;
    result.beatCount = 4;
    result.bpmStd = 0.0;
    result.confidence = bestCorr;

    return result;
}

BpmResult estimateBpmFromIr(const std::deque<uint32_t>& irWindow)
{
    if (irWindow.size() < 600)
        return BpmResult{};

    std::vector<double> ac = highPassDeque(irWindow);
    ac = smoothVector(ac, 7);

    BpmResult peak = estimateBpmByPeaks(ac);

    if (peak.valid)
        return peak;

    return estimateBpmByAutocorrelation(ac);
}

Spo2Result estimateSpo2FromWindow(const std::deque<uint32_t>& irWindow,
                                  const std::deque<uint32_t>& redWindow)
{
    Spo2Result result;

    if (irWindow.size() < 500 || redWindow.size() < 500)
        return result;

    const double irDc = meanDeque(irWindow);
    const double redDc = meanDeque(redWindow);

    if (irDc <= 1.0 || redDc <= 1.0)
        return result;

    const std::vector<double> irAcVec = highPassDeque(irWindow);
    const std::vector<double> redAcVec = highPassDeque(redWindow);

    const double irAc = stdVector(irAcVec);
    const double redAc = stdVector(redAcVec);

    if (irAc < 5.0 || redAc < 5.0)
        return result;

    const double r = (redAc / redDc) / (irAc / irDc);

    // MAX30100 prototipte bu aralik disinda SpO2'yi gostermiyoruz.
    // Boylece hatali 70/75 gibi degerler ekrana basilmiyor.
    if (r < 0.35 || r > 1.20)
        return result;

    double spo2 = -45.060 * r * r + 30.354 * r + 94.845;

    if (spo2 < 70.0)
        spo2 = 70.0;

    if (spo2 > 100.0)
        spo2 = 100.0;

    result.valid = true;
    result.spo2 = spo2;
    result.r = r;
    result.irAc = irAc;
    result.redAc = redAc;

    return result;
}

} // namespace

Max30102Sensor::Max30102Sensor(QObject* parent)
    : QObject(parent)
{
    connect(&m_pollTimer, &QTimer::timeout, this, &Max30102Sensor::pollSensor);
    m_pollTimer.setInterval(kPollMs);
}

Max30102Sensor::~Max30102Sensor()
{
    stop();
}

bool Max30102Sensor::startDefault()
{
    return start("/dev/i2c-1");
}

void Max30102Sensor::stopSensor()
{
    stop();
}

bool Max30102Sensor::start(const QString& device)
{
    if (m_running) {
        qInfo() << "[MAX30100] zaten calisiyor";
        return true;
    }

    qInfo() << "[MAX30100] start() cagirildi, device:" << device;

    if (!openDevice(device)) {
        qWarning() << "[MAX30100] openDevice basarisiz";
        emit errorOccurred("MAX30100: I2C device acilamadi");
        return false;
    }

    if (!resetDevice()) {
        qWarning() << "[MAX30100] resetDevice basarisiz";
        emit errorOccurred("MAX30100: reset basarisiz");
        closeDevice();
        return false;
    }

    if (!configureDevice()) {
        qWarning() << "[MAX30100] configureDevice basarisiz";
        emit errorOccurred("MAX30100: konfigurasyon basarisiz");
        closeDevice();
        return false;
    }

    resetAlgorithmState();
    m_reading = VitalReading{};
    m_clock.restart();

    m_running = true;
    m_pollTimer.start();

    qInfo() << "[MAX30100] basariyla baslatildi";

    emit runningChanged();
    emit dataChanged();

    return true;
}

void Max30102Sensor::stop()
{
    if (!m_running && m_fd < 0)
        return;

    m_pollTimer.stop();

    if (m_fd >= 0) {
        writeReg8(REG_LED_CONFIG, 0x00);
        writeReg8(REG_MODE_CONFIG, 0x00);
    }

    closeDevice();

    m_running = false;
    m_reading = VitalReading{};
    resetAlgorithmState();

    emit runningChanged();
    emit dataChanged();
}

void Max30102Sensor::resetAlgorithmState()
{
    m_irWindow.clear();
    m_redWindow.clear();

    m_lastIr = 0;
    m_lastRed = 0;

    m_sampleCounter = 0;
    m_lastDebugMs = 0;
    m_lastSampleMs = 0;
    m_contactStartMs = 0;
    m_lastGoodReadingMs = 0;

    m_validStableCount = 0;

    m_fingerOnCount = 0;
    m_fingerOffCount = 0;
    m_fingerLatched = false;

    m_smoothedBpm = 0.0;
    m_smoothedSpo2 = 0.0;
}

bool Max30102Sensor::openDevice(const QString& device)
{
    m_fd = ::open(device.toLocal8Bit().constData(), O_RDWR);

    if (m_fd < 0) {
        qWarning() << "[MAX30100] open(" << device << ") basarisiz, errno=" << errno
                   << "(" << std::strerror(errno) << ")";
        return false;
    }

    if (ioctl(m_fd, I2C_SLAVE, I2C_ADDR) < 0) {
        qWarning() << "[MAX30100] ioctl I2C_SLAVE 0x57 basarisiz, errno=" << errno
                   << "(" << std::strerror(errno) << ")";
        closeDevice();
        return false;
    }

    qInfo() << "[MAX30100] I2C device acildi:" << device << "addr 0x57";
    return true;
}

void Max30102Sensor::closeDevice()
{
    if (m_fd >= 0) {
        ::close(m_fd);
        m_fd = -1;
    }
}

bool Max30102Sensor::writeReg8(uint8_t reg, uint8_t value)
{
    if (m_fd < 0)
        return false;

    uint8_t data[2] = { reg, value };
    const bool ok = (::write(m_fd, data, 2) == 2);

    if (!ok) {
        qWarning() << "[MAX30100] writeReg8 basarisiz reg=" << reg
                   << "errno=" << errno << "(" << std::strerror(errno) << ")";
    }

    return ok;
}

bool Max30102Sensor::readReg8(uint8_t reg, uint8_t& value)
{
    if (m_fd < 0)
        return false;

    if (::write(m_fd, &reg, 1) != 1) {
        qWarning() << "[MAX30100] readReg8 write basarisiz reg=" << reg
                   << "errno=" << errno << "(" << std::strerror(errno) << ")";
        return false;
    }

    if (::read(m_fd, &value, 1) != 1) {
        qWarning() << "[MAX30100] readReg8 read basarisiz reg=" << reg
                   << "errno=" << errno << "(" << std::strerror(errno) << ")";
        return false;
    }

    return true;
}

bool Max30102Sensor::readBytes(uint8_t reg, uint8_t* buffer, size_t len)
{
    if (m_fd < 0)
        return false;

    if (::write(m_fd, &reg, 1) != 1) {
        qWarning() << "[MAX30100] readBytes write basarisiz reg=" << reg
                   << "errno=" << errno << "(" << std::strerror(errno) << ")";
        return false;
    }

    const ssize_t got = ::read(m_fd, buffer, static_cast<int>(len));

    if (got != static_cast<ssize_t>(len)) {
        qWarning() << "[MAX30100] readBytes read basarisiz reg=" << reg
                   << "beklenen=" << len << "gelen=" << got
                   << "errno=" << errno << "(" << std::strerror(errno) << ")";
        return false;
    }

    return true;
}

bool Max30102Sensor::resetDevice()
{
    if (!writeReg8(REG_MODE_CONFIG, 0x40))
        return false;

    usleep(150000);

    uint8_t mode = 0;

    for (int i = 0; i < 30; ++i) {
        if (!readReg8(REG_MODE_CONFIG, mode))
            return false;

        if ((mode & 0x40) == 0)
            return true;

        usleep(20000);
    }

    return true;
}

bool Max30102Sensor::configureDevice()
{
    uint8_t partId = 0;
    uint8_t revId = 0;

    if (!readReg8(REG_PART_ID, partId))
        return false;

    readReg8(REG_REV_ID, revId);

    qInfo().noquote() << QString("[MAX30100] PART_ID=0x%1 REV_ID=0x%2")
                         .arg(partId, 2, 16, QChar('0'))
                         .arg(revId, 2, 16, QChar('0'));

    if (partId != 0x11) {
        qWarning().noquote() << QString("[MAX30100] Beklenen PART_ID 0x11 degil, okunan=0x%1")
                                .arg(partId, 2, 16, QChar('0'));
    }

    if (!writeReg8(REG_MODE_CONFIG, 0x00)) return false;
    usleep(20000);

    if (!writeReg8(REG_INTR_ENABLE, 0x30)) return false;

    if (!writeReg8(REG_FIFO_WR_PTR, 0x00)) return false;
    if (!writeReg8(REG_OVF_COUNTER, 0x00)) return false;
    if (!writeReg8(REG_FIFO_RD_PTR, 0x00)) return false;

    if (!writeReg8(REG_SPO2_CONFIG, DEFAULT_SPO2_CONFIG)) return false;
    if (!writeReg8(REG_LED_CONFIG, DEFAULT_LED_CONFIG)) return false;

    usleep(20000);

    if (!writeReg8(REG_MODE_CONFIG, 0x03)) return false;

    usleep(100000);

    uint8_t modeCheck = 0;
    uint8_t spo2Check = 0;
    uint8_t ledCheck = 0;
    uint8_t intrCheck = 0;

    readReg8(REG_MODE_CONFIG, modeCheck);
    readReg8(REG_SPO2_CONFIG, spo2Check);
    readReg8(REG_LED_CONFIG, ledCheck);
    readReg8(REG_INTR_STATUS, intrCheck);

    qInfo().noquote() << QString("[MAX30100] MODE=0x%1 SPO2_CONFIG=0x%2 LED_CONFIG=0x%3 INTR=0x%4")
                         .arg(modeCheck, 2, 16, QChar('0'))
                         .arg(spo2Check, 2, 16, QChar('0'))
                         .arg(ledCheck, 2, 16, QChar('0'))
                         .arg(intrCheck, 2, 16, QChar('0'));

    return true;
}

bool Max30102Sensor::readAvailableSamples(std::vector<Max30102Sample>& outSamples)
{
    outSamples.clear();

    uint8_t intr = 0;
    uint8_t wr = 0;
    uint8_t rd = 0;
    uint8_t ovf = 0;

    readReg8(REG_INTR_STATUS, intr);

    if (!readReg8(REG_FIFO_WR_PTR, wr)) return false;
    if (!readReg8(REG_OVF_COUNTER, ovf)) return false;
    if (!readReg8(REG_FIFO_RD_PTR, rd)) return false;

    wr &= 0x0F;
    rd &= 0x0F;
    ovf &= 0x0F;

    int count = static_cast<int>(wr) - static_cast<int>(rd);

    if (count < 0)
        count += 16;

    const bool overflowDetected = (ovf > 0);

    if (count == 0 && overflowDetected)
        count = 16;

    bool forceReadOneSample = false;

    if (count <= 0) {
        if ((intr & 0x30) != 0) {
            count = 1;
            forceReadOneSample = true;
        } else {
            return true;
        }
    }

    if (count > 16)
        count = 16;

    outSamples.reserve(static_cast<size_t>(count));

    const qint64 nowMs = m_clock.elapsed();
    const qint64 firstTs = nowMs - static_cast<qint64>((count - 1) * SAMPLE_PERIOD_MS);

    uint32_t previousIr = m_lastIr;
    uint32_t previousRed = m_lastRed;
    bool hasPrevious = (m_sampleCounter > 0);

    for (int i = 0; i < count; ++i) {
        uint8_t raw[4] = {0};

        if (!readBytes(REG_FIFO_DATA, raw, sizeof(raw)))
            return false;

        const uint32_t ir =
            (static_cast<uint32_t>(raw[0]) << 8) |
             static_cast<uint32_t>(raw[1]);

        const uint32_t red =
            (static_cast<uint32_t>(raw[2]) << 8) |
             static_cast<uint32_t>(raw[3]);

        if (hasPrevious && ir == previousIr && red == previousRed)
            continue;

        previousIr = ir;
        previousRed = red;
        hasPrevious = true;

        outSamples.push_back(Max30102Sample{
            red,
            ir,
            firstTs + static_cast<qint64>(i) * SAMPLE_PERIOD_MS
        });
    }

    if (overflowDetected) {
        writeReg8(REG_FIFO_WR_PTR, 0x00);
        writeReg8(REG_OVF_COUNTER, 0x00);
        writeReg8(REG_FIFO_RD_PTR, 0x00);

        qWarning() << "[MAX30100] FIFO overflow temizlendi. OVF=" << ovf
                   << "WR=" << wr
                   << "RD=" << rd
                   << "okunan=" << outSamples.size();
    }

    if (forceReadOneSample && outSamples.empty()) {
        qWarning() << "[MAX30100] Data-ready geldi ama yeni ornek okunamadi.";
    }

    return true;
}

void Max30102Sensor::processSamples(const std::vector<Max30102Sample>& samples)
{
    if (samples.empty()) {
        const qint64 nowMs = m_clock.elapsed();

        if (m_lastSampleMs > 0 && (nowMs - m_lastSampleMs) > 1500) {
            m_irWindow.clear();
            m_redWindow.clear();

            m_reading.fingerPresent = false;
            m_reading.signalStable = false;
            m_reading.pulseDetected = false;
            m_reading.heartRateBpm = 0.0;
            m_reading.spo2 = 0.0;
            m_reading.signalQuality = 0.0;
            m_reading.perfusion = 0.0;
            m_reading.rateTooLow = false;
            m_reading.rateTooHigh = false;
            m_reading.statusText = "Parmak algilanmadi";

            emit dataChanged();
        }

        return;
    }

    m_lastSampleMs = m_clock.elapsed();

    for (const auto& s : samples) {
        m_lastIr = s.ir;
        m_lastRed = s.red;
        ++m_sampleCounter;

        m_irWindow.push_back(s.ir);
        m_redWindow.push_back(s.red);

        while (static_cast<int>(m_irWindow.size()) > MAX_WINDOW)
            m_irWindow.pop_front();

        while (static_cast<int>(m_redWindow.size()) > MAX_WINDOW)
            m_redWindow.pop_front();
    }
}

void Max30102Sensor::updateReading()
{
    m_reading.available = true;

    auto clearReading = [this](const QString& text) {
        m_reading.fingerPresent = false;
        m_reading.signalStable = false;
        m_reading.pulseDetected = false;
        m_reading.heartRateBpm = 0.0;
        m_reading.spo2 = 0.0;
        m_reading.signalQuality = 0.0;
        m_reading.perfusion = 0.0;
        m_reading.rateTooLow = false;
        m_reading.rateTooHigh = false;
        m_reading.statusText = text;

        m_contactStartMs = 0;
        m_validStableCount = 0;
        m_smoothedBpm = 0.0;
        m_smoothedSpo2 = 0.0;
    };

    if (m_irWindow.empty() || m_redWindow.empty()) {
        clearReading("Veri bekleniyor");
        return;
    }

    const qint64 nowMs = m_clock.elapsed();

    const int tailCount = std::min<int>(10, static_cast<int>(m_irWindow.size()));

    double recentIrMean = 0.0;
    double recentRedMean = 0.0;

    for (int i = 0; i < tailCount; ++i) {
        recentIrMean += m_irWindow[m_irWindow.size() - 1 - i];
        recentRedMean += m_redWindow[m_redWindow.size() - 1 - i];
    }

    recentIrMean /= static_cast<double>(tailCount);
    recentRedMean /= static_cast<double>(tailCount);

    const double recentIrNorm = recentIrMean / ADC_MAX_VALUE;
    const double recentRedNorm = recentRedMean / ADC_MAX_VALUE;

    const double irDc = meanDeque(m_irWindow);
    const double redDc = meanDeque(m_redWindow);

    const std::vector<double> irAcVec = highPassDeque(m_irWindow);
    const std::vector<double> redAcVec = highPassDeque(m_redWindow);

    const double irAc = stdVector(irAcVec);
    const double redAc = stdVector(redAcVec);

    const double irRedRatio =
        recentRedMean > 1.0 ? (recentIrMean / recentRedMean) : 0.0;

    const double irPerfusion =
        irDc > 1.0 ? (irAc / irDc) : 0.0;

    const bool opticalCandidate =
        recentIrNorm >= IR_FINGER_MIN_NORM &&
        recentRedNorm >= RED_FINGER_MIN_NORM &&
        recentIrNorm <= ADC_SATURATION_NORM &&
        recentRedNorm <= ADC_SATURATION_NORM &&
        irRedRatio >= IR_RED_RATIO_MIN &&
        irRedRatio <= IR_RED_RATIO_MAX;

    if (opticalCandidate) {
        m_fingerOnCount++;
        m_fingerOffCount = 0;
    } else {
        m_fingerOffCount++;
        m_fingerOnCount = 0;
    }

    if (!m_fingerLatched && m_fingerOnCount >= 4)
        m_fingerLatched = true;

    if (m_fingerLatched && m_fingerOffCount >= 4)
        m_fingerLatched = false;

    const bool opticalLevelOk = m_fingerLatched;

    if (!opticalLevelOk) {
        clearReading(QString("Parmak algilanmadi IR=%1 RED=%2 IRn=%3 REDn=%4 ratio=%5 AC_IR=%6 perf=%7")
                         .arg(m_lastIr)
                         .arg(m_lastRed)
                         .arg(QString::number(recentIrNorm, 'f', 4))
                         .arg(QString::number(recentRedNorm, 'f', 4))
                         .arg(QString::number(irRedRatio, 'f', 3))
                         .arg(QString::number(irAc, 'f', 1))
                         .arg(QString::number(irPerfusion, 'f', 5)));

        if (!opticalCandidate) {
            m_irWindow.clear();
            m_redWindow.clear();
        }

        return;
    }

    if (m_contactStartMs == 0)
        m_contactStartMs = nowMs;

    m_reading.fingerPresent = true;
    m_reading.signalStable = false;
    m_reading.pulseDetected = false;
    m_reading.heartRateBpm = 0.0;
    m_reading.spo2 = 0.0;
    m_reading.signalQuality = 0.0;
    m_reading.perfusion = irPerfusion * 100.0;
    m_reading.rateTooLow = false;
    m_reading.rateTooHigh = false;

    if ((nowMs - m_contactStartMs) < CONTACT_SETTLE_MS ||
        static_cast<int>(m_irWindow.size()) < MIN_BPM_WINDOW) {

        m_reading.statusText = QString("Parmak algilandi, veri toplaniyor IR=%1 RED=%2 IRn=%3 REDn=%4 ratio=%5 AC_IR=%6")
                                   .arg(m_lastIr)
                                   .arg(m_lastRed)
                                   .arg(QString::number(recentIrNorm, 'f', 4))
                                   .arg(QString::number(recentRedNorm, 'f', 4))
                                   .arg(QString::number(irRedRatio, 'f', 3))
                                   .arg(QString::number(irAc, 'f', 1));
        return;
    }

    const BpmResult bpmResult = estimateBpmFromIr(m_irWindow);
    const Spo2Result spo2Result = estimateSpo2FromWindow(m_irWindow, m_redWindow);

    const bool bpmOk =
        bpmResult.valid &&
        bpmResult.beatCount >= 4 &&
        bpmResult.bpm >= 35.0 &&
        bpmResult.bpm <= 180.0;

    const bool spo2Ok =
        spo2Result.valid &&
        spo2Result.spo2 >= 70.0 &&
        spo2Result.spo2 <= 100.0;

    if (!bpmOk) {
        if (m_smoothedBpm > 0.0 &&
            m_lastGoodReadingMs > 0 &&
            (nowMs - m_lastGoodReadingMs) <= HOLD_LAST_READING_MS) {

            m_reading.fingerPresent = true;
            m_reading.pulseDetected = true;
            m_reading.heartRateBpm = m_smoothedBpm;
            m_reading.spo2 = (m_smoothedSpo2 > 0.0) ? m_smoothedSpo2 : 0.0;
            m_reading.signalQuality = 0.45;
            m_reading.signalStable = true;
            m_reading.perfusion = irPerfusion * 100.0;
            m_reading.rateTooLow = m_smoothedBpm < 60.0;
            m_reading.rateTooHigh = m_smoothedBpm > 120.0;

            m_reading.statusText = QString("Son olcum korunuyor: %1 bpm")
                                       .arg(QString::number(m_smoothedBpm, 'f', 0));
            return;
        }

        m_validStableCount = std::max(0, m_validStableCount - 1);

        m_reading.statusText = QString("Nabiz araniyor IR=%1 RED=%2 AC_IR=%3 AC_RED=%4 ratio=%5 perf=%6")
                                   .arg(m_lastIr)
                                   .arg(m_lastRed)
                                   .arg(QString::number(irAc, 'f', 1))
                                   .arg(QString::number(redAc, 'f', 1))
                                   .arg(QString::number(irRedRatio, 'f', 3))
                                   .arg(QString::number(irPerfusion, 'f', 5));
        return;
    }

    if (m_smoothedBpm <= 0.0) {
        m_smoothedBpm = bpmResult.bpm;
    } else {
        const double diff = std::abs(bpmResult.bpm - m_smoothedBpm);
        const double alpha = (diff > 12.0) ? 0.04 : 0.10;
        m_smoothedBpm = m_smoothedBpm * (1.0 - alpha) + bpmResult.bpm * alpha;
    }

    if (spo2Ok) {
        if (m_smoothedSpo2 <= 0.0)
            m_smoothedSpo2 = spo2Result.spo2;
        else
            m_smoothedSpo2 = m_smoothedSpo2 * 0.97 + spo2Result.spo2 * 0.03;
    }

    m_validStableCount++;

    const bool valueReady = m_validStableCount >= MIN_STABLE_READINGS;

    if (valueReady)
        m_lastGoodReadingMs = nowMs;

    m_reading.fingerPresent = true;
    m_reading.pulseDetected = valueReady;
    m_reading.heartRateBpm = valueReady ? m_smoothedBpm : 0.0;
    m_reading.spo2 = (valueReady && spo2Ok) ? m_smoothedSpo2 : 0.0;

    const double perfusionScore = clamp(irPerfusion / 0.003, 0.0, 1.0);
    const double bpmScore = valueReady ? clamp(bpmResult.confidence, 0.35, 1.0) : 0.0;
    const double spo2Score = (valueReady && spo2Ok) ? 1.0 : 0.0;

    m_reading.signalQuality = clamp(
        perfusionScore * 0.35 +
        bpmScore      * 0.45 +
        spo2Score     * 0.20,
        0.0,
        1.0
    );

    if (!valueReady)
        m_reading.signalQuality = 0.0;

    m_reading.signalStable =
        valueReady &&
        bpmOk &&
        m_reading.signalQuality >= 0.35;

    m_reading.rateTooLow = valueReady && m_smoothedBpm < 60.0;
    m_reading.rateTooHigh = valueReady && m_smoothedBpm > 120.0;

    if (!valueReady) {
        m_reading.statusText = "Olcum kesinlesiyor";
    } else if (!spo2Ok) {
        m_reading.statusText = QString("Nabiz: %1 bpm, SpO2 guvenilir degil Q:%2%")
                                   .arg(QString::number(m_smoothedBpm, 'f', 0))
                                   .arg(QString::number(m_reading.signalQuality * 100.0, 'f', 0));
    } else if (!m_reading.signalStable) {
        m_reading.statusText = QString("Nabiz: %1 bpm, SpO2: %2%, sinyal zayif Q:%3%")
                                   .arg(QString::number(m_smoothedBpm, 'f', 0))
                                   .arg(QString::number(m_smoothedSpo2, 'f', 0))
                                   .arg(QString::number(m_reading.signalQuality * 100.0, 'f', 0));
    } else {
        m_reading.statusText = QString("Nabiz: %1 bpm  SpO2: %2%  Q:%3%")
                                   .arg(QString::number(m_smoothedBpm, 'f', 0))
                                   .arg(QString::number(m_smoothedSpo2, 'f', 0))
                                   .arg(QString::number(m_reading.signalQuality * 100.0, 'f', 0));
    }

    if (nowMs - m_lastDebugMs >= 1000) {
        m_lastDebugMs = nowMs;

        qInfo().noquote() << QString("[MAX30100 DATA] IR=%1 RED=%2 IRn=%3 REDn=%4 ratio=%5 finger=%6 pulse=%7 stable=%8 bpm=%9 spo2=%10 q=%11 perf=%12 valid=%13 samples=%14 AC_IR=%15 AC_RED=%16")
                             .arg(m_lastIr)
                             .arg(m_lastRed)
                             .arg(QString::number(static_cast<double>(m_lastIr) / ADC_MAX_VALUE, 'f', 4))
                             .arg(QString::number(static_cast<double>(m_lastRed) / ADC_MAX_VALUE, 'f', 4))
                             .arg(QString::number(irRedRatio, 'f', 3))
                             .arg(m_reading.fingerPresent)
                             .arg(m_reading.pulseDetected)
                             .arg(m_reading.signalStable)
                             .arg(QString::number(m_reading.heartRateBpm, 'f', 1))
                             .arg(QString::number(m_reading.spo2, 'f', 1))
                             .arg(QString::number(m_reading.signalQuality, 'f', 2))
                             .arg(QString::number(m_reading.perfusion, 'f', 3))
                             .arg(m_validStableCount)
                             .arg(m_sampleCounter)
                             .arg(QString::number(irAc, 'f', 1))
                             .arg(QString::number(redAc, 'f', 1));
    }
}

void Max30102Sensor::pollSensor()
{
    if (!m_running)
        return;

    std::vector<Max30102Sample> samples;

    if (!readAvailableSamples(samples)) {
        m_reading.available = false;
        m_reading.fingerPresent = false;
        m_reading.signalStable = false;
        m_reading.pulseDetected = false;
        m_reading.heartRateBpm = 0.0;
        m_reading.spo2 = 0.0;
        m_reading.signalQuality = 0.0;
        m_reading.perfusion = 0.0;
        m_reading.statusText = "Sensor okunamadi";
        emit dataChanged();
        return;
    }

    const qint64 nowMs = m_clock.elapsed();

    if (samples.empty()) {
        if (m_lastSampleMs > 0 && (nowMs - m_lastSampleMs) > 1500) {
            m_reading.fingerPresent = false;
            m_reading.signalStable = false;
            m_reading.pulseDetected = false;
            m_reading.heartRateBpm = 0.0;
            m_reading.spo2 = 0.0;
            m_reading.signalQuality = 0.0;
            m_reading.perfusion = 0.0;
            m_reading.rateTooLow = false;
            m_reading.rateTooHigh = false;
            m_reading.statusText = "Parmak algilanmadi";

            resetAlgorithmState();
            emit dataChanged();
        }

        return;
    }

    processSamples(samples);
    updateReading();

    emit dataChanged();
}

double Max30102Sensor::clamp(double x, double lo, double hi) const
{
    if (x < lo)
        return lo;

    if (x > hi)
        return hi;

    return x;
}
