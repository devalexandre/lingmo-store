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

#include "flatpakbackend.h"
#include "errors.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QPointer>
#include <QProcess>
#include <QStandardPaths>
#include <QSysInfo>
#include <QTemporaryFile>
#include <QThread>
#include <QTimer>

#ifdef HAVE_FLATPAK
#include <flatpak.h>
#endif

using namespace std::chrono_literals;

namespace {

QString flatpakArch()
{
#ifdef HAVE_FLATPAK
    return QString::fromUtf8(flatpak_get_default_arch());
#else
    const QString arch = QSysInfo::currentCpuArchitecture();
    return arch == QLatin1String("arm64") ? QStringLiteral("aarch64") : arch;
#endif
}

QString userFlatpakDir()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/flatpak");
}

QString installationDir(bool user)
{
    return user ? userFlatpakDir() : QStringLiteral("/var/lib/flatpak");
}

// Flathub's catalog of an installation, as flatpak deploys it
QString appstreamDir(bool user)
{
    return installationDir(user) + QStringLiteral("/appstream/%1/%2/active")
        .arg(QLatin1String(FlatpakBackend::Remote), flatpakArch());
}

#ifdef HAVE_FLATPAK
struct GErrorDeleter {
    void operator()(GError *e) const { g_error_free(e); }
};

FlatpakInstallation *openInstallation(bool user, GCancellable *cancellable, QString *error)
{
    GError *err = nullptr;
    FlatpakInstallation *inst = user ? flatpak_installation_new_user(cancellable, &err)
                                     : flatpak_installation_new_system(cancellable, &err);
    if (!inst && error) {
        *error = QString::fromUtf8(err ? err->message : "unknown error");
    }
    if (err)
        g_error_free(err);
    return inst;
}

// Maps libflatpak errors to something a person can act on
QString friendlyError(GError *err, bool install)
{
    if (!err)
        return QString();
    const QString message = QString::fromUtf8(err->message);
    if (g_error_matches(err, G_IO_ERROR, G_IO_ERROR_CANCELLED) || g_error_matches(err, FLATPAK_ERROR, FLATPAK_ERROR_ABORTED))
        return Errors::cancelled();
    if (message.contains(QLatin1String("authoriz"), Qt::CaseInsensitive)
        || message.contains(QLatin1String("Authentication"), Qt::CaseInsensitive)
        || message.contains(QLatin1String("dismissed"), Qt::CaseInsensitive))
        return Errors::authCancelled();
    if (message.contains(QLatin1String("resolve"), Qt::CaseInsensitive)
        || message.contains(QLatin1String("network"), Qt::CaseInsensitive)
        || message.contains(QLatin1String("Timeout"), Qt::CaseInsensitive)
        || message.contains(QLatin1String("connect"), Qt::CaseInsensitive)
        || g_error_matches(err, G_IO_ERROR, G_IO_ERROR_NETWORK_UNREACHABLE)
        || g_error_matches(err, G_IO_ERROR, G_IO_ERROR_HOST_NOT_FOUND))
        return Errors::offline();
    if (message.contains(QLatin1String("No space left"), Qt::CaseInsensitive)
        || g_error_matches(err, G_IO_ERROR, G_IO_ERROR_NO_SPACE))
        return Errors::noSpace();
    if (message.contains(QLatin1String("locked"), Qt::CaseInsensitive))
        return Errors::busy();
    return (install ? Errors::installFailed() : Errors::removeFailed()) + QLatin1Char(' ') + message;
}

struct TransactionContext {
    FlatpakBackend *self;
    QString appId;
    bool install;
    QString operationError;
};

void onProgressChanged(FlatpakTransactionProgress *progress, gpointer data)
{
    auto *ctx = static_cast<TransactionContext *>(data);
    auto *transaction = static_cast<FlatpakTransaction *>(g_object_get_data(G_OBJECT(progress), "lingmo-transaction"));
    auto *op = static_cast<FlatpakTransactionOperation *>(g_object_get_data(G_OBJECT(progress), "lingmo-operation"));
    if (!transaction || !op)
        return;

    GList *ops = flatpak_transaction_get_operations(transaction);
    const int total = qMax(1, int(g_list_length(ops)));
    const int index = qMax(0, g_list_index(ops, op));
    g_list_free_full(ops, g_object_unref);

    const int percent = flatpak_transaction_progress_get_progress(progress);
    const double fraction = (index + percent / 100.0) / total;

    const QString ref = QString::fromUtf8(flatpak_transaction_operation_get_ref(op));
    const bool isApp = ref.startsWith(QLatin1String("app/")) && ref.section(QLatin1Char('/'), 1, 1) == ctx->appId;
    QString text;
    switch (flatpak_transaction_operation_get_operation_type(op)) {
    case FLATPAK_TRANSACTION_OPERATION_UNINSTALL:
        text = FlatpakBackend::tr("Removing…");
        break;
    default:
        text = isApp ? FlatpakBackend::tr("Downloading and installing (%1%)…").arg(percent)
                     : FlatpakBackend::tr("Installing required components (%1 of %2)…").arg(index + 1).arg(total);
        break;
    }
    Q_EMIT ctx->self->progress(fraction, text);
}

