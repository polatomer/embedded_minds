#include "voice_command_server.h"
#include <QDebug>

VoiceCommandServer::VoiceCommandServer(QObject* parent)
    : QObject(parent)
{
}

VoiceCommandServer::~VoiceCommandServer()
{
    stop();
}

bool VoiceCommandServer::start(const QString& socketName)
{
    server_ = new QLocalServer(this);

    // Önceki çökmüş süreçten kalan soket dosyasını temizle
    QLocalServer::removeServer(socketName);

    if (!server_->listen(socketName)) {
        qWarning() << "[VoiceServer] listen basarisiz:" << server_->errorString();
        return false;
    }

    connect(server_, &QLocalServer::newConnection,
            this, &VoiceCommandServer::onNewConnection);

    qInfo() << "[VoiceServer] Dinleniyor, socket:" << socketName;
    return true;
}

void VoiceCommandServer::stop()
{
    if (socket_) {
        socket_->disconnectFromServer();
        socket_ = nullptr;
    }

    if (server_) {
        server_->close();
        server_ = nullptr;
    }
}

void VoiceCommandServer::onNewConnection()
{
    // Tek Python client — önceki bağlantıyı kapat
    if (socket_) {
        socket_->disconnectFromServer();
        socket_ = nullptr;
    }

    socket_ = server_->nextPendingConnection();

    connect(socket_, &QLocalSocket::readyRead,
            this, &VoiceCommandServer::onReadyRead);

    connect(socket_, &QLocalSocket::disconnected, this, [this]() {
        qInfo() << "[VoiceServer] Python baglantisi kesildi";
        socket_ = nullptr;
    });

    qInfo() << "[VoiceServer] Python client baglandi";
}

void VoiceCommandServer::onReadyRead()
{
    if (!socket_)
        return;

    while (socket_->canReadLine()) {
        const QString cmd = QString::fromUtf8(socket_->readLine()).trimmed();

        if (!cmd.isEmpty()) {
            qInfo() << "[VoiceCmd] Komut alindi:" << cmd;
            emit commandReceived(cmd);
        }
    }
}
