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

#include "reviews.h"
#include "catalog.h"
#include "errors.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QPointer>
#include <QSaveFile>
#include <QStandardPaths>
#include <QThread>
#include <QTimer>

#include <pwd.h>
#include <unistd.h>

using namespace std::chrono_literals;

static const QString DefaultApi = QStringLiteral("https://odrs.gnome.org/1.0/reviews/api");
static constexpr qint64 RatingsMaxAge = 24 * 3600;
static constexpr qint64 ReviewsMaxAge = 6 * 3600;
static constexpr int MaxReviews = 8;

namespace {

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

QString readFirstLine(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QString::fromUtf8(file.readLine()).trimmed();
}

// NAME= of os-release ("Arch Linux", "ArchLingmo"…)
QString distroName()
{
    for (const char *path : {"/etc/os-release", "/usr/lib/os-release"}) {
        QFile file(QString::fromLatin1(path));
        if (!file.open(QIODevice::ReadOnly))
            continue;
        while (!file.atEnd()) {
            const QString line = QString::fromUtf8(file.readLine()).trimmed();
            if (line.startsWith(QLatin1String("NAME="))) {
                QString name = line.mid(5);
                if (name.size() >= 2 && (name.startsWith(QLatin1Char('"')) || name.startsWith(QLatin1Char('\''))))
                    name = name.mid(1, name.size() - 2);
                return name;
            }
        }
    }
    return QStringLiteral("Arch Linux");
}

QString versionOf(const AppEntry *app)
{
    if (!app)
        return {};
    if (app->flathub && !app->flathub->version.isEmpty())
        return app->flathub->version;
    if (app->arch && !app->arch->version.isEmpty())
        return app->arch->version.section(QLatin1Char(':'), -1).section(QLatin1Char('-'), 0, 0);
    return {};
}

} // namespace

Reviews::Reviews(Catalog *catalog, bool fake, QObject *parent)
    : QObject(parent)
    , m_catalog(catalog)
    , m_fake(fake)
    , m_network(new QNetworkAccessManager(this))
    , m_distro(distroName())
    , m_locale(QLocale().name())
{
    m_network->setTransferTimeout(20000);

    // Like GNOME Software: a salted hash of the login and the machine id, so ODRS
    // can tell a person's reviews apart without knowing who they are
    QString machineId = readFirstLine(QStringLiteral("/etc/machine-id"));
    if (machineId.isEmpty())
        machineId = readFirstLine(QStringLiteral("/var/lib/dbus/machine-id"));
    QString login = qEnvironmentVariable("USER");
    if (const passwd *pw = getpwuid(getuid())) {
        login = QString::fromLocal8Bit(pw->pw_name);
        m_userName = QString::fromLocal8Bit(pw->pw_gecos).section(QLatin1Char(','), 0, 0).trimmed();
    }
    if (m_userName.isEmpty())
        m_userName = login;
    if (!machineId.isEmpty() && !login.isEmpty()) {
        const QByteArray salted = QStringLiteral("lingmo-store[%1:%2]").arg(login, machineId).toUtf8();
        m_userHash = QString::fromLatin1(QCryptographicHash::hash(salted, QCryptographicHash::Sha1).toHex());
    }

    connect(m_catalog, &Catalog::changed, this, [this] {
        m_ratingByKey.clear();
        bump();
    });
    QTimer::singleShot(0, this, &Reviews::loadRatings);
}

void Reviews::bump()
{
    ++m_revision;
    Q_EMIT changed();
}

QString Reviews::apiUrl(const QString &method) const
{
    QString base = qEnvironmentVariable("LINGMO_STORE_ODRS_URL", DefaultApi);
    while (base.endsWith(QLatin1Char('/')))
        base.chop(1);
    return base + QLatin1Char('/') + method;
}

QString Reviews::cacheDir() const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/reviews");
    QDir().mkpath(dir);
    return dir;
}

QNetworkReply *Reviews::post(const QString &method, const QJsonObject &body)
{
    QNetworkRequest request{QUrl(apiUrl(method))};
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("lingmo-store/" LINGMO_STORE_VERSION));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json; charset=utf-8"));
    return m_network->post(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
}

