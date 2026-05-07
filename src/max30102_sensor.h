#pragma once

#include <QObject>
#include <QElapsedTimer>
#include <QTimer>
#include <QString>

#include <cstdint>
#include <cstddef>
#include <deque>
#include <vector>

struct Max30102Sample {
    uint32_t red = 0;
    uint32_t ir = 0;
    qint64 timestampMs = 0;
};

struct VitalReading {
    bool available = false;
    bool fingerPresent = false;
    bool signalStable = false;
    bool pulseDetected = false;

    double heartRateBpm = 0.0;
    double spo2 = 0.0;
    double signalQuality = 0.0;
    double perfusion = 0.0;

    bool rateTooLow = false;
    bool rateTooHigh = false;

    QString statusText;
};

class Max30102Sensor : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(bool available READ available NOTIFY dataChanged)
    Q_PROPERTY(bool fingerPresent READ fingerPresent NOTIFY dataChanged)
    Q_PROPERTY(bool signalStable READ signalStable NOTIFY dataChanged)
    Q_PROPERTY(bool pulseDetected READ pulseDetected NOTIFY dataChanged)
    Q_PROPERTY(double heartRateBpm READ heartRateBpm NOTIFY dataChanged)
    Q_PROPERTY(double spo2 READ spo2 NOTIFY dataChanged)
    Q_PROPERTY(double signalQuality READ signalQuality NOTIFY dataChanged)
    Q_PROPERTY(double perfusion READ perfusion NOTIFY dataChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY dataChanged)
    Q_PROPERTY(bool cprLikelyWorking READ cprLikelyWorking NOTIFY dataChanged)

public:
    explicit Max30102Sensor(QObject* parent = nullptr);
    ~Max30102Sensor() override;

    bool start(const QString& device = "/dev/i2c-1");
    void stop();

    bool running() const { return m_running; }

    bool available() const { return m_reading.available; }
    bool fingerPresent() const { return m_reading.fingerPresent; }
    bool signalStable() const { return m_reading.signalStable; }
    bool pulseDetected() const { return m_reading.pulseDetected; }
    double heartRateBpm() const { return m_reading.heartRateBpm; }
    double spo2() const { return m_reading.spo2; }
    double signalQuality() const { return m_reading.signalQuality; }
    double perfusion() const { return m_reading.perfusion; }
    QString statusText() const { return m_reading.statusText; }

    bool cprLikelyWorking() const
    {
        return m_reading.fingerPresent && m_reading.pulseDetected;
    }

    Q_INVOKABLE bool startDefault();
    Q_INVOKABLE void stopSensor();

signals:
    void runningChanged();
    void dataChanged();
    void errorOccurred(const QString& message);

private slots:
    void pollSensor();

private:
    // MAX30100 register map.
    // Dosya/sinif adi projeyi bozmamak icin Max30102Sensor olarak kaldi.
    static constexpr uint8_t I2C_ADDR = 0x57;

    static constexpr uint8_t REG_INTR_STATUS     = 0x00;
    static constexpr uint8_t REG_INTR_ENABLE     = 0x01;
    static constexpr uint8_t REG_FIFO_WR_PTR     = 0x02;
    static constexpr uint8_t REG_OVF_COUNTER     = 0x03;
    static constexpr uint8_t REG_FIFO_RD_PTR     = 0x04;
    static constexpr uint8_t REG_FIFO_DATA       = 0x05;
    static constexpr uint8_t REG_MODE_CONFIG     = 0x06;
    static constexpr uint8_t REG_SPO2_CONFIG     = 0x07;
    static constexpr uint8_t REG_LED_CONFIG      = 0x09;
    static constexpr uint8_t REG_REV_ID          = 0xFE;
    static constexpr uint8_t REG_PART_ID         = 0xFF;

    // MAX30100 ayarlari
    static constexpr int MAX_WINDOW = 900;
    static constexpr double SAMPLE_RATE_HZ = 100.0;
    static constexpr qint64 SAMPLE_PERIOD_MS = 10;

    // 0x47 = high-resolution + 100 sps + 1600 us pulse width.
    // 0x88 = RED/IR yaklasik 27.1 mA. 0x66'dan guclu, 0x99'dan daha kontrollu.
    static constexpr uint8_t DEFAULT_SPO2_CONFIG = 0x47;
    static constexpr uint8_t DEFAULT_LED_CONFIG  = 0x88;

    static constexpr double ADC_MAX_VALUE = 65535.0;

    // Parmak algilama:
    // Parmaksiz durumda ratio genelde ~0.47
    // Parmak takiliyken ratio genelde ~0.64-0.67
    static constexpr double IR_FINGER_MIN_NORM  = 0.220000;
    static constexpr double RED_FINGER_MIN_NORM = 0.380000;

    static constexpr double IR_RED_RATIO_MIN = 0.600000;
    static constexpr double IR_RED_RATIO_MAX = 0.950000;

    static constexpr double ADC_SATURATION_NORM = 0.930000;

    static constexpr qint64 CONTACT_SETTLE_MS = 2500;
    static constexpr int MIN_BPM_WINDOW = 600;
    static constexpr int MIN_SPO2_WINDOW = 500;
    static constexpr int MIN_STABLE_READINGS = 6;
    static constexpr qint64 HOLD_LAST_READING_MS = 3000;

    bool openDevice(const QString& device);
    void closeDevice();

    bool writeReg8(uint8_t reg, uint8_t value);
    bool readReg8(uint8_t reg, uint8_t& value);
    bool readBytes(uint8_t reg, uint8_t* buffer, size_t len);

    bool resetDevice();
    bool configureDevice();
    bool readAvailableSamples(std::vector<Max30102Sample>& outSamples);

    void processSamples(const std::vector<Max30102Sample>& samples);
    void updateReading();
    void resetAlgorithmState();

    double clamp(double x, double lo, double hi) const;

private:
    int m_fd = -1;
    bool m_running = false;
    QTimer m_pollTimer;
    QElapsedTimer m_clock;

    VitalReading m_reading;

    std::deque<uint32_t> m_irWindow;
    std::deque<uint32_t> m_redWindow;

    uint32_t m_lastIr = 0;
    uint32_t m_lastRed = 0;

    qint64 m_sampleCounter = 0;
    qint64 m_lastDebugMs = 0;
    qint64 m_lastSampleMs = 0;
    qint64 m_contactStartMs = 0;
    qint64 m_lastGoodReadingMs = 0;

    int m_validStableCount = 0;

    int m_fingerOnCount = 0;
    int m_fingerOffCount = 0;
    bool m_fingerLatched = false;

    double m_smoothedBpm = 0.0;
    double m_smoothedSpo2 = 0.0;
};
