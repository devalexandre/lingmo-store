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

#include "permissions.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QPointer>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>

using namespace std::chrono_literals;

static constexpr qint64 MaxAge = 3 * 24 * 3600;
static const QString DefaultApi = QStringLiteral("https://flathub.org/api/v2");

namespace {

enum Level { Low = 0, Medium = 1, High = 2 };

const char *levelName(int level)
{
    return level == High ? "high" : level == Medium ? "medium" : "low";
}

QStringList strings(const QJsonValue &value)
{
    QStringList out;
    for (const QJsonValue &v : value.toArray()) {
        const QString s = v.toString().trimmed();
        // "!x" takes a permission away
        if (!s.isEmpty() && !s.startsWith(QLatin1Char('!')))
            out << s;
    }
    return out;
}

QJsonArray toArray(const QStringList &list)
{
    return QJsonArray::fromStringList(list);
}

bool isOffline(QNetworkReply::NetworkError error)
{
    switch (error) {
    case QNetworkReply::HostNotFoundError:
    case QNetworkReply::TimeoutError:
    case QNetworkReply::ConnectionRefusedError:
    case QNetworkReply::TemporaryNetworkFailureError:
    case QNetworkReply::NetworkSessionFailedError:
    case QNetworkReply::UnknownNetworkError:
    case QNetworkReply::OperationCanceledError:
        return true;
    default:
        return false;
    }
}

// D-Bus names any desktop app talks to without that being a risk
bool harmlessBusName(const QString &name)
{
    static const QStringList prefixes = {
        QStringLiteral("org.freedesktop.portal."), QStringLiteral("org.freedesktop.Notifications"),
        QStringLiteral("org.kde.StatusNotifierWatcher"), QStringLiteral("org.kde.StatusNotifierItem"),
        QStringLiteral("com.canonical.AppMenu.Registrar"), QStringLiteral("com.canonical.indicator."),
        QStringLiteral("com.canonical.Unity"), QStringLiteral("org.a11y.Bus"), QStringLiteral("org.mpris."),
        QStringLiteral("org.freedesktop.FileManager1"), QStringLiteral("org.gtk.vfs"),
        QStringLiteral("org.freedesktop.ScreenSaver"), QStringLiteral("org.gnome.SessionManager"),
        QStringLiteral("org.kde.kconfig.notify"), QStringLiteral("org.kde.KGlobalSettings"),
        QStringLiteral("org.freedesktop.UPower"), QStringLiteral("org.freedesktop.Avahi"),
        QStringLiteral("org.freedesktop.timedate1"), QStringLiteral("org.freedesktop.locale1"),
        QStringLiteral("org.freedesktop.RealtimeKit1"), QStringLiteral("org.freedesktop.PowerManagement"),
        QStringLiteral("org.gnome.Shell.Screenshot"), QStringLiteral("org.gtk.Settings"),
        QStringLiteral("org.freedesktop.DBus"), QStringLiteral("ca.desrt.dconf"),
    };
    for (const QString &p : prefixes) {
        if (name.startsWith(p))
            return true;
    }
    return false;
}

} // namespace

Permissions::Permissions(bool userInstallation, QObject *parent)
    : QObject(parent)
    , m_user(userInstallation)
    , m_network(new QNetworkAccessManager(this))
{
    m_network->setTransferTimeout(20000);
    loadCache();
}

QString Permissions::cachePath() const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(dir);
    return dir + QStringLiteral("/permissions.json");
}

void Permissions::loadCache()
{
    QFile file(cachePath());
    if (!file.open(QIODevice::ReadOnly))
        return;
    const QJsonObject all = QJsonDocument::fromJson(file.readAll()).object();
    for (auto it = all.constBegin(); it != all.constEnd(); ++it) {
        const QJsonObject o = it.value().toObject();
        Entry entry;
        entry.state = QStringLiteral("ready");
        entry.permissions = o.value(QStringLiteral("permissions")).toObject();
        entry.fetched = o.value(QStringLiteral("fetched")).toInteger();
        m_entries.insert(it.key(), entry);
    }
}