void onNewOperation(FlatpakTransaction *transaction, FlatpakTransactionOperation *op,
                    FlatpakTransactionProgress *progress, gpointer data)
{
    g_object_set_data(G_OBJECT(progress), "lingmo-transaction", transaction);
    g_object_set_data(G_OBJECT(progress), "lingmo-operation", op);
    flatpak_transaction_progress_set_update_frequency(progress, 250);
    g_signal_connect(progress, "changed", G_CALLBACK(onProgressChanged), data);
    onProgressChanged(progress, data);
}

gboolean onOperationError(FlatpakTransaction *, FlatpakTransactionOperation *, GError *error,
                          gint details, gpointer data)
{
    auto *ctx = static_cast<TransactionContext *>(data);
    // An already installed app is not a failure
    if (g_error_matches(error, FLATPAK_ERROR, FLATPAK_ERROR_ALREADY_INSTALLED)
        || g_error_matches(error, FLATPAK_ERROR, FLATPAK_ERROR_NOT_INSTALLED))
        return TRUE;
    if (details & FLATPAK_TRANSACTION_ERROR_DETAILS_NON_FATAL)
        return TRUE;
    ctx->operationError = friendlyError(error, ctx->install);
    return FALSE; // stop the transaction
}

gboolean onAddNewRemote(FlatpakTransaction *, FlatpakTransactionRemoteReason, const char *, const char *,
                        const char *, gpointer)
{
    return FALSE; // never add remotes behind the user's back
}
#endif

} // namespace

FlatpakBackend::FlatpakBackend(bool fake, QObject *parent)
    : QObject(parent)
    , m_fake(fake)
    , m_user(qEnvironmentVariable("LINGMO_STORE_FLATPAK_INSTALLATION") == QLatin1String("user"))
{
    qRegisterMetaType<QHash<QString, QString>>();
}

FlatpakBackend::~FlatpakBackend()
{
    cancel();
}

bool FlatpakBackend::available() const
{
#ifdef HAVE_FLATPAK
    return true;
#else
    return false;
#endif
}

void FlatpakBackend::runInThread(std::function<void()> work)
{
    QThread *thread = QThread::create(std::move(work));
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->start();
}

void FlatpakBackend::setState(State state, const QString &error)
{
    if (m_state == state && m_error == error)
        return;
    m_state = state;
    m_error = error;
    Q_EMIT stateChanged();
}

QStringList FlatpakBackend::extraAppstreamDirs() const
{
    // libappstream reads /var/lib/flatpak by itself; add the per-user installation
    QStringList dirs;
    const QString user = appstreamDir(true);
    if (QFileInfo::exists(user + QStringLiteral("/appstream.xml.gz")) || QFileInfo::exists(user + QStringLiteral("/appstream.xml")))
        dirs << user;
    return dirs;
}

