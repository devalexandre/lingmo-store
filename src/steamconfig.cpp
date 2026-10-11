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

#include "steamconfig.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QList>
#include <QStringList>

namespace {

struct Token {
    enum Type { String, Open, Close, End } type = End;
    QString text;
    int start = 0;
    int end = 0; // one past the last character
};

class Lexer
{
public:
    explicit Lexer(const QString &text) : m_text(text) {}

    Token next()
    {
        for (;;) {
            while (m_pos < m_text.size() && m_text.at(m_pos).isSpace())
                ++m_pos;
            if (m_text.mid(m_pos, 2) == QLatin1String("//")) {
                while (m_pos < m_text.size() && m_text.at(m_pos) != QLatin1Char('\n'))
                    ++m_pos;
                continue;
            }
            break;
        }
        Token t;
        t.start = m_pos;
        if (m_pos >= m_text.size()) {
            t.type = Token::End;
            t.end = m_pos;
            return t;
        }
        const QChar c = m_text.at(m_pos);
        if (c == QLatin1Char('{') || c == QLatin1Char('}')) {
            t.type = c == QLatin1Char('{') ? Token::Open : Token::Close;
            t.end = ++m_pos;
            return t;
        }
        t.type = Token::String;
        if (c == QLatin1Char('"')) {
            ++m_pos;
            while (m_pos < m_text.size() && m_text.at(m_pos) != QLatin1Char('"')) {
                if (m_text.at(m_pos) == QLatin1Char('\\') && m_pos + 1 < m_text.size()) {
                    t.text.append(m_text.at(m_pos + 1));
                    m_pos += 2;
                    continue;
                }
                t.text.append(m_text.at(m_pos++));
            }
            if (m_pos >= m_text.size()) {
                m_error = true;
                t.type = Token::End;
            } else {
                ++m_pos;
            }
        } else {
            while (m_pos < m_text.size() && !m_text.at(m_pos).isSpace() && m_text.at(m_pos) != QLatin1Char('{')
                   && m_text.at(m_pos) != QLatin1Char('}') && m_text.at(m_pos) != QLatin1Char('"'))
                t.text.append(m_text.at(m_pos++));
        }
        t.end = m_pos;
        return t;
    }
    bool error() const { return m_error; }

private:
    const QString &m_text;
    int m_pos = 0;
    bool m_error = false;
};

struct Node {
    QString key;
    QString value;
    bool block = false;
    int start = 0;  // where the key starts
    int open = -1;  // position of '{'
    int close = -1; // position of '}'
    int end = 0;    // one past the node
    QList<Node> children;
};

// Parses key/value pairs until '}' (nested) or the end (top level)
bool parseNodes(Lexer &lexer, QList<Node> *nodes, bool nested, Token *closing)
{
    for (;;) {
        Token key = lexer.next();
        if (key.type == Token::End)
            return !nested && !lexer.error();
        if (key.type == Token::Close) {
            if (!nested)
                return false;
            *closing = key;
            return true;
        }
        if (key.type != Token::String)
            return false;
        Token value = lexer.next();
        // Platform conditionals ("[$WIN32]") after a value or key are skipped
        while (value.type == Token::String && value.text.startsWith(QLatin1Char('[')) && value.text.endsWith(QLatin1Char(']')))
            value = lexer.next();
        Node node;
        node.key = key.text;
        node.start = key.start;
        if (value.type == Token::Open) {
            node.block = true;
            node.open = value.start;
            Token close;
            if (!parseNodes(lexer, &node.children, true, &close))
                return false;
            node.close = close.start;
            node.end = close.end;
        } else if (value.type == Token::String) {
            node.value = value.text;
            node.end = value.end;
        } else {
            return false;
        }
        nodes->append(node);
    }
}

const Node *child(const QList<Node> &nodes, const QString &key)
{
    for (const Node &n : nodes) {
        if (n.key.compare(key, Qt::CaseInsensitive) == 0)
            return &n;
    }
    return nullptr;
}

// InstallConfigStore/Software/Valve/Steam
const Node *steamNode(const QList<Node> &top)
{
    const Node *n = child(top, QStringLiteral("InstallConfigStore"));
    for (const char *k : {"Software", "Valve", "Steam"}) {
        if (!n || !n->block)
            return nullptr;
        n = child(n->children, QLatin1String(k));
    }
    return n && n->block ? n : nullptr;
}

bool parse(const QString &vdf, QList<Node> *top)
{
    Lexer lexer(vdf);
    Token unused;
    return parseNodes(lexer, top, false, &unused);
}

QString quoted(const QString &s)
{
    QString out = s;
    out.replace(QLatin1Char('\\'), QStringLiteral("\\\\"));
    out.replace(QLatin1Char('"'), QStringLiteral("\\\""));
    return QLatin1Char('"') + out + QLatin1Char('"');
}

} // namespace