void Permissions::saveCache() const
{
    QJsonObject all;
    for (auto it = m_entries.constBegin(); it != m_entries.constEnd(); ++it) {
        if (it->fetched == 0)
            continue;
        all.insert(it.key(), QJsonObject{{QStringLiteral("permissions"), it->permissions},
                                         {QStringLiteral("fetched"), it->fetched}});
    }
    QSaveFile file(cachePath());
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(all).toJson(QJsonDocument::Compact));
        file.commit();
    }
}

QJsonObject Permissions::fromMetadata(const QByteArray &keyfile)
{
    QHash<QString, QStringList> lists;
    QString group;
    for (const QByteArray &raw : keyfile.split('\n')) {
        const QString line = QString::fromUtf8(raw).trimmed();
        if (line.isEmpty() || line.startsWith(QLatin1Char('#')))
            continue;
        if (line.startsWith(QLatin1Char('[')) && line.endsWith(QLatin1Char(']'))) {
            group = line.mid(1, line.size() - 2);
            continue;
        }
        const int eq = line.indexOf(QLatin1Char('='));
        if (eq <= 0)
            continue;
        const QString key = line.left(eq).trimmed();
        const QString value = line.mid(eq + 1).trimmed();
        if (group == QLatin1String("Context")) {
            for (const QString &v : value.split(QLatin1Char(';'), Qt::SkipEmptyParts)) {
                if (!v.startsWith(QLatin1Char('!')))
                    lists[key] << v.trimmed();
            }
        } else if (group == QLatin1String("Session Bus Policy") || group == QLatin1String("System Bus Policy")) {
            const QString bus = group.startsWith(QLatin1String("Session")) ? QStringLiteral("session")
                                                                           : QStringLiteral("system");
            if (value == QLatin1String("talk") || value == QLatin1String("own"))
                lists[bus + QLatin1Char('-') + value] << key;
        }
    }
    QJsonObject out;
    for (const char *k : {"shared", "sockets", "devices", "features", "filesystems", "session-talk", "session-own",
                          "system-talk", "system-own"}) {
        out.insert(QLatin1String(k), toArray(lists.value(QLatin1String(k))));
    }
    return out;
}

QJsonObject Permissions::fromFlathubApi(const QJsonObject &summary)
{
    const QJsonObject p = summary.value(QStringLiteral("metadata")).toObject().value(QStringLiteral("permissions")).toObject();
    const QJsonObject session = p.value(QStringLiteral("session-bus")).toObject();
    const QJsonObject system = p.value(QStringLiteral("system-bus")).toObject();
    return {
        {QStringLiteral("shared"), toArray(strings(p.value(QStringLiteral("shared"))))},
        {QStringLiteral("sockets"), toArray(strings(p.value(QStringLiteral("sockets"))))},
        {QStringLiteral("devices"), toArray(strings(p.value(QStringLiteral("devices"))))},
        {QStringLiteral("features"), toArray(strings(p.value(QStringLiteral("features"))))},
        {QStringLiteral("filesystems"), toArray(strings(p.value(QStringLiteral("filesystems"))))},
        {QStringLiteral("session-talk"), toArray(strings(session.value(QStringLiteral("talk"))))},
        {QStringLiteral("session-own"), toArray(strings(session.value(QStringLiteral("own"))))},
        {QStringLiteral("system-talk"), toArray(strings(system.value(QStringLiteral("talk"))))},
        {QStringLiteral("system-own"), toArray(strings(system.value(QStringLiteral("own"))))},
    };
}

