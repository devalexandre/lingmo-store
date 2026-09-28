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

#include "imageproviders.h"

#include <QFile>
#include <QImageReader>
#include <QNetworkAccessManager>
#include <QNetworkDiskCache>
#include <QStandardPaths>
#include <QUrl>

#ifdef HAVE_JXL
#include <jxl/decode.h>
#endif

static QImage decodeJxl(const QByteArray &data)
{
#ifdef HAVE_JXL
    JxlDecoder *dec = JxlDecoderCreate(nullptr);
    if (!dec)
        return {};
    QImage image;
    JxlBasicInfo info;
    const JxlPixelFormat format{4, JXL_TYPE_UINT8, JXL_NATIVE_ENDIAN, 0};
    bool ok = JxlDecoderSubscribeEvents(dec, JXL_DEC_BASIC_INFO | JXL_DEC_FULL_IMAGE) == JXL_DEC_SUCCESS
        && JxlDecoderSetInput(dec, reinterpret_cast<const uint8_t *>(data.constData()), data.size()) == JXL_DEC_SUCCESS;
    if (ok)
        JxlDecoderCloseInput(dec);
    while (ok) {
        const JxlDecoderStatus status = JxlDecoderProcessInput(dec);
        if (status == JXL_DEC_BASIC_INFO) {
            if (JxlDecoderGetBasicInfo(dec, &info) != JXL_DEC_SUCCESS || info.xsize > 4096 || info.ysize > 4096) {
                ok = false;
                break;
            }
            image = QImage(int(info.xsize), int(info.ysize), QImage::Format_RGBA8888);
        } else if (status == JXL_DEC_NEED_IMAGE_OUT_BUFFER) {
            if (image.isNull()
                || JxlDecoderSetImageOutBuffer(dec, &format, image.bits(), size_t(image.sizeInBytes())) != JXL_DEC_SUCCESS)
                ok = false;
        } else if (status == JXL_DEC_FULL_IMAGE) {
            continue;
        } else if (status == JXL_DEC_SUCCESS) {
            break;
        } else {
            ok = false; // error, or truncated input
        }
    }
    JxlDecoderDestroy(dec);
    return ok ? image : QImage();
#else
    Q_UNUSED(data)
    return {};
#endif
}

AppIconProvider::AppIconProvider()
    : QQuickImageProvider(QQuickImageProvider::Image, QQmlImageProviderBase::ForceAsynchronousImageLoading)
{
}

QImage AppIconProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    const QString path = QUrl::fromPercentEncoding(id.toUtf8());
    QImage image;
    // Qt's own readers first (kimageformats adds JPEG XL), then libjxl
    QImageReader reader(path);
    if (reader.canRead())
        image = reader.read();
    if (image.isNull()) {
        QFile file(path);
        if (file.open(QIODevice::ReadOnly) && file.size() < 4 * 1024 * 1024)
            image = decodeJxl(file.readAll());
    }
    if (image.isNull())
        return {};
    if (requestedSize.isValid() && !requestedSize.isEmpty() && image.size() != requestedSize)
        image = image.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    if (size)
        *size = image.size();
    return image;
}

namespace {
class CachingNetworkAccessManager : public QNetworkAccessManager
{
public:
    using QNetworkAccessManager::QNetworkAccessManager;

protected:
    QNetworkReply *createRequest(Operation op, const QNetworkRequest &original, QIODevice *data) override
    {
        QNetworkRequest request(original);
        // Screenshots and icons of a given URL never change on Flathub: skip revalidation
        request.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::PreferCache);
        return QNetworkAccessManager::createRequest(op, request, data);
    }
};
}

QNetworkAccessManager *CachingNetworkFactory::create(QObject *parent)
{
    auto *nam = new CachingNetworkAccessManager(parent);
    auto *cache = new QNetworkDiskCache(nam);
    cache->setCacheDirectory(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/http"));
    cache->setMaximumCacheSize(300 * 1024 * 1024);
    nam->setCache(cache);
    nam->setTransferTimeout(30000);
    return nam;
}
