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

#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

#include <functional>

class QNetworkAccessManager;

// What a Flathub app may reach outside its sandbox, read before it is installed:
// the [Context] and bus policies of the app's metadata (`flatpak remote-info
// --show-metadata`, or `flatpak info` when installed), with Flathub's API as the
// fallback when the remote isn't set up yet. The permissions are turned into
// plain sentences with a risk level. Cached on disk for a few days; offline, the
// last answer is shown.
//
// LINGMO_STORE_FLATHUB_API overrides https://flathub.org/api/v2 (tests).
class Permissions : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY changed)

public:
    explicit Permissions(bool userInstallation, QObject *parent = nullptr);

    int revision() const { return m_revision; }

    // {state: none|loading|ready|offline|error, level: high|medium|low,
    //  title, text, items: [{level, icon, title, detail}]}
    Q_INVOKABLE QVariantMap forApp(const QString &flatpakId) const;
    // ref: app/<id>/<arch>/<branch>
    Q_INVOKABLE void fetch(const QString &flatpakId, const QString &ref, bool installed);

    // The permissions in one shape, whichever way they were read:
    // {shared, sockets, devices, features, filesystems, session-talk, session-own,
    //  system-talk, system-own} -> string arrays
    static QJsonObject fromMetadata(const QByteArray &keyfile);
    static QJsonObject fromFlathubApi(const QJsonObject &summary);
    // Plain-language list, most dangerous first
    static QVariantList describe(const QJsonObject &permissions);
    static QVariantMap summarize(const QJsonObject &permissions);

Q_SIGNALS:
    void changed();

private:
    struct Entry {
        QString state;
        QJsonObject permissions;
        qint64 fetched = 0;
        bool stale = false;
    };
    void runFlatpak(const QString &id, const QStringList &args, std::function<void(bool, const QByteArray &)> done);
    void fetchFromApi(const QString &id);
    void store(const QString &id, const QJsonObject &permissions);
    void failed(const QString &id, bool offline);
    void loadCache();
    void saveCache() const;
    QString cachePath() const;

    bool m_user;
    QNetworkAccessManager *m_network = nullptr;
    QHash<QString, Entry> m_entries;
    int m_revision = 0;
};