QVariantList Permissions::describe(const QJsonObject &perms)
{
    struct Item {
        int level;
        QString icon, title, detail;
    };
    QList<Item> items;
    auto add = [&items](int level, const char *icon, const QString &title, const QString &detail) {
        items << Item{level, QLatin1String(icon), title, detail};
    };
    const QStringList shared = strings(perms.value(QStringLiteral("shared")));
    const QStringList sockets = strings(perms.value(QStringLiteral("sockets")));
    const QStringList devices = strings(perms.value(QStringLiteral("devices")));
    const QStringList features = strings(perms.value(QStringLiteral("features")));
    const QStringList filesystems = strings(perms.value(QStringLiteral("filesystems")));
    const QStringList sessionTalk = strings(perms.value(QStringLiteral("session-talk")));
    const QStringList systemTalk = strings(perms.value(QStringLiteral("system-talk")));

    // Breaking out first: these make the rest of the sandbox moot
    if (sessionTalk.contains(QLatin1String("org.freedesktop.Flatpak")))
        add(High, "utilities-terminal", tr("Runs programs outside the sandbox"),
            tr("Can start any program directly on your system, without isolation (org.freedesktop.Flatpak)."));
    if (sockets.contains(QLatin1String("session-bus")))
        add(High, "preferences-system", tr("The whole D-Bus session"),
            tr("Can talk to every program of your session, which is enough to get out of the sandbox."));
    if (sockets.contains(QLatin1String("system-bus")))
        add(High, "preferences-system", tr("The whole system D-Bus"),
            tr("Can talk to every service of the system."));

    // Files
    static const QHash<QString, const char *> xdgNames = {
        {QStringLiteral("xdg-download"), QT_TR_NOOP("Downloads")},   {QStringLiteral("xdg-documents"), QT_TR_NOOP("Documents")},
        {QStringLiteral("xdg-pictures"), QT_TR_NOOP("Pictures")},    {QStringLiteral("xdg-music"), QT_TR_NOOP("Music")},
        {QStringLiteral("xdg-videos"), QT_TR_NOOP("Videos")},        {QStringLiteral("xdg-desktop"), QT_TR_NOOP("Desktop")},
        {QStringLiteral("xdg-public-share"), QT_TR_NOOP("Public")}, {QStringLiteral("xdg-templates"), QT_TR_NOOP("Templates")},
    };
    QStringList foldersRw, foldersRo, otherRw, otherRo;
    bool removable = false, removableRo = true, pipewire = false;
    for (const QString &fs : filesystems) {
        const int colon = fs.lastIndexOf(QLatin1Char(':'));
        QString path = fs;
        QString mode;
        if (colon > 0 && !fs.mid(colon + 1).contains(QLatin1Char('/'))) {
            path = fs.left(colon);
            mode = fs.mid(colon + 1);
        }
        const bool ro = mode == QLatin1String("ro");
        while (path.size() > 1 && path.endsWith(QLatin1Char('/')))
            path.chop(1);
        const QString head = path.section(QLatin1Char('/'), 0, 0);
        if (path == QLatin1String("host") || path == QLatin1String("/")) {
            add(High, "drive-harddisk", tr("All the files on this computer"),
                ro ? tr("Can read every file, including system files and other people's.")
                   : tr("Can read, change and delete every file, including system files and other people's."));
        } else if (path == QLatin1String("host-os") || path == QLatin1String("host-etc")) {
            add(Medium, "computer", tr("System files"), tr("Can read the programs and settings of the operating system."));
        } else if (path == QLatin1String("home") || path == QLatin1String("~")) {
            if (ro)
                add(Medium, "user-home", tr("All your files (read only)"), tr("Can read everything in your personal folder."));
            else
                add(High, "user-home", tr("All your files"),
                    tr("Can read, change and delete everything in your personal folder."));
        } else if (xdgNames.contains(head)) {
            (ro ? foldersRo : foldersRw) << tr(xdgNames.value(head));
        } else if (path == QLatin1String("/media") || path == QLatin1String("/run/media") || path == QLatin1String("/mnt")) {
            removable = true;
            removableRo = removableRo && ro;
        } else if (path.startsWith(QLatin1String("xdg-run/pipewire"))) {
            pipewire = true;
        } else {
            QString shown = path;
            shown.replace(QRegularExpression(QStringLiteral("^xdg-config")), QStringLiteral("~/.config"));
            shown.replace(QRegularExpression(QStringLiteral("^xdg-data")), QStringLiteral("~/.local/share"));
            shown.replace(QRegularExpression(QStringLiteral("^xdg-cache")), QStringLiteral("~/.cache"));
            // Sockets and settings of the desktop (xdg-run/…, read-only config) are routine
            if (ro || path.startsWith(QLatin1String("xdg-run")) || path.startsWith(QLatin1String("/run/")))
                otherRo << shown;
            else
                otherRw << shown;
        }
    }
    foldersRw.removeDuplicates();
    foldersRo.removeDuplicates();
    for (const QString &f : std::as_const(foldersRw))
        foldersRo.removeAll(f);
    if (!foldersRw.isEmpty())
        add(Medium, "folder", tr("Your folders: %1").arg(foldersRw.join(QStringLiteral(", "))),
            tr("Can read, change and delete the files in these folders."));
    if (!foldersRo.isEmpty())
        add(Low, "folder", tr("Your folders, read only: %1").arg(foldersRo.join(QStringLiteral(", "))),
            tr("Can read the files in these folders."));
    if (removable)
        add(Medium, "drive-removable-media", tr("Pen drives and external disks"),
            removableRo ? tr("Can read the files on removable drives.")
                        : tr("Can read and change the files on removable drives."));
    if (!otherRw.isEmpty())
        add(Medium, "folder", tr("Other folders"), tr("Can read and change: %1").arg(otherRw.join(QStringLiteral(", "))));
    if (!otherRo.isEmpty())
        add(Low, "folder", tr("Some desktop settings and services"), tr("Can read: %1").arg(otherRo.join(QStringLiteral(", "))));

    // Devices
    if (devices.contains(QLatin1String("all")))
        add(High, "camera-web", tr("Camera and every other device"),
            tr("Can use the webcam, game controllers, USB devices and any other device connected."));
    else {
        if (devices.contains(QLatin1String("input")))
            add(Medium, "input-gaming", tr("Game controllers and input devices"), tr("Can read joysticks and other input devices directly."));
        if (devices.contains(QLatin1String("usb")))
            add(Medium, "drive-removable-media", tr("USB devices"), tr("Can talk to USB devices directly."));
    }
    if (devices.contains(QLatin1String("kvm")))
        add(Medium, "computer", tr("Virtual machines (KVM)"), tr("Can run virtual machines with hardware acceleration."));
    if (pipewire || sockets.contains(QLatin1String("pulseaudio")))
        add(Medium, "audio-input-microphone", tr("Sound and microphone"),
            pipewire ? tr("Can play sound, record from the microphone and capture the screen (PipeWire).")
                     : tr("Can play sound and record from the microphone."));
    if (features.contains(QLatin1String("bluetooth")) || systemTalk.contains(QLatin1String("org.bluez")))
        add(Medium, "preferences-system-bluetooth", tr("Bluetooth"), tr("Can find and connect to Bluetooth devices."));
    if (features.contains(QLatin1String("devel")))
        add(Medium, "applications-development", tr("Developer tools"), tr("Can inspect and control other programs (ptrace)."));
    if (sockets.contains(QLatin1String("ssh-auth")))
        add(Medium, "dialog-password", tr("Your SSH keys"), tr("Can use your SSH keys to log in to other computers."));
    if (sockets.contains(QLatin1String("gpg-agent")))
        add(Medium, "dialog-password", tr("Your GPG keys"), tr("Can sign and decrypt with your GPG keys."));

    // Services
    QStringList otherSession, otherSystem;
    bool secrets = false;
    for (const QString &name : sessionTalk) {
        if (name == QLatin1String("org.freedesktop.Flatpak"))
            continue;
        if (name.startsWith(QLatin1String("org.freedesktop.secrets")) || name.startsWith(QLatin1String("org.kde.kwalletd"))
            || name.startsWith(QLatin1String("org.gnome.keyring")))
            secrets = true;
        else if (name == QLatin1String("org.freedesktop.systemd1"))
            add(Medium, "preferences-system", tr("Your background services"), tr("Can start and stop services of your session (systemd)."));
        else if (!harmlessBusName(name))
            otherSession << name;
    }
    if (secrets)
        add(Medium, "dialog-password", tr("Your saved passwords"), tr("Can read the passwords kept in the system keyring."));
    if (!sockets.contains(QLatin1String("system-bus"))) {
        for (const QString &name : systemTalk) {
            if (name == QLatin1String("org.freedesktop.NetworkManager"))
                add(Medium, "network-wired", tr("Network settings"), tr("Can see and change your network connections."));
            else if (name == QLatin1String("org.freedesktop.UDisks2"))
                add(Medium, "drive-harddisk", tr("Disks"), tr("Can mount and manage disks."));
            else if (name != QLatin1String("org.bluez") && !harmlessBusName(name))
                otherSystem << name;
        }
    }

    // Everyday ones
    if (shared.contains(QLatin1String("network")))
        add(Low, "network-wired", tr("Internet"), tr("Can connect to the internet and to your local network."));
    if (devices.contains(QLatin1String("dri")) && !devices.contains(QLatin1String("all")))
        add(Low, "video-display", tr("Graphics acceleration"), tr("Uses the video card to draw faster."));
    if (sockets.contains(QLatin1String("x11")))
        add(Low, "video-display", tr("Windows through X11"),
            tr("Uses the older X11 window system, where apps can see other windows and keystrokes."));
    if (sockets.contains(QLatin1String("cups")))
        add(Low, "printer", tr("Printers"), tr("Can print directly."));
    if (sockets.contains(QLatin1String("pcsc")))
        add(Low, "media-flash", tr("Smart cards"), tr("Can use smart card readers (digital certificates)."));
    if (!otherSession.isEmpty())
        add(Low, "preferences-system", tr("Other programs"), tr("Talks to: %1").arg(otherSession.join(QStringLiteral(", "))));
    if (!otherSystem.isEmpty())
        add(Low, "preferences-system", tr("System services"), tr("Talks to: %1").arg(otherSystem.join(QStringLiteral(", "))));

    std::stable_sort(items.begin(), items.end(), [](const Item &a, const Item &b) { return a.level > b.level; });
    QVariantList out;
    for (const Item &item : std::as_const(items)) {
        out << QVariantMap{
            {QStringLiteral("level"), QLatin1String(levelName(item.level))},
            {QStringLiteral("icon"), item.icon},
            {QStringLiteral("title"), item.title},
            {QStringLiteral("detail"), item.detail},
        };
    }
    return out;
}