void FlatpakBackend::probe()
{
#ifdef HAVE_FLATPAK
    QPointer<FlatpakBackend> self(this);
    const bool user = m_user;
    runInThread([self, user] {
        QString error;
        QHash<QString, QString> installed;
        bool usable = false;
        bool hasRemote = false;
        for (bool u : {false, true}) {
            FlatpakInstallation *inst = openInstallation(u, nullptr, &error);
            if (!inst)
                continue;
            if (u == user) {
                usable = true;
                GError *err = nullptr;
                FlatpakRemote *remote = flatpak_installation_get_remote_by_name(inst, Remote, nullptr, &err);
                hasRemote = remote && !flatpak_remote_get_disabled(remote);
                if (remote)
                    g_object_unref(remote);
                if (err)
                    g_error_free(err);
            }
            GError *err = nullptr;
            GPtrArray *refs = flatpak_installation_list_installed_refs_by_kind(inst, FLATPAK_REF_KIND_APP, nullptr, &err);
            if (refs) {
                for (guint i = 0; i < refs->len; ++i) {
                    auto *ref = FLATPAK_REF(g_ptr_array_index(refs, i));
                    installed.insert(QString::fromUtf8(flatpak_ref_get_name(ref)),
                                     u ? QStringLiteral("user") : QStringLiteral("system"));
                }
                g_ptr_array_unref(refs);
            }
            if (err)
                g_error_free(err);
            g_object_unref(inst);
        }
        QMetaObject::invokeMethod(qApp, [self, usable, hasRemote, installed, error] {
            if (!self)
                return;
            if (!usable)
                self->setState(Unavailable, error);
            else if (!hasRemote)
                self->setState(self->m_state == AddingRemote ? AddingRemote : NoRemote);
            else if (self->m_state == Probing || self->m_state == NoRemote || self->m_state == Unavailable)
                self->setState(Ready);
            Q_EMIT self->probed(installed);
            if (usable && hasRemote)
                self->refreshAppstream();
        }, Qt::QueuedConnection);
    });
#else
    setState(Unavailable, tr("Flatpak support was not built in."));
    Q_EMIT probed({});
#endif
}

void FlatpakBackend::refreshAppstream(bool force)
{
#ifdef HAVE_FLATPAK
    if (m_refreshing)
        return;
    const QString dir = appstreamDir(m_user);
    const QFileInfo active(dir);
    const bool missing = !QFileInfo::exists(dir + QStringLiteral("/appstream.xml.gz"))
        && !QFileInfo::exists(dir + QStringLiteral("/appstream.xml"));
    QFileInfo stamp(QFileInfo(dir).path() + QStringLiteral("/.timestamp"));
    const QDateTime updated = stamp.exists() ? stamp.lastModified() : active.lastModified();
    const bool stale = missing || !updated.isValid() || updated.secsTo(QDateTime::currentDateTime()) > 24 * 3600;
    if (!force && !stale)
        return;
    if (m_fake && !m_user) {
        // Fake mode never writes to /var/lib/flatpak
        qInfo("[fake] skipping the Flathub catalog update of the system installation");
        return;
    }

    m_refreshing = true;
    if (missing)
        setState(Refreshing);
    QPointer<FlatpakBackend> self(this);
    const bool user = m_user;
    runInThread([self, user, missing] {
        QString error;
        bool changed = false;
        FlatpakInstallation *inst = openInstallation(user, nullptr, &error);
        if (inst) {
            GError *err = nullptr;
            gboolean out_changed = FALSE;
            if (!flatpak_installation_update_appstream_full_sync(inst, Remote, nullptr, nullptr, nullptr,
                                                                 &out_changed, nullptr, &err)) {
                error = friendlyError(err, true);
                qWarning() << "Updating the Flathub catalog failed:" << (err ? err->message : "");
            }
            changed = out_changed;
            if (err)
                g_error_free(err);
            g_object_unref(inst);
        }
        QMetaObject::invokeMethod(qApp, [self, error, changed, missing] {
            if (!self)
                return;
            self->m_refreshing = false;
            if (!error.isEmpty() && missing) {
                self->setState(Error, error);
                return;
            }
            self->setState(Ready);
            if (changed || missing)
                Q_EMIT self->catalogUpdated();
        }, Qt::QueuedConnection);
    });
#else
    Q_UNUSED(force)
#endif
}