QHash<QString, std::array<int, 5>> Reviews::parseRatings(const QByteArray &json)
{
    QHash<QString, std::array<int, 5>> out;
    const QJsonObject all = QJsonDocument::fromJson(json).object();
    out.reserve(all.size());
    for (auto it = all.constBegin(); it != all.constEnd(); ++it) {
        const QJsonObject r = it.value().toObject();
        std::array<int, 5> stars{};
        int total = 0;
        for (int i = 0; i < 5; ++i) {
            stars[i] = qMax(0, r.value(QStringLiteral("star%1").arg(i + 1)).toInt());
            total += stars[i];
        }
        if (total == 0)
            continue;
        // The same app filed under ids that differ only in case: add them up
        std::array<int, 5> &slot = out[it.key().toLower()];
        for (int i = 0; i < 5; ++i)
            slot[i] += stars[i];
    }
    return out;
}

void Reviews::applyRatings(const QByteArray &json, bool save)
{
    QPointer<Reviews> self(this);
    const QString path = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/ratings.json");
    // ~2 MB of JSON: parse it away from the window
    QThread *thread = QThread::create([self, json, save, path] {
        auto parsed = parseRatings(json);
        if (save && !parsed.isEmpty()) {
            QDir().mkpath(QFileInfo(path).path());
            QSaveFile file(path);
            if (file.open(QIODevice::WriteOnly)) {
                file.write(json);
                file.commit();
            }
        }
        QMetaObject::invokeMethod(qApp, [self, parsed = std::move(parsed)]() mutable {
            if (!self || parsed.isEmpty())
                return;
            self->m_ratings = std::move(parsed);
            self->m_ratingByKey.clear();
            self->bump();
        }, Qt::QueuedConnection);
    });
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->start();
}

void Reviews::loadRatings()
{
    if (m_ratingsLoading)
        return;
    const QString path = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/ratings.json");
    const QFileInfo info(path);
    QByteArray cached;
    if (info.exists()) {
        QFile file(path);
        if (file.open(QIODevice::ReadOnly))
            cached = file.readAll();
    }
    if (!cached.isEmpty())
        applyRatings(cached, false);
    if (!cached.isEmpty() && info.lastModified().secsTo(QDateTime::currentDateTime()) < RatingsMaxAge)
        return;

    m_ratingsLoading = true;
    QNetworkRequest request{QUrl(apiUrl(QStringLiteral("ratings")))};
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("lingmo-store/" LINGMO_STORE_VERSION));
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *reply = m_network->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        m_ratingsLoading = false;
        if (reply->error() != QNetworkReply::NoError) {
            qInfo().noquote() << "ODRS ratings unavailable:" << reply->errorString();
            return; // keep whatever the cache had
        }
        applyRatings(reply->readAll(), true);
    });
}

QStringList Reviews::idsFor(const QString &key) const
{
    const AppEntry *app = m_catalog->entry(key);
    if (!app)
        return {};
    QStringList ids;
    auto add = [&ids](const QString &id) {
        if (!id.isEmpty() && !ids.contains(id, Qt::CaseInsensitive))
            ids << id;
    };
    // The Flathub id first: that's where most reviews of GNOME Software and Discover go
    if (app->flathub)
        add(app->flathub->flatpakRef.section(QLatin1Char('/'), 1, 1));
    for (const QString &id : app->reviewIds)
        add(id);
    add(app->id);
    // ODRS has both "gimp.desktop" and "org.gimp.GIMP" styles
    const QStringList base = ids;
    for (const QString &id : base) {
        if (id.endsWith(QLatin1String(".desktop")))
            add(id.chopped(8));
        else
            add(id + QStringLiteral(".desktop"));
    }
    return ids;
}

