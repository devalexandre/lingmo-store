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

#include <QCoreApplication>
#include <QString>

// Messages shared by the backends, written for people who never saw a terminal
namespace Errors {
inline QString offline()
{
    return QCoreApplication::translate("Errors", "No internet connection. Check your network and try again.");
}
inline QString busy()
{
    return QCoreApplication::translate("Errors", "Another program is installing software. Try again in a moment.");
}
inline QString authCancelled()
{
    return QCoreApplication::translate("Errors", "Authentication was cancelled. Nothing was changed.");
}
inline QString cancelled()
{
    return QCoreApplication::translate("Errors", "Cancelled. Nothing was changed.");
}
inline QString noSpace()
{
    return QCoreApplication::translate("Errors", "There is not enough free disk space.");
}
inline QString installFailed()
{
    return QCoreApplication::translate("Errors", "Could not install.");
}
inline QString removeFailed()
{
    return QCoreApplication::translate("Errors", "Could not remove.");
}
}
