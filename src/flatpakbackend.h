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
#include <QObject>
#include <QStringList>

#include <atomic>
#include <functional>

// Flathub through libflatpak, system-wide by default: apps are shared by every user
// and show up in the launcher, and flatpak's own polkit rules let administrators
// (wheel) install without a password. LINGMO_STORE_FLATPAK_INSTALLATION=user
// switches to the per-user installation (~/.local/share/flatpak).
//
// Everything that touches libflatpak runs in a worker thread; results come back as
// queued signals.
class FlatpakBackend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool userInstallation READ userInstallation CONSTANT)
    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY stateChanged)

public:
    enum State {
        Probing,
        Unavailable,  // flatpak isn't installed / usable
        NoRemote,     // the flathub remote isn't configured
        AddingRemote,
        Refreshing,   // downloading Flathub's catalog
        Ready,
        Error,
    };
    Q_ENUM(State)

    static constexpr const char *Remote = "flathub";

    explicit FlatpakBackend(bool fake, QObject *parent = nullptr);
    ~FlatpakBackend() override;

    State state() const { return m_state; }
    bool userInstallation() const { return m_user; }
    bool available() const;
    QString errorMessage() const { return m_error; }
    // Where libappstream should look for the Flathub catalog besides /var/lib/flatpak
    QStringList extraAppstreamDirs() const;

    // Installed apps (id -> "system"/"user") and the remote's state
    void probe();
    // Downloads Flathub's AppStream data when missing or older than a day
    Q_INVOKABLE void refreshAppstream(bool force = false);
    // Adds the flathub remote (only after the user agreed)
    Q_INVOKABLE void addFlathub();
    // Download and installed size of an app, from the remote's cached summary
    void fetchSize(const QString &id);

    // Transactions: one at a time, reported with progress()/finished()
    void install(const QString &id);
    void uninstall(const QString &id, const QString &installation);
    void cancel();

Q_SIGNALS:
    void stateChanged();
    void probed(const QHash<QString, QString> &installed);
    void catalogUpdated();
    void remoteAdded(bool ok, const QString &error);
    void sizeFetched(const QString &id, qint64 download, qint64 installed);
    void progress(double fraction, const QString &text);
    void finished(bool ok, const QString &error);

private:
    void setState(State state, const QString &error = QString());
    void runTransaction(const QString &id, bool install, const QString &installation);
    void runFake(const QString &id, bool install);
    static void runInThread(std::function<void()> work);

    State m_state = Probing;
    QString m_error;
    bool m_fake;
    bool m_user;
    bool m_refreshing = false;
    std::atomic<void *> m_cancellable{nullptr};
};