QVariantMap Reviews::rating(const QString &key) const
{
    if (m_ratings.isEmpty() || key.isEmpty())
        return {};
    if (auto it = m_ratingByKey.constFind(key); it != m_ratingByKey.constEnd())
        return it.value();
    std::array<int, 5> stars{};
    for (const QString &id : idsFor(key)) {
        const auto found = m_ratings.constFind(id.toLower());
        if (found == m_ratings.constEnd())
            continue;
        for (int i = 0; i < 5; ++i)
            stars[i] += found.value()[i];
    }
    int count = 0;
    qint64 sum = 0;
    QVariantList list;
    for (int i = 0; i < 5; ++i) {
        count += stars[i];
        sum += qint64(stars[i]) * (i + 1);
        list << stars[i];
    }
    QVariantMap map;
    if (count > 0) {
        map = {
            {QStringLiteral("count"), count},
            {QStringLiteral("average"), qRound(sum * 10.0 / count) / 10.0},
            {QStringLiteral("stars"), list},
        };
    }
    m_ratingByKey.insert(key, map);
    return map;
}

QVariantMap Reviews::reviews(const QString &key) const
{
    const auto it = m_reviews.constFind(key);
    if (it == m_reviews.constEnd())
        return {{QStringLiteral("state"), QStringLiteral("none")}, {QStringLiteral("items"), QVariantList()}};
    bool reviewed = false;
    for (const QVariant &v : it->items)
        reviewed = reviewed || v.toMap().value(QStringLiteral("mine")).toBool();
    return {
        {QStringLiteral("state"), it->state},
        {QStringLiteral("items"), it->items},
        {QStringLiteral("english"), it->english},
        {QStringLiteral("stale"), it->stale},
        {QStringLiteral("reviewed"), reviewed},
    };
}

bool Reviews::loadCachedReviews(const QString &key, AppReviews *out) const
{
    QFile file(cacheDir() + QLatin1Char('/') + QString::fromLatin1(key.toUtf8().toPercentEncoding()) + QStringLiteral(".json"));
    if (!file.open(QIODevice::ReadOnly))
        return false;
    const QJsonObject doc = QJsonDocument::fromJson(file.readAll()).object();
    if (doc.isEmpty())
        return false;
    out->items.clear();
    for (const QJsonValue &v : doc.value(QStringLiteral("items")).toArray()) {
        QVariantMap item = v.toObject().toVariantMap();
        // Dates are written in the reader's language
        const qint64 when = item.value(QStringLiteral("timestamp")).toLongLong();
        item.insert(QStringLiteral("date"), QLocale().toString(QDateTime::fromSecsSinceEpoch(when).date(), QLocale::ShortFormat));
        item.insert(QStringLiteral("mine"), item.value(QStringLiteral("userHash")).toString() == m_userHash && !m_userHash.isEmpty());
        out->items << item;
    }
    out->english = doc.value(QStringLiteral("english")).toBool();
    out->fetched = doc.value(QStringLiteral("fetched")).toInteger();
    out->skey = doc.value(QStringLiteral("skey")).toString();
    out->state = QStringLiteral("ready");
    return true;
}

void Reviews::saveReviews(const QString &key) const
{
    const auto it = m_reviews.constFind(key);
    if (it == m_reviews.constEnd())
        return;
    QJsonArray items;
    for (const QVariant &v : it->items) {
        QVariantMap item = v.toMap();
        item.remove(QStringLiteral("date"));
        item.remove(QStringLiteral("mine"));
        items << QJsonObject::fromVariantMap(item);
    }
    const QJsonObject doc{
        {QStringLiteral("fetched"), it->fetched},
        {QStringLiteral("english"), it->english},
        {QStringLiteral("skey"), it->skey},
        {QStringLiteral("items"), items},
    };
    QSaveFile file(cacheDir() + QLatin1Char('/') + QString::fromLatin1(key.toUtf8().toPercentEncoding()) + QStringLiteral(".json"));
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(doc).toJson(QJsonDocument::Compact));
        file.commit();
    }
}

void Reviews::fetch(const QString &key, bool force)
{
    if (key.isEmpty() || !m_catalog->entry(key))
        return;
    AppReviews &entry = m_reviews[key];
    if (entry.state == QLatin1String("loading"))
        return;
    const qint64 now = QDateTime::currentSecsSinceEpoch();
    if (entry.state.isEmpty()) {
        AppReviews cached;
        if (loadCachedReviews(key, &cached)) {
            entry = cached;
            if (!force && now - entry.fetched < ReviewsMaxAge) {
                bump();
                return;
            }
        }
    } else if (!force && entry.state == QLatin1String("ready") && !entry.stale && now - entry.fetched < ReviewsMaxAge) {
        return;
    }
    entry.state = QStringLiteral("loading");
    bump();
    requestReviews(key, m_locale);
}