QVariantMap Permissions::summarize(const QJsonObject &permissions)
{
    const QVariantList items = describe(permissions);
    QString level = QStringLiteral("low");
    int important = 0;
    for (const QVariant &v : items) {
        const QString l = v.toMap().value(QStringLiteral("level")).toString();
        if (l == QLatin1String("high"))
            level = l;
        else if (l == QLatin1String("medium") && level == QLatin1String("low"))
            level = l;
        if (l != QLatin1String("low"))
            ++important;
    }
    QString title, text;
    if (level == QLatin1String("high")) {
        title = tr("Wide access");
        text = tr("This app is only partly isolated: it can reach your files or the system in ways that matter. Install it only if you trust the developer.");
    } else if (level == QLatin1String("medium")) {
        title = tr("Isolated, with %n sensitive permission(s)", nullptr, important);
        text = tr("Runs in a sandbox, but can reach a few things worth knowing about.");
    } else {
        title = tr("Isolated from the system");
        text = items.isEmpty() ? tr("Runs in a sandbox with no special permissions.")
                               : tr("Runs in a sandbox, without access to anything sensitive.");
    }
    return {
        {QStringLiteral("level"), level},
        {QStringLiteral("title"), title},
        {QStringLiteral("text"), text},
        {QStringLiteral("items"), items},
    };
}

