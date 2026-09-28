/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * Author:     devalexandre <alexandre@dev2learn.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <QApplication>
#include <QCommandLineParser>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QIcon>
#include <QLocale>
#include <QQmlEngine>
#include <QSettings>
#include <QStandardPaths>
#include <QTranslator>

#include "flatpakbackend.h"
#include "storeapp.h"

static const QString DBusService = QStringLiteral("com.lingmo.Store");
static const QString DBusPath = QStringLiteral("/Store");

// The Lingmo platform theme doesn't always hand the icon theme over at startup:
// use the one set in Lingmo Settings.
static void applyIconTheme()
{
    const QString current = QIcon::themeName();
    if (!current.isEmpty() && current != QLatin1String("hicolor"))
        return;
    QSettings theme(QStringLiteral("lingmoos"), QStringLiteral("theme"));
    const bool dark = theme.value(QStringLiteral("DarkMode"), false).toBool();
    const QStringList candidates = {
        theme.value(dark ? QStringLiteral("DarkIconTheme") : QStringLiteral("IconTheme")).toString(),
        dark ? QStringLiteral("Crule-dark") : QStringLiteral("Crule"),
        QStringLiteral("breeze"),
    };
    for (const QString &name : candidates) {
        if (!name.isEmpty()
            && !QStandardPaths::locate(QStandardPaths::GenericDataLocation,
                                       QStringLiteral("icons/%1/index.theme").arg(name)).isEmpty()) {
            QIcon::setThemeName(name);
            break;
        }
    }
    QIcon::setFallbackThemeName(QStringLiteral("hicolor"));
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("lingmo-store"));
    app.setApplicationVersion(QStringLiteral(LINGMO_STORE_VERSION));
    app.setDesktopFileName(QStringLiteral("lingmo-store"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Lingmo App Store"));
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addOption({QStringLiteral("app"),
                      QStringLiteral("Open the page of an app: AppStream or Flathub id, flatpak ref or Arch package name"),
                      QStringLiteral("id")});
    parser.addOption({QStringLiteral("search"), QStringLiteral("Search for apps"), QStringLiteral("text")});
    parser.addOption({QStringLiteral("games"), QStringLiteral("Open the games page")});
    parser.addPositionalArgument(QStringLiteral("url"), QStringLiteral("appstream://<id> link or .flatpakref file"),
                                 QStringLiteral("[url]"));
    parser.process(app);
    const QStringList arguments = app.arguments().mid(1);

    // One instance per session: a second one hands its arguments to the first
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerService(DBusService)) {
        QDBusInterface iface(DBusService, DBusPath, DBusService, bus);
        const QDBusMessage reply = iface.call(QStringLiteral("activate"), arguments);
        if (reply.type() == QDBusMessage::ErrorMessage)
            qWarning("Could not reach the running Lingmo Store: %s", qPrintable(reply.errorMessage()));
        return 0;
    }

    applyIconTheme();
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("system-software-install")));

    // Installed location first, then next to the binary (build tree, staged installs)
    QTranslator translator;
    for (const QString &dir : {QStringLiteral(TRANSLATIONS_DIR),
                               app.applicationDirPath() + QStringLiteral("/../share/lingmo-store/translations"),
                               app.applicationDirPath()}) {
        if (translator.load(QLocale(), QStringLiteral("lingmo-store"), QStringLiteral("_"), dir)) {
            app.installTranslator(&translator);
            break;
        }
    }

    qmlRegisterUncreatableType<FlatpakBackend>("Lingmo.Store", 1, 0, "Flatpak",
                                               QStringLiteral("Use the flatpak context property"));

    StoreApp store;
    bus.registerObject(DBusPath, &store, QDBusConnection::ExportAllSlots);
    store.handle(StoreRequest::fromArguments(arguments));

    return app.exec();
}