QVariantMap Reviews::reviewMap(const QJsonObject &review) const
{
    const qint64 when = qint64(review.value(QStringLiteral("date_created")).toDouble());
    const QString author = review.value(QStringLiteral("user_display")).toString().trimmed();
    const QString hash = review.value(QStringLiteral("user_hash")).toString();
    return {
        {QStringLiteral("id"), review.value(QStringLiteral("review_id")).toInteger()},
        {QStringLiteral("stars"), qBound(1, qRound(review.value(QStringLiteral("rating")).toDouble() / 20.0), 5)},
        {QStringLiteral("summary"), review.value(QStringLiteral("summary")).toString().trimmed()},
        {QStringLiteral("description"), review.value(QStringLiteral("description")).toString().trimmed()},
        {QStringLiteral("author"), author.isEmpty() ? tr("Anonymous") : author},
        {QStringLiteral("version"), review.value(QStringLiteral("version")).toString()},
        {QStringLiteral("timestamp"), when},
        {QStringLiteral("date"), QLocale().toString(QDateTime::fromSecsSinceEpoch(when).date(), QLocale::ShortFormat)},
        {QStringLiteral("userHash"), hash},
        {QStringLiteral("mine"), !m_userHash.isEmpty() && hash == m_userHash},
    };
}

void Reviews::requestReviews(const QString &key, const QString &locale)
{
    const QStringList ids = idsFor(key);
    if (ids.isEmpty())
        return;
    const QJsonObject body{
        {QStringLiteral("user_hash"), m_userHash.isEmpty() ? QString(40, QLatin1Char('0')) : m_userHash},
        {QStringLiteral("app_id"), ids.first()},
        {QStringLiteral("compat_ids"), QJsonArray::fromStringList(ids.mid(1))},
        {QStringLiteral("locale"), locale},
        {QStringLiteral("distro"), m_distro},
        {QStringLiteral("version"), versionOf(m_catalog->entry(key))},
        {QStringLiteral("limit"), 20},
    };
    const bool english = locale != m_locale;
    QNetworkReply *reply = post(QStringLiteral("fetch"), body);
    connect(reply, &QNetworkReply::finished, this, [this, reply, key, english] {
        reply->deleteLater();
        AppReviews &entry = m_reviews[key];
        if (reply->error() != QNetworkReply::NoError) {
            const bool offline = isOffline(reply->error());
            qInfo().noquote() << "ODRS reviews of" << key << "unavailable:" << reply->errorString();
            AppReviews cached;
            if (!entry.items.isEmpty() || loadCachedReviews(key, &cached)) {
                if (entry.items.isEmpty())
                    entry = cached;
                entry.state = QStringLiteral("ready");
                entry.stale = true;
            } else {
                entry.state = offline ? QStringLiteral("offline") : QStringLiteral("error");
            }
            bump();
            return;
        }
        const QJsonArray list = QJsonDocument::fromJson(reply->readAll()).array();
        bool any = false;
        for (const QJsonValue &v : list)
            any = any || v.toObject().contains(QStringLiteral("review_id"));
        // Nothing in the user's language: show what English speakers wrote
        if (!any && !english && !m_locale.startsWith(QLatin1String("en"))) {
            if (!list.isEmpty())
                entry.skey = list.first().toObject().value(QStringLiteral("user_skey")).toString();
            requestReviews(key, QStringLiteral("en_US"));
            return;
        }
        setReviews(key, list, english);
    });
}