QVariantMap Permissions::forApp(const QString &flatpakId) const
{
    const auto it = m_entries.constFind(flatpakId);
    if (flatpakId.isEmpty() || it == m_entries.constEnd())
        return {{QStringLiteral("state"), QStringLiteral("none")}};
    QVariantMap map;
    if (it->fetched > 0)
        map = summarize(it->permissions);
    map.insert(QStringLiteral("state"), it->fetched > 0 && it->state != QLatin1String("loading") ? QStringLiteral("ready") : it->state);
    map.insert(QStringLiteral("stale"), it->stale);
    return map;
}

void Permissions::runFlatpak(const QString &id, const QStringList &args, std::function<void(bool, const QByteArray &)> done)
{
    Q_UNUSED(id)
    auto *proc = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert(QStringLiteral("LC_ALL"), QStringLiteral("C"));
    proc->setProcessEnvironment(env);
    auto finished = std::make_shared<bool>(false);
    auto finish = [proc, done, finished](bool ok, const QByteArray &out) {
        if (*finished)
            return;
        *finished = true;
        proc->deleteLater();
        done(ok, out);
    };
    connect(proc, &QProcess::finished, this, [proc, finish](int code, QProcess::ExitStatus status) {
        finish(status == QProcess::NormalExit && code == 0, proc->readAllStandardOutput());
    });
    connect(proc, &QProcess::errorOccurred, this, [finish](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart)
            finish(false, {});
    });
    QTimer::singleShot(25s, proc, [proc] { proc->kill(); });
    proc->start(QStringLiteral("flatpak"), args);
}

