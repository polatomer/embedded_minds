#pragma once

#include <QLocalServer>
#include <QLocalSocket>
#include <QObject>

class VoiceCommandServer : public QObject
{
    Q_OBJECT

public:
    explicit VoiceCommandServer(QObject* parent = nullptr);
    ~VoiceCommandServer() override;

    bool start(const QString& socketName = "aks_voice");
    void stop();

signals:
    void commandReceived(const QString& command);

private slots:
    void onNewConnection();
    void onReadyRead();

private:
    QLocalServer* server_  = nullptr;
    QLocalSocket* socket_  = nullptr;
};
