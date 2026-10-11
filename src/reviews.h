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
#include <QVariantList>
#include <QVariantMap>

#include <array>

class Catalog;
class QNetworkAccessManager;
class QNetworkReply;

// Ratings and reviews from ODRS (odrs.gnome.org), the service GNOME Software and
// KDE Discover use. The star counts of every app come in one download, cached for a
// day; the reviews of an app are fetched when its page opens and cached for a few
// hours. Nothing here blocks: answers arrive later through changed(), and a cached
// copy (even a stale one) stands in when there's no internet.
//
// LINGMO_STORE_ODRS_URL points at another server (tests). With LINGMO_STORE_FAKE set
// and no LINGMO_STORE_ODRS_URL, submitting a review is only simulated.
class Reviews : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY changed)
    Q_PROPERTY(QString userName READ userName CONSTANT)
    Q_PROPERTY(bool canSubmit READ canSubmit CONSTANT)
    Q_PROPERTY(bool submitting READ submitting NOTIFY changed)

public:
    Reviews(Catalog *catalog, bool fake, QObject *parent = nullptr);

    int revision() const { return m_revision; }
    QString userName() const { return m_userName; }
    bool canSubmit() const { return !m_userHash.isEmpty(); }
    bool submitting() const { return m_submitting; }

    // {count, average, stars: [count of 1★ … 5★]}; empty when nobody rated the app
    Q_INVOKABLE QVariantMap rating(const QString &key) const;
    // {state: loading|ready|offline|error, items: [...], english, stale, reviewed}
    Q_INVOKABLE QVariantMap reviews(const QString &key) const;
    Q_INVOKABLE void fetch(const QString &key, bool force = false);
    // stars 1–5; answers with submitted()
    Q_INVOKABLE bool submit(const QString &key, const QString &version, int stars, const QString &summary,
                            const QString &description, const QString &name);

    static constexpr int SummaryMax = 70;
    static constexpr int DescriptionMin = 15;
    static constexpr int DescriptionMax = 3000;

    // Exposed for tests: the ODRS ratings document -> lower-case id -> 1★…5★ counts
    static QHash<QString, std::array<int, 5>> parseRatings(const QByteArray &json);

Q_SIGNALS:
    void changed();
    void submitted(const QString &key, bool ok, const QString &message);

private:
    struct AppReviews {
        QString state;          // loading, ready, offline, error
        QVariantList items;
        bool english = false;   // none in the user's language: these are in English
        bool stale = false;
        qint64 fetched = 0;
        QString skey;           // ODRS' per-app key, sent back with a submission
    };

    QStringList idsFor(const QString &key) const;
    QString apiUrl(const QString &method) const;
    QNetworkReply *post(const QString &method, const QJsonObject &body);
    void loadRatings();
    void applyRatings(const QByteArray &json, bool save);
    void requestReviews(const QString &key, const QString &locale);
    void setReviews(const QString &key, const QJsonArray &list, bool english);
    QVariantMap reviewMap(const QJsonObject &review) const;
    QString cacheDir() const;
    void saveReviews(const QString &key) const;
    bool loadCachedReviews(const QString &key, AppReviews *out) const;
    void bump();

    Catalog *m_catalog;
    bool m_fake;
    QNetworkAccessManager *m_network;
    QString m_userHash;
    QString m_userName;
    QString m_distro;
    QString m_locale;
    QHash<QString, std::array<int, 5>> m_ratings;
    mutable QHash<QString, QVariantMap> m_ratingByKey;
    QHash<QString, AppReviews> m_reviews;
    int m_revision = 0;
    bool m_submitting = false;
    bool m_ratingsLoading = false;
};