void Permissions::fetch(const QString &flatpakId, const QString &ref, bool installed)
{
    if (flatpakId.isEmpty())
        return;
    Entry &entry = m_entries[flatpakId];
    if (entry.state == QLatin1String("loading"))
        return;
    if (entry.state == QLatin1String("ready") && !entry.stale
        && QDateTime::currentSecsSinceEpoch() - entry.fetched < MaxAge && !installed)
        return;
    entry.state = QStringLiteral("loading");
    ++m_revision;
    Q_EMIT changed();

    const QString id = flatpakId;
    auto fromRemote = [this, id, ref] {
        if (ref.isEmpty()) {
            fetchFromApi(id);
            return;
        }
        runFlatpak(id, {QStringLiteral("remote-info"), m_user ? QStringLiteral("--user") : QStringLiteral("--system"),
                        QStringLiteral("--show-metadata"), QStringLiteral("flathub"), ref},
                   [this, id](bool ok, const QByteArray &out) {
                       if (ok && out.contains("[Application]"))
                           store(id, fromMetadata(out));
                       else
                           fetchFromApi(id);
                   });
    };
    if (!installed) {
        fromRemote();
        return;
    }
    // Installed: what's on disk is what runs, and needs no network
    runFlatpak(id, {QStringLiteral("info"), QStringLiteral("--show-metadata"), id},
               [this, id, fromRemote](bool ok, const QByteArray &out) {
                   if (ok && out.contains("[Application]"))
                       store(id, fromMetadata(out));
                   else
                       fromRemote();
               });
}

void Permissions::fetchFromApi(const QString &id)
{
    QString base = qEnvironmentVariable("LINGMO_STORE_FLATHUB_API", DefaultApi);
    while (base.endsWith(QLatin1Char('/')))
        base.chop(1);
    QNetworkRequest request{QUrl(base + QStringLiteral("/summary/") + id)};
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("lingmo-store/" LINGMO_STORE_VERSION));
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *reply = m_network->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, id] {
        reply->deleteLater();
        const QJsonObject summary = QJsonDocument::fromJson(reply->readAll()).object();
        if (reply->error() != QNetworkReply::NoError || !summary.contains(QStringLiteral("metadata"))) {
            qInfo().noquote() << "Permissions of" << id << "unavailable:" << reply->errorString();
            failed(id, isOffline(reply->error()));
            return;
        }
        store(id, fromFlathubApi(summary));
    });
}

void Permissions::store(const QString &id, const QJsonObject &permissions)
{
    Entry &entry = m_entries[id];
    entry.state = QStringLiteral("ready");
    entry.permissions = permissions;
    entry.fetched = QDateTime::currentSecsSinceEpoch();
    entry.stale = false;
    saveCache();
    ++m_revision;
    Q_EMIT changed();
}

void Permissions::failed(const QString &id, bool offline)
{
    Entry &entry = m_entries[id];
    if (entry.fetched > 0) {
        entry.state = QStringLiteral("ready");
        entry.stale = true;
    } else {
        entry.state = offline ? QStringLiteral("offline") : QStringLiteral("error");
    }
    ++m_revision;
    Q_EMIT changed();
}
