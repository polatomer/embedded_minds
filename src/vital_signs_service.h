#pragma once

#include <QObject>
#include <QString>

#include "max30102_sensor.h"

class VitalSignsService : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool sensorRunning READ sensorRunning NOTIFY changed)
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(bool fingerPresent READ fingerPresent NOTIFY changed)
    Q_PROPERTY(bool signalStable READ signalStable NOTIFY changed)
    Q_PROPERTY(bool pulseDetected READ pulseDetected NOTIFY changed)
    Q_PROPERTY(bool cprLikelyWorking READ cprLikelyWorking NOTIFY changed)
    Q_PROPERTY(double heartRateBpm READ heartRateBpm NOTIFY changed)
    Q_PROPERTY(double spo2 READ spo2 NOTIFY changed)
    Q_PROPERTY(double signalQuality READ signalQuality NOTIFY changed)
    Q_PROPERTY(double perfusion READ perfusion NOTIFY changed)
    Q_PROPERTY(QString statusText READ statusText NOTIFY changed)

public:
    explicit VitalSignsService(QObject* parent = nullptr);

    bool sensorRunning() const;
    bool available() const;
    bool fingerPresent() const;
    bool signalStable() const;
    bool pulseDetected() const;
    bool cprLikelyWorking() const;
    double heartRateBpm() const;
    double spo2() const;
    double signalQuality() const;
    double perfusion() const;
    QString statusText() const;

    Q_INVOKABLE bool start();
    Q_INVOKABLE bool startOptional();
    Q_INVOKABLE void stop();

signals:
    void changed();
    void errorOccurred(const QString& message);

private:
    Max30102Sensor m_sensor;
    QString m_statusOverride;
};
