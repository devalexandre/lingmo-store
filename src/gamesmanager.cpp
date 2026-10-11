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

#include "gamesmanager.h"
#include "catalog.h"
#include "installer.h"
#include "steamconfig.h"

#include <QDateTime>
#include <QDebug>
#include <QFile>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>

#include <grp.h>
#include <pwd.h>
#include <unistd.h>

static const QString ProtonTool = QStringLiteral("proton_experimental");

GamesManager::GamesManager(Catalog *catalog, Installer *installer, QObject *parent)
    : QObject(parent)
    , m_catalog(catalog)
    , m_installer(installer)
{
    connect(m_catalog, &Catalog::changed, this, &GamesManager::changed);
    connect(m_catalog, &Catalog::installedChanged, this, &GamesManager::changed);
    connect(m_catalog, &Catalog::installedChanged, this, &GamesManager::refreshSteam);
    connect(m_catalog, &Catalog::changed, this, &GamesManager::refreshSteam);
    connect(m_installer, &Installer::finished, this,
            [this](const QString &, const QString &, const QString &action, bool ok, const QString &) {
                if (action != QLatin1String("gaming") || !ok)
                    return;
                if (m_installer->fakeMode()) {
                    // Nothing was installed for real: remember it for this session, and
                    // re-read the (copied) pacman.conf the fake helper edited
                    for (const QString &pkg : std::as_const(m_lastPackages))
                        m_catalog->setFakePackageInstalled(pkg);
                    if (m_lastPackages.contains(QLatin1String("gamemode")))
                        m_fakeGroupAdded = true;
                    m_catalog->reload();
                }
            });
}

void GamesManager::detect()
{
    // LINGMO_STORE_FAKE_GPU=nvidia|amd|intel skips lspci (testing)
    const QString fakeGpu = qEnvironmentVariable("LINGMO_STORE_FAKE_GPU");
    if (!fakeGpu.isEmpty()) {
        m_vendors = fakeGpu.split(QLatin1Char('+'));
        m_gpuNames = {QStringLiteral("Simulated %1 GPU").arg(fakeGpu)};
        Q_EMIT changed();
        return;
    }
    m_detecting = true;
    Q_EMIT changed();
    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc] {
        proc->deleteLater();
        m_vendors.clear();
        m_gpuNames.clear();
        // 07:00.0 "VGA compatible controller [0300]" "NVIDIA Corporation [10de]" "TU106 [GeForce RTX 2060] [1f08]" …
        static const QRegularExpression re(QStringLiteral(
            "^\\S+\\s+\"[^\"]*\\[(03[0-9a-f]{2})\\]\"\\s+\"([^\"]*)\\[([0-9a-f]{4})\\]\"\\s+\"([^\"]*?)\\s*(?:\\[[0-9a-f]{4}\\])?\""));
        const QStringList lines = QString::fromUtf8(proc->readAllStandardOutput()).split(QLatin1Char('\n'));
        for (const QString &line : lines) {
            const auto m = re.match(line);
            if (!m.hasMatch())
                continue;
            const QString vendorId = m.captured(3);
            QString vendor;
            if (vendorId == QLatin1String("10de"))
                vendor = QStringLiteral("nvidia");
            else if (vendorId == QLatin1String("1002") || vendorId == QLatin1String("1022"))
                vendor = QStringLiteral("amd");
            else if (vendorId == QLatin1String("8086"))
                vendor = QStringLiteral("intel");
            else
                continue;
            if (!m_vendors.contains(vendor))
                m_vendors << vendor;
            QString name = m.captured(4).trimmed();
            // "TU106 [GeForce RTX 2060 Rev. A]" -> "GeForce RTX 2060 Rev. A"
            static const QRegularExpression bracket(QStringLiteral("\\[([^\\]]+)\\]"));
            if (const auto b = bracket.match(name); b.hasMatch())
                name = b.captured(1);
            const QString brand = vendor == QLatin1String("nvidia") ? QStringLiteral("NVIDIA")
                : vendor == QLatin1String("amd")                    ? QStringLiteral("AMD")
                                                                    : QStringLiteral("Intel");
            m_gpuNames << (name.startsWith(brand, Qt::CaseInsensitive) ? name : brand + QLatin1Char(' ') + name);
        }
        m_detecting = false;
        Q_EMIT changed();
    });
    connect(proc, &QProcess::errorOccurred, this, [this, proc](QProcess::ProcessError e) {
        if (e != QProcess::FailedToStart)
            return;
        proc->deleteLater();
        m_detecting = false;
        Q_EMIT changed();
    });
    proc->start(QStringLiteral("lspci"), {QStringLiteral("-mm"), QStringLiteral("-nn")});
}