void FlatpakBackend::addFlathub()
{
    if (m_state == AddingRemote)
        return;
    setState(AddingRemote);
    if (m_fake) {
        QTimer::singleShot(1500ms, this, [this] {
            qInfo("[fake] flatpak remote-add flathub");
            setState(Ready);
            Q_EMIT remoteAdded(true, QString());
        });
        return;
    }

    // The .flatpakrepo (with Flathub's signing key) ships in the binary: no download
    auto *repo = new QTemporaryFile(QDir::tempPath() + QStringLiteral("/lingmo-store-XXXXXX.flatpakrepo"), this);
    QFile source(QStringLiteral(":/data/flathub.flatpakrepo"));
    if (!repo->open() || !source.open(QIODevice::ReadOnly)) {
        delete repo;
        setState(NoRemote, tr("Could not add Flathub."));
        Q_EMIT remoteAdded(false, m_error);
        return;
    }
    repo->write(source.readAll());
    repo->flush();

    auto *proc = new QProcess(this);
    proc->setProcessChannelMode(QProcess::MergedChannels);
    proc->setProgram(QStringLiteral("flatpak"));
    proc->setArguments({QStringLiteral("remote-add"), QStringLiteral("--if-not-exists"),
                        m_user ? QStringLiteral("--user") : QStringLiteral("--system"),
                        QLatin1String(Remote), repo->fileName()});
    connect(proc, &QProcess::finished, this, [this, proc, repo](int code, QProcess::ExitStatus status) {
        const QString out = QString::fromUtf8(proc->readAll()).trimmed();
        proc->deleteLater();
        repo->deleteLater();
        if (status == QProcess::NormalExit && code == 0) {
            setState(Ready);
            Q_EMIT remoteAdded(true, QString());
            probe();
            refreshAppstream(true);
            return;
        }
        qWarning() << "flatpak remote-add failed:" << code << out;
        const QString error = out.contains(QLatin1String("authoriz"), Qt::CaseInsensitive)
            ? Errors::authCancelled()
            : tr("Could not add Flathub.") + QLatin1Char(' ') + out;
        setState(NoRemote, error);
        Q_EMIT remoteAdded(false, error);
    });
    connect(proc, &QProcess::errorOccurred, this, [this, proc, repo](QProcess::ProcessError e) {
        if (e != QProcess::FailedToStart)
            return;
        proc->deleteLater();
        repo->deleteLater();
        setState(Unavailable, tr("The flatpak program is not installed."));
        Q_EMIT remoteAdded(false, m_error);
    });
    proc->start();
}

void FlatpakBackend::fetchSize(const QString &id)
{
#ifdef HAVE_FLATPAK
    QPointer<FlatpakBackend> self(this);
    const bool user = m_user;
    runInThread([self, user, id] {
        qint64 download = -1, installed = -1;
        FlatpakInstallation *inst = openInstallation(user, nullptr, nullptr);
        if (inst) {
            GError *err = nullptr;
            const QByteArray name = id.toUtf8();
            FlatpakRemoteRef *ref = flatpak_installation_fetch_remote_ref_sync(
                inst, Remote, FLATPAK_REF_KIND_APP, name.constData(), flatpak_get_default_arch(), "stable", nullptr, &err);
            if (ref) {
                download = qint64(flatpak_remote_ref_get_download_size(ref));
                installed = qint64(flatpak_remote_ref_get_installed_size(ref));
                g_object_unref(ref);
            }
            if (err)
                g_error_free(err);
            g_object_unref(inst);
        }
        if (self)
            Q_EMIT self->sizeFetched(id, download, installed);
    });
#else
    Q_UNUSED(id)
#endif
}

void FlatpakBackend::install(const QString &id)
{
    if (m_fake)
        runFake(id, true);
    else
        runTransaction(id, true, m_user ? QStringLiteral("user") : QStringLiteral("system"));
}

void FlatpakBackend::uninstall(const QString &id, const QString &installation)
{
    if (m_fake)
        runFake(id, false);
    else
        runTransaction(id, false, installation.isEmpty() ? (m_user ? QStringLiteral("user") : QStringLiteral("system"))
                                                         : installation);
}

void FlatpakBackend::cancel()
{
#ifdef HAVE_FLATPAK
    if (void *c = m_cancellable.load())
        g_cancellable_cancel(G_CANCELLABLE(c));
#endif
    if (QTimer *timer = findChild<QTimer *>(QStringLiteral("fakeTransaction"))) {
        timer->stop();
        timer->deleteLater();
        Q_EMIT finished(false, Errors::cancelled());
    }
}