namespace SteamConfig {

static QStringList candidates()
{
    const QString override = qEnvironmentVariable("LINGMO_STORE_STEAM_DIR");
    if (!override.isEmpty())
        return {override};
    const QString home = QDir::homePath();
    return {
        home + QStringLiteral("/.steam/steam"),
        home + QStringLiteral("/.local/share/Steam"),
        home + QStringLiteral("/.var/app/com.valvesoftware.Steam/.local/share/Steam"),
    };
}

bool isInstalledDir(const QString &dir)
{
    return QFileInfo::exists(dir + QStringLiteral("/config/config.vdf"));
}

QString steamDir()
{
    const QStringList dirs = candidates();
    for (const QString &dir : dirs) {
        if (isInstalledDir(dir))
            return dir;
    }
    return dirs.first();
}

QString configPath()
{
    return steamDir() + QStringLiteral("/config/config.vdf");
}

bool steamRunning()
{
    const QString fake = qEnvironmentVariable("LINGMO_STORE_FAKE_STEAM_RUNNING");
    if (!fake.isEmpty())
        return fake == QLatin1String("1");
    const QStringList pids = QDir(QStringLiteral("/proc")).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &pid : pids) {
        if (!pid.at(0).isDigit())
            continue;
        QFile comm(QStringLiteral("/proc/%1/comm").arg(pid));
        if (!comm.open(QIODevice::ReadOnly))
            continue;
        const QByteArray name = comm.readAll().trimmed();
        if (name == "steam" || name == "steamwebhelper")
            return true;
    }
    return false;
}

QString defaultTool(const QString &vdf, bool *ok)
{
    QList<Node> top;
    const bool parsed = parse(vdf, &top);
    const Node *steam = parsed ? steamNode(top) : nullptr;
    if (ok)
        *ok = steam != nullptr;
    if (!steam)
        return {};
    const Node *mapping = child(steam->children, QStringLiteral("CompatToolMapping"));
    const Node *zero = mapping && mapping->block ? child(mapping->children, QStringLiteral("0")) : nullptr;
    const Node *name = zero && zero->block ? child(zero->children, QStringLiteral("name")) : nullptr;
    return name && !name->block ? name->value : QString();
}

QString withDefaultTool(const QString &vdf, const QString &tool, QString *error)
{
    QList<Node> top;
    if (!parse(vdf, &top)) {
        *error = QStringLiteral("config.vdf could not be read");
        return {};
    }
    const Node *steam = steamNode(top);
    if (!steam) {
        *error = QStringLiteral("config.vdf has no InstallConfigStore/Software/Valve/Steam section");
        return {};
    }
    const QString entry = QStringLiteral("\"0\"\n{\n%1\t\t%2\n\"config\"\t\t\"\"\n\"priority\"\t\t\"75\"\n}")
                              .arg(quoted(QStringLiteral("name")), quoted(tool));
    QString out = vdf;
    const Node *mapping = child(steam->children, QStringLiteral("CompatToolMapping"));
    if (mapping && mapping->block) {
        if (const Node *zero = child(mapping->children, QStringLiteral("0")))
            out.replace(zero->start, zero->end - zero->start, entry);
        else
            out.insert(mapping->open + 1, QLatin1Char('\n') + entry + QLatin1Char('\n'));
    } else if (mapping) {
        // "CompatToolMapping" "" – a value where a block belongs
        out.replace(mapping->start, mapping->end - mapping->start,
                    QStringLiteral("\"CompatToolMapping\"\n{\n") + entry + QStringLiteral("\n}"));
    } else {
        out.insert(steam->open + 1, QStringLiteral("\n\"CompatToolMapping\"\n{\n") + entry + QStringLiteral("\n}\n"));
    }
    bool ok = false;
    if (defaultTool(out, &ok) != tool || !ok) {
        *error = QStringLiteral("the edited config.vdf did not check out");
        return {};
    }
    return out;
}

} // namespace SteamConfig