QStringList GamesManager::driverPackages() const
{
    QStringList pkgs{QStringLiteral("vulkan-icd-loader"), QStringLiteral("lib32-vulkan-icd-loader")};
    bool mesa = m_vendors.isEmpty();
    for (const QString &vendor : m_vendors) {
        if (vendor == QLatin1String("nvidia")) {
            // The proprietary driver brings its own 32-bit libraries; nouveau uses Mesa (NVK)
            if (m_catalog->isPackageInstalled(QStringLiteral("nvidia-utils"))) {
                pkgs << QStringLiteral("lib32-nvidia-utils");
            } else {
                mesa = true;
                pkgs << QStringLiteral("vulkan-nouveau") << QStringLiteral("lib32-vulkan-nouveau");
            }
        } else if (vendor == QLatin1String("amd")) {
            mesa = true;
            pkgs << QStringLiteral("vulkan-radeon") << QStringLiteral("lib32-vulkan-radeon");
        } else if (vendor == QLatin1String("intel")) {
            mesa = true;
            pkgs << QStringLiteral("vulkan-intel") << QStringLiteral("lib32-vulkan-intel");
        }
    }
    if (mesa)
        pkgs << QStringLiteral("lib32-mesa");
    return pkgs;
}

QList<GamesManager::Item> GamesManager::plan() const
{
    QString gpu;
    if (m_vendors.contains(QLatin1String("nvidia")) && m_vendors.size() == 1)
        gpu = QStringLiteral("NVIDIA");
    else if (m_vendors.size() == 1)
        gpu = m_vendors.first() == QLatin1String("amd") ? QStringLiteral("AMD") : QStringLiteral("Intel");
    else if (m_vendors.size() > 1)
        gpu = m_gpuNames.size() > 1 ? tr("%1 video cards").arg(m_vendors.size()) : QString();
    return {
        {QStringLiteral("multilib"), tr("32-bit software repository (multilib)"),
         tr("Needed by Steam and by Windows games."), {}, false},
        {QStringLiteral("steam"), tr("Steam"),
         tr("The biggest game store, with Proton to run Windows games."),
         {QStringLiteral("steam"), QStringLiteral("ttf-liberation")}, false},
        {QStringLiteral("drivers"),
         gpu.isEmpty() ? tr("32-bit video drivers (Vulkan)") : tr("32-bit video drivers (Vulkan, %1)").arg(gpu),
         tr("Let games talk to your video card."), driverPackages(), false},
        {QStringLiteral("gamemode"), tr("GameMode"),
         gamemodeGroupMissing() && m_catalog->isPackageInstalled(QStringLiteral("gamemode"))
             ? tr("Puts the computer in performance mode while you play. Your user still needs to join the gamemode group.")
             : tr("Puts the computer in performance mode while you play."),
         {QStringLiteral("gamemode"), QStringLiteral("lib32-gamemode")}, false},
        {QStringLiteral("mangohud"), tr("MangoHud (optional)"),
         tr("Shows FPS, temperatures and usage on top of the game."),
         {QStringLiteral("mangohud"), QStringLiteral("lib32-mangohud")}, true},
    };
}

bool GamesManager::installed(const Item &item) const
{
    if (item.id == QLatin1String("multilib"))
        return m_catalog->multilibEnabled();
    if (item.id == QLatin1String("gamemode") && gamemodeGroupMissing())
        return false;
    return std::all_of(item.packages.cbegin(), item.packages.cend(),
                       [this](const QString &pkg) { return m_catalog->isPackageInstalled(pkg); });
}

QVariantList GamesManager::items() const
{
    QVariantList list;
    for (const Item &item : plan()) {
        list << QVariantMap{
            {QStringLiteral("id"), item.id},
            {QStringLiteral("title"), item.title},
            {QStringLiteral("detail"), item.detail},
            {QStringLiteral("packages"), item.packages.join(QLatin1Char(' '))},
            {QStringLiteral("optional"), item.optional},
            {QStringLiteral("done"), installed(item)},
        };
    }
    return list;
}

