#include "app_bridge.h"

#include <QCoreApplication>
#include <QDir>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <QWindow>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    AppBridge bridge;
    bridge.initialize(QDir::currentPath() + "/..");

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("appBridge", &bridge);

    const QUrl url(QStringLiteral("qrc:/ui/main.qml"));

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreated,
        &app,
        [url](QObject *obj, const QUrl &objUrl)
        {
            if (!obj && objUrl == url)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection
    );

    engine.load(url);

    if (engine.rootObjects().isEmpty())
        return -1;

    QObject *rootObject = engine.rootObjects().constFirst();
    if (auto *window = qobject_cast<QWindow *>(rootObject))
    {
        window->setFlags(Qt::Window | Qt::FramelessWindowHint);
        window->showFullScreen();
        window->requestActivate();
    }

    return app.exec();
}
