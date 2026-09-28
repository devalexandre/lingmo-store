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

#include <QProcess>
#include <QRegularExpression>

GamesManager::GamesManager(Catalog *catalog, Installer *installer, QObject *parent)
    : QObject(parent)
    , m_catalog(catalog)
    , m_installer(installer)
{
    connect(m_catalog, &Catalog::changed, this, &GamesManager::changed);
    connect(m_catalog, &Catalog::installedChanged, this, &GamesManager::changed);
    connect(m_installer, &Installer::finished, this,
            [this](const QString &, const QString &, const QString &action, bool ok, const QString &) {
                if (action != QLatin1String("gaming") || !ok)
                    return;
                if (m_installer->fakeMode()) {
                    // Nothing was installed for real: remember it for this session, and
                    // re-read the (copied) pacman.conf the fake helper edited
                    for (const QString &pkg : std::as_const(m_lastPackages))
                        m_catalog->setFakePackageInstalled(pkg);
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
         tr("Puts the computer in performance mode while you play."),
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