bool GamesManager::allDone() const
{
    if (!m_catalog->ready())
        return false;
    const auto items = plan();
    return std::all_of(items.cbegin(), items.cend(), [this](const Item &item) {
        return (item.optional && !m_includeOptional) || installed(item);
    });
}

void GamesManager::setIncludeOptional(bool include)
{
    if (m_includeOptional == include)
        return;
    m_includeOptional = include;
    Q_EMIT changed();
}

QStringList GamesManager::plannedPackages() const
{
    QStringList pkgs;
    for (const Item &item : plan()) {
        if (!item.optional || m_includeOptional)
            pkgs << item.packages;
    }
    pkgs.removeDuplicates();
    return pkgs;
}

bool GamesManager::prepare()
{
    m_lastPackages = plannedPackages();
    return m_installer->prepareGaming(m_lastPackages);
}

bool GamesManager::gamemodeInstalled() const
{
    return m_catalog->isPackageInstalled(QStringLiteral("gamemode"));
}

bool GamesManager::gamemodeGroupMissing() const
{
    if (m_fakeGroupAdded)
        return false;
    // The gamemode package creates the group (sysusers.d); its polkit rule lets members
    // switch the CPU to performance mode without a password
    const group *gr = getgrnam("gamemode");
    if (!gr)
        return false;
    const passwd *pw = getpwuid(getuid());
    if (!pw)
        return false;
    if (pw->pw_gid == gr->gr_gid)
        return false;
    for (char **member = gr->gr_mem; member && *member; ++member) {
        if (qstrcmp(*member, pw->pw_name) == 0)
            return false;
    }
    return true;
}

void GamesManager::refreshSteam()
{
    QString state;
    QString tool;
    const QString dir = SteamConfig::steamDir();
    const bool steamInstalled = m_catalog->isPackageInstalled(QStringLiteral("steam"))
        || m_catalog->isFlatpakInstalled(QStringLiteral("com.valvesoftware.Steam")) || SteamConfig::isInstalledDir(dir);
    if (!steamInstalled) {
        state = QStringLiteral("nosteam");
    } else if (!SteamConfig::isInstalledDir(dir)) {
        state = QStringLiteral("firstrun");
    } else {
        QFile file(SteamConfig::configPath());
        bool ok = false;
        if (file.open(QIODevice::ReadOnly))
            tool = SteamConfig::defaultTool(QString::fromUtf8(file.readAll()), &ok);
        if (!ok)
            state = QStringLiteral("unknown");
        else if (!tool.isEmpty())
            state = QStringLiteral("on");
        else
            state = SteamConfig::steamRunning() ? QStringLiteral("running") : QStringLiteral("off");
    }
    if (state == m_protonState && tool == m_protonTool)
        return;
    m_protonState = state;
    m_protonTool = tool;
    Q_EMIT steamChanged();
}

QString GamesManager::enableProtonForAll()
{
    refreshSteam();
    if (m_protonState == QLatin1String("on"))
        return {};
    if (m_protonState == QLatin1String("nosteam"))
        return tr("Install Steam first.");
    if (m_protonState == QLatin1String("firstrun"))
        return tr("Open Steam once and sign in, then close it and try again.");
    if (SteamConfig::steamRunning())
        return tr("Close Steam first (Steam menu, Exit), then try again.");

    const QString path = SteamConfig::configPath();
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return tr("Could not read Steam's settings.");
    const QString original = QString::fromUtf8(file.readAll());
    file.close();
    QString error;
    const QString edited = SteamConfig::withDefaultTool(original, ProtonTool, &error);
    if (edited.isEmpty()) {
        qWarning().noquote() << "Steam settings:" << error;
        return tr("Steam's settings are in a format the store doesn't know. Turn it on in Steam instead.");
    }
    const QString backup = path + QStringLiteral(".lingmo-store-%1.bak")
                                      .arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss")));
    if (!QFile::copy(path, backup))
        return tr("Could not save a copy of Steam's settings, so nothing was changed.");
    QSaveFile out(path);
    if (!out.open(QIODevice::WriteOnly) || out.write(edited.toUtf8()) < 0 || !out.commit())
        return tr("Could not save Steam's settings.");
    qInfo().noquote() << "Steam Play enabled for all titles in" << path << "(backup:" << backup + ")";
    refreshSteam();
    return {};
}