void Reviews::setReviews(const QString &key, const QJsonArray &list, bool english)
{
    AppReviews &entry = m_reviews[key];
    QList<QVariantMap> items;
    for (const QJsonValue &v : list) {
        const QJsonObject review = v.toObject();
        if (entry.skey.isEmpty() && !english)
            entry.skey = review.value(QStringLiteral("user_skey")).toString();
        if (!review.contains(QStringLiteral("review_id")) || review.value(QStringLiteral("reported")).toInt() > 0)
            continue;
        items << reviewMap(review);
    }
    // Newest first
    std::stable_sort(items.begin(), items.end(), [](const QVariantMap &a, const QVariantMap &b) {
        return a.value(QStringLiteral("timestamp")).toLongLong() > b.value(QStringLiteral("timestamp")).toLongLong();
    });
    entry.items.clear();
    for (int i = 0; i < items.size() && i < MaxReviews; ++i)
        entry.items << items.at(i);
    entry.english = english && !entry.items.isEmpty();
    entry.stale = false;
    entry.state = QStringLiteral("ready");
    entry.fetched = QDateTime::currentSecsSinceEpoch();
    saveReviews(key);
    bump();
}

bool Reviews::submit(const QString &key, const QString &version, int stars, const QString &summary,
                     const QString &description, const QString &name)
{
    const QStringList ids = idsFor(key);
    const QString title = summary.simplified();
    const QString text = description.trimmed();
    if (m_submitting || ids.isEmpty() || m_userHash.isEmpty() || stars < 1 || stars > 5 || title.isEmpty()
        || title.size() > SummaryMax || text.size() < DescriptionMin || text.size() > DescriptionMax)
        return false;

    const QString display = name.simplified().isEmpty() ? tr("Anonymous") : name.simplified();
    QJsonObject body{
        {QStringLiteral("app_id"), ids.first()},
        {QStringLiteral("locale"), m_locale},
        {QStringLiteral("summary"), title},
        {QStringLiteral("description"), text},
        {QStringLiteral("user_hash"), m_userHash},
        {QStringLiteral("version"), version.isEmpty() ? QStringLiteral("unknown") : version},
        {QStringLiteral("distro"), m_distro},
        {QStringLiteral("rating"), stars * 20},
        {QStringLiteral("user_display"), display},
    };
    const QString skey = m_reviews.value(key).skey;
    if (!skey.isEmpty())
        body.insert(QStringLiteral("user_skey"), skey);

    m_submitting = true;
    bump();
    auto done = [this, key, body](bool ok, const QString &message) {
        m_submitting = false;
        if (ok) {
            AppReviews &entry = m_reviews[key];
            QJsonObject mine = body;
            mine.insert(QStringLiteral("date_created"), double(QDateTime::currentSecsSinceEpoch()));
            mine.insert(QStringLiteral("review_id"), 0);
            entry.items.prepend(reviewMap(mine));
            entry.english = false;
            if (entry.state != QLatin1String("loading"))
                entry.state = QStringLiteral("ready");
            saveReviews(key);
        }
        bump();
        Q_EMIT submitted(key, ok, message);
    };

    if (m_fake && qEnvironmentVariableIsEmpty("LINGMO_STORE_ODRS_URL")) {
        qInfo().noquote() << "[fake] would send this review to ODRS:" << QJsonDocument(body).toJson(QJsonDocument::Compact);
        QTimer::singleShot(800ms, this, [done] { done(true, QString()); });
        return true;
    }

    QNetworkReply *reply = post(QStringLiteral("submit"), body);
    connect(reply, &QNetworkReply::finished, this, [reply, done] {
        reply->deleteLater();
        const QJsonObject answer = QJsonDocument::fromJson(reply->readAll()).object();
        if (reply->error() != QNetworkReply::NoError && answer.isEmpty()) {
            done(false, isOffline(reply->error()) ? Errors::offline()
                                                  : tr("Could not send your review. Try again later."));
            return;
        }
        if (!answer.value(QStringLiteral("success")).toBool()) {
            const QString msg = answer.value(QStringLiteral("msg")).toString();
            qWarning().noquote() << "ODRS refused the review:" << msg;
            done(false, msg.contains(QLatin1String("already"), Qt::CaseInsensitive)
                            ? tr("You already reviewed this app.")
                            : tr("The review service did not accept your review: %1").arg(msg));
            return;
        }
        done(true, QString());
    });
    return true;
}
