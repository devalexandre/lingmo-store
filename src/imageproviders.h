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

#include <QQmlNetworkAccessManagerFactory>
#include <QQuickImageProvider>

// image://appicon/<percent-encoded path>: AppStream icons in formats Qt may not
// read on its own (Arch ships them as JPEG XL), decoded with libjxl
class AppIconProvider : public QQuickImageProvider
{
public:
    AppIconProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
};

// Screenshots and remote icons are kept in a disk cache, so pages open instantly the
// second time and still show pictures offline
class CachingNetworkFactory : public QQmlNetworkAccessManagerFactory
{
public:
    QNetworkAccessManager *create(QObject *parent) override;
};