void FlatpakBackend::runTransaction(const QString &id, bool install, const QString &installation)
{
#ifdef HAVE_FLATPAK
    Q_EMIT progress(-1, install ? tr("Preparing…") : tr("Removing…"));
    GCancellable *cancellable = g_cancellable_new();
    m_cancellable = cancellable;
    QPointer<FlatpakBackend> self(this);
    FlatpakBackend *raw = this;
    runInThread([self, raw, id, install, installation, cancellable] {
        GMainContext *context = g_main_context_new();
        g_main_context_push_thread_default(context);

        QString error;
        bool ok = false;
        FlatpakInstallation *inst = openInstallation(installation == QLatin1String("user"), cancellable, &error);
        if (inst) {
            GError *err = nullptr;
            FlatpakTransaction *transaction = flatpak_transaction_new_for_installation(inst, cancellable, &err);
            TransactionContext ctx{raw, id, install, QString()};
            if (transaction) {
                g_signal_connect(transaction, "new-operation", G_CALLBACK(onNewOperation), &ctx);
                g_signal_connect(transaction, "operation-error", G_CALLBACK(onOperationError), &ctx);
                g_signal_connect(transaction, "add-new-remote", G_CALLBACK(onAddNewRemote), &ctx);
                flatpak_transaction_add_default_dependency_sources(transaction);

                gboolean added = FALSE;
                if (install) {
                    const QByteArray ref = QStringLiteral("app/%1/%2/stable").arg(id, flatpakArch()).toUtf8();
                    added = flatpak_transaction_add_install(transaction, Remote, ref.constData(), nullptr, &err);
                } else {
                    const QByteArray name = id.toUtf8();
                    FlatpakInstalledRef *installed = flatpak_installation_get_installed_ref(
                        inst, FLATPAK_REF_KIND_APP, name.constData(), nullptr, nullptr, cancellable, &err);
                    if (installed) {
                        gchar *ref = flatpak_ref_format_ref(FLATPAK_REF(installed));
                        added = flatpak_transaction_add_uninstall(transaction, ref, &err);
                        g_free(ref);
                        g_object_unref(installed);
                    }
                }
                if (added)
                    ok = flatpak_transaction_run(transaction, cancellable, &err);
                if (!ok)
                    error = !ctx.operationError.isEmpty() ? ctx.operationError : friendlyError(err, install);
                g_object_unref(transaction);
            } else {
                error = friendlyError(err, install);
            }
            if (err)
                g_error_free(err);
            g_object_unref(inst);
        }

        g_main_context_pop_thread_default(context);
        g_main_context_unref(context);

        QMetaObject::invokeMethod(qApp, [self, ok, error, cancellable] {
            if (self) {
                if (self->m_cancellable.load() == cancellable)
                    self->m_cancellable = nullptr;
                Q_EMIT self->finished(ok, error);
            }
            g_object_unref(cancellable);
        }, Qt::QueuedConnection);
    });
#else
    Q_UNUSED(id)
    Q_UNUSED(install)
    Q_UNUSED(installation)
    Q_EMIT finished(false, tr("Flatpak support was not built in."));
#endif
}

// LINGMO_STORE_FAKE: simulated transaction (1|ok, fail, offline, cancel)
void FlatpakBackend::runFake(const QString &id, bool install)
{
    QString mode = qEnvironmentVariable("LINGMO_STORE_FAKE");
    if (mode == QLatin1String("1"))
        mode = QStringLiteral("ok");
    qInfo().noquote() << "[fake] flatpak" << (install ? "install" : "uninstall") << (m_user ? "--user" : "--system")
                      << Remote << id;
    auto *timer = new QTimer(this);
    timer->setObjectName(QStringLiteral("fakeTransaction"));
    timer->setInterval(120ms);
    auto step = std::make_shared<int>(0);
    connect(timer, &QTimer::timeout, this, [this, timer, step, install, mode] {
        const int s = ++*step;
        if (mode == QLatin1String("cancel") && s == 8) {
            timer->deleteLater();
            Q_EMIT finished(false, Errors::authCancelled());
            return;
        }
        if ((mode == QLatin1String("offline") || mode == QLatin1String("fail")) && s == 12) {
            timer->deleteLater();
            Q_EMIT finished(false, mode == QLatin1String("offline") ? Errors::offline()
                                                                     : Errors::installFailed() + QStringLiteral(" (simulated)"));
            return;
        }
        if (!install) {
            Q_EMIT progress(s / 12.0, tr("Removing…"));
            if (s >= 12) {
                timer->deleteLater();
                Q_EMIT finished(true, QString());
            }
            return;
        }
        if (s <= 10)
            Q_EMIT progress(s / 50.0, tr("Installing required components (%1 of %2)…").arg(1).arg(2));
        else
            Q_EMIT progress(0.2 + (s - 10) / 50.0, tr("Downloading and installing (%1%)…").arg(qMin(100, (s - 10) * 100 / 40)));
        if (s >= 50) {
            timer->deleteLater();
            Q_EMIT finished(true, QString());
        }
    });
    Q_EMIT progress(-1, install ? tr("Preparing…") : tr("Removing…"));
    timer->start();
}
