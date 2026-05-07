#include "vital_signs_service.h"

#include <QFileInfo>

VitalSignsService::VitalSignsService(QObject* parent)
    : QObject(parent)
{
    connect(&m_sensor, &Max30102Sensor::dataChanged, this, &VitalSignsService::changed);
    connect(&m_sensor, &Max30102Sensor::runningChanged, this, &VitalSignsService::changed);
    connect(&m_sensor, &Max30102Sensor::errorOccurred, this, &VitalSignsService::errorOccurred);
}

bool VitalSignsService::sensorRunning() const
{
    return m_sensor.running();
}

bool VitalSignsService::available() const
{
    return m_sensor.available();
}

bool VitalSignsService::fingerPresent() const
{
    return m_sensor.fingerPresent();
}

bool VitalSignsService::signalStable() const
{
    return m_sensor.signalStable();
}

bool VitalSignsService::pulseDetected() const
{
    return m_sensor.pulseDetected();
}

bool VitalSignsService::cprLikelyWorking() const
{
    return m_sensor.cprLikelyWorking();
}

double VitalSignsService::heartRateBpm() const
{
    return m_sensor.heartRateBpm();
}

double VitalSignsService::spo2() const
{
    return m_sensor.spo2();
}

double VitalSignsService::signalQuality() const
{
    return m_sensor.signalQuality();
}

double VitalSignsService::perfusion() const
{
    return m_sensor.perfusion();
}

QString VitalSignsService::statusText() const
{
    if (!m_statusOverride.isEmpty())
        return m_statusOverride;

    return m_sensor.statusText();
}

bool VitalSignsService::start()
{
    m_statusOverride.clear();
    const bool ok = m_sensor.startDefault();
    emit changed();
    return ok;
}

bool VitalSignsService::startOptional()
{
    const QString dev = "/dev/i2c-1";

    // Sensör bus'ı yoksa uygulama sensörsüz devam etsin.
    if (!QFileInfo::exists(dev)) {
        m_statusOverride = "Sensör pasif";
        emit changed();
        return false;
    }

    m_statusOverride.clear();

    // Bus var ama sensör takılı değilse de uygulama devam etsin.
    const bool ok = m_sensor.startDefault();
    if (!ok) {
        m_statusOverride = "Sensör bagli degil";
        emit changed();
        return false;
    }

    emit changed();
    return true;
}

void VitalSignsService::stop()
{
    m_sensor.stop();
    m_statusOverride = "Sensör durduruldu";
    emit changed();
}
