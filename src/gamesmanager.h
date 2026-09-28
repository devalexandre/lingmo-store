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

#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>

class Catalog;
class Installer;

// "Get ready for games": the [multilib] repository, Steam, 32-bit Vulkan drivers for
// the GPUs found by lspci, GameMode and (optionally) MangoHud, in one transaction.
class GamesManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool detecting READ detecting NOTIFY changed)
    Q_PROPERTY(QString gpuName READ gpuName NOTIFY changed)
    Q_PROPERTY(QString gpuVendor READ gpuVendor NOTIFY changed)
    Q_PROPERTY(QVariantList items READ items NOTIFY changed)
    Q_PROPERTY(bool allDone READ allDone NOTIFY changed)
    Q_PROPERTY(bool includeOptional READ includeOptional WRITE setIncludeOptional NOTIFY changed)

public:
    GamesManager(Catalog *catalog, Installer *installer, QObject *parent = nullptr);

    bool detecting() const { return m_detecting; }
    QString gpuName() const { return m_gpuNames.join(QStringLiteral(" + ")); }
    QString gpuVendor() const { return m_vendors.join(QLatin1Char('+')); }
    QVariantList items() const;
    bool allDone() const;
    bool includeOptional() const { return m_includeOptional; }
    void setIncludeOptional(bool include);

    // Packages the one-click setup installs (pacman --needed skips those already there)
    Q_INVOKABLE QStringList plannedPackages() const;
    Q_INVOKABLE bool prepare();

public Q_SLOTS:
    void detect();

Q_SIGNALS:
    void changed();

private:
    struct Item {
        QString id;
        QString title;
        QString detail;
        QStringList packages;
        bool optional = false;
    };
    QList<Item> plan() const;
    QStringList driverPackages() const;
    bool installed(const Item &item) const;

    Catalog *m_catalog;
    Installer *m_installer;
    bool m_detecting = false;
    bool m_includeOptional = false;
    QStringList m_vendors;  // nvidia, amd, intel
    QStringList m_gpuNames;
    QStringList m_lastPackages;
};
