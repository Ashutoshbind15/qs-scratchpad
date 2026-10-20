#include <qqml.h>
#include <QQmlExtensionPlugin>
#include <QCoreApplication>
#include <QJSEngine>
#include <QVersionNumber>
#include <private/qcoreapplication_p.h>

// Quickshell (0.3.1 and 0.3.2) constructs QGuiApplication with argc == 0, and
// Chromium aborts the whole process without a program name. Supply one before
// any view is created; leave hosts that already pass arguments alone.
//
// QCoreApplicationPrivate's layout is only valid for the Qt minor version this
// file was compiled against. A module left over from an older Qt still loads
// (Qt's symbol versions are backward compatible), so writing to it after a Qt
// update would corrupt memory. Check the running Qt first and report the
// editor as unavailable instead; `prepare-editor` rebuilds the module.
static bool patchArguments() {
    if (!QCoreApplication::arguments().isEmpty()) return true;
    const QVersionNumber running = QVersionNumber::fromString(QString::fromLatin1(qVersion()));
    if (running.majorVersion() != QT_VERSION_MAJOR || running.minorVersion() != QT_VERSION_MINOR) {
        qWarning("ScratchpadWeb was built for Qt %s but Qt %s is running; run prepare-editor",
                 QT_VERSION_STR, qVersion());
        return false;
    }
    auto *app = static_cast<QCoreApplicationPrivate *>(QObjectPrivate::get(QCoreApplication::instance()));
    static char name[] = "quickshell-scratchpad";
    static char *arguments[] = {name, nullptr};
    app->argv = arguments;
    app->argc = 1;
    return !QCoreApplication::arguments().isEmpty();
}

class ScratchpadWebPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override {
        static const bool available = patchArguments();
        // Chromium's GPU compositor shares Qt Quick's graphics context in this
        // process and can leave the view black after the window is parked,
        // the screen sleeps, or Qt and QtWebEngine versions drift apart.
        // Software compositing is plenty for a text editor.
        QByteArray flags = qgetenv("QTWEBENGINE_CHROMIUM_FLAGS");
        if (!flags.contains("--disable-gpu"))
            qputenv("QTWEBENGINE_CHROMIUM_FLAGS", (flags + " --disable-gpu").trimmed());
        qmlRegisterModule(uri, 1, 0);
        qmlRegisterSingletonType(uri, 1, 0, "WebSupport", [](QQmlEngine *, QJSEngine *engine) {
            QJSValue support = engine->newObject();
            support.setProperty("available", available);
            return support;
        });
    }
};
#include "plugin.moc"
