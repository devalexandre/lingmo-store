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

#include <QString>

// Steam's own settings, read and changed in the user's config.vdf (Valve's
// KeyValues text format). Used to turn on "Steam Play for all other titles": the
// CompatToolMapping entry for app id 0.
namespace SteamConfig {

// The Steam folder that has config/config.vdf (native or Flatpak Steam), or the
// first candidate when Steam never ran. LINGMO_STORE_STEAM_DIR overrides it (tests).
QString steamDir();
QString configPath();
bool isInstalledDir(const QString &dir);
// Steam rewrites config.vdf on exit: editing it while Steam runs would be undone.
// LINGMO_STORE_FAKE_STEAM_RUNNING=1|0 overrides the check (tests).
bool steamRunning();

// The compatibility tool set for all titles ("proton_experimental"…), empty when
// none. *ok is false when the text isn't a config.vdf this code understands.
QString defaultTool(const QString &vdf, bool *ok = nullptr);
// The text with `tool` as the tool for all titles; empty with *error set on failure
QString withDefaultTool(const QString &vdf, const QString &tool, QString *error);

} // namespace SteamConfig
