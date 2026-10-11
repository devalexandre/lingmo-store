# Lingmo Store

The app store of the ArchLingmo desktop ("Loja de aplicativos"): one place to find,
install and remove applications without a terminal. Flathub first, the Arch
repositories second, the AUR not at all.

- **Catalog** — AppStream metadata read with libappstream: the Arch repositories'
  data (`archlinux-appstream-data`, `/usr/share/swcatalog`) and Flathub's
  (`/var/lib/flatpak/appstream`, downloaded by the store when missing or older than a
  day). An app found in both is shown once, with both sources.
- **Home** — rotating banner, popular apps and categories. The curated lists live in
  [`data/featured.json`](data/featured.json).
- **Search** — instant, accent-insensitive, understands everyday Portuguese words
  ("editor de fotos", "planilha", "jogos").
- **App page** — screenshots, description, developer (with Flathub's *verified*
  badge), license, size and version, and the choice between *Versão do Arch* and
  *Flathub* when both exist. The Arch package is recommended when it's in the official
  repositories and not older than Flathub's; otherwise Flathub.
- **Permissions before installing** — for Flathub apps, the sandbox permissions of the
  app's metadata (`flatpak info --show-metadata` when installed, `flatpak remote-info
  --show-metadata flathub <ref>` otherwise, Flathub's `/api/v2/summary/<id>` when the
  remote isn't set up) in plain words with a risk level: running commands outside the
  sandbox (`--talk-name=org.freedesktop.Flatpak`), the whole D-Bus session, all files,
  camera and devices, microphone, SSH keys, saved passwords, network…; a summary sits
  under the Install button. Arch packages say clearly that they run without a sandbox
  and which repository (official or not) they come from. Cached for three days.
- **Ratings and reviews** — from [ODRS](https://odrs.gnome.org), the service GNOME
  Software and KDE Discover use: average and count on every app card and page (one
  ~2 MB download a day, matched by AppStream id, `.desktop` id, Flathub id and the ids
  an app provides), the newest reviews on the app page (in the user's language, else
  English; cached for six hours) and, for installed apps, *Escrever avaliação*. The
  reviewer is identified, like in GNOME Software, by a salted SHA-1 of the login and
  `/etc/machine-id`. Offline, the last answers are shown; nothing waits on the network.
- **Installed** — what was installed from the store, with Open and Remove. Updates are
  left to Lingmo Updater (linked from the sidebar).
- **Games** — *Preparar para jogos* enables `[multilib]`, installs Steam, the 32-bit
  Vulkan driver for the GPUs `lspci` reports, GameMode and optionally MangoHud, in one
  transaction, and adds the user to the `gamemode` group (GameMode's polkit rule needs
  it); *Proton para todos os jogos* sets Proton Experimental for "all other titles"
  (`CompatToolMapping` → `0` in Steam's `config/config.vdf`, only while Steam is closed,
  with a backup); *Modo jogo* explains `gamemoderun %command%`; *Seu jogo funciona?*
  combines ProtonDB and Are We Anti-Cheat Yet into a verdict, and popular online games
  whose anti-cheat blocks Linux (`antiCheatWatch` in `featured.json`, checked against
  Are We Anti-Cheat Yet) are listed as a warning.
- **Native games** — classic games rebuilt as native programs by decompilation and
  recompilation projects (`nativeGames` in `featured.json`). The store never ships or
  links to game data: entries that need the user's own copy say so and explain how.

## How software is installed

- **Flathub apps**: libflatpak transactions on the **system** installation. The apps
  are shared by every user and appear in the launcher, and flatpak's own polkit rules
  let administrators (group `wheel`) install without typing a password. The `flathub`
  remote is added (`flatpak remote-add --system`, with the `.flatpakrepo` embedded in
  the binary) only after the user agrees. `LINGMO_STORE_FLATPAK_INSTALLATION=user`
  switches to the per-user installation.
- **Arch packages**: `pkexec /usr/lib/lingmo-store/lingmo-store-helper`, a small
  shell script and the only thing that runs as root (polkit action
  `com.lingmo.store.manage-packages`, `auth_admin_keep`):

  | command                  | runs                                                |
  |--------------------------|-----------------------------------------------------|
  | `install <pkg>…`         | `pacman -S --needed --noconfirm`                    |
  | `remove <pkg>…`          | `pacman -Rns --noconfirm` (refuses essential ones)  |
  | `enable-multilib`        | uncomments `[multilib]` in `/etc/pacman.conf` after a timestamped backup, validated with `pacman-conf` |
  | `prepare-gaming <pkg>…`  | `enable-multilib` if needed, then `pacman -Syu --needed --noconfirm` (a sync plus install in one transaction, never a partial upgrade); with `gamemode`, `gpasswd -a <user of PKEXEC_UID> gamemode` |

  pacman's output is turned into a progress bar and, on failure, into a sentence
  ("Sem internet…", "Outro programa está instalando, tente de novo em instantes", …).

## Command line and D-Bus

```
lingmo-store                          open the store
lingmo-store --app <id>               open an app's page
lingmo-store --search "<text>"        open search results
lingmo-store --games                  open the games page
lingmo-store appstream://<id>         same as --app
lingmo-store <file>.flatpakref        page of the app in the flatpakref
```

`<id>` may be an AppStream id (with or without `.desktop`, any case), a Flathub id,
a flatpak ref (`app/<id>/<arch>/<branch>`) or an Arch package name
(`--app com.google.Chrome`, `--app org.libreoffice.LibreOffice`, `--app firefox`).
Unknown ids fall back to a search.

Only one instance runs per session. It owns `com.lingmo.Store` on the session bus and
exports `/Store` with interface `com.lingmo.Store`:

| method                        | effect                                         |
|-------------------------------|------------------------------------------------|
| `activate(as arguments)`      | same as the command line (a second instance calls this with its own arguments) |
| `openApp(s id)`               | `--app id`                                     |
| `search(s text)`              | `--search text`                                |
| `openGames()`                 | `--games`                                      |
| `show()`                      | raise the window                               |

## Build

```sh
cmake -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr
ninja -C build
DESTDIR=/tmp/stage ninja -C build install
```

Build dependencies: `qt6-base qt6-declarative qt6-tools qt6-5compat kwindowsystem
appstream flatpak pacman libjxl cmake ninja` (libflatpak, libalpm and libjxl are
optional at build time; without them Flathub, Arch packages or Arch's JPEG XL icons
are unavailable).

Runtime: `lingmoui`, `appstream`, `archlinux-appstream-data`, `flatpak`, `pacman`,
`polkit` with an agent, `pciutils` (GPU detection); optional `kimageformats`.

## Testing without touching the system

`LINGMO_STORE_FAKE` makes every change a simulation: the helper runs from the
resources in its fake mode (never as root) and flatpak transactions are simulated.
Values: `1`/`ok`, `fail`, `offline`, `lock`, `cancel`.

| variable                               | effect                                          |
|----------------------------------------|-------------------------------------------------|
| `LINGMO_STORE_PACMAN_CONF=<copy>`      | fake mode: read and edit this copy of pacman.conf |
| `LINGMO_STORE_FLATPAK_INSTALLATION=user` | use `$XDG_DATA_HOME/flatpak`                  |
| `LINGMO_STORE_FAKE_GPU=nvidia\|amd\|intel` | skip lspci                                  |
| `LINGMO_STORE_FAKE_NATIVE=soh,zelda3`  | fake mode: pretend `[archlingmo]` has these native games |
| `LINGMO_STORE_FAKE_DELAY`              | seconds between fake pacman steps               |
| `LINGMO_STORE_ODRS_URL=<url>`          | another ODRS server (e.g. a local stub); in fake mode without it, submitting a review is only logged |
| `LINGMO_STORE_FLATHUB_API=<url>`       | another Flathub API (permissions fallback)      |
| `LINGMO_STORE_STEAM_DIR=<dir>`         | the Steam folder whose `config/config.vdf` is edited |
| `LINGMO_STORE_FAKE_STEAM_RUNNING=1\|0` | skip looking for a running Steam                |

```sh
cp /etc/pacman.conf /tmp/pacman.conf
LINGMO_STORE_FAKE=1 LINGMO_STORE_PACMAN_CONF=/tmp/pacman.conf lingmo-store --games
```

## License

GPL-3.0-or-later.
