/**
 * D's Luck — .ds (D-Spec) parser.
 *
 * A .ds file is the engine's contract document: it says what a module IS,
 * which API family it serves, what it ADDS (functions, elements, events,
 * tools), and HOW IT MOVES (lifecycle, memory, thread rules).
 *
 * One format covers all three connection paths:
 *   kind: core  |  contract  |  plugin  |  extension
 *
 * v1 limits (deliberate, mobile-friendly): fixed buffers only,
 * 24 provides-entries and 12 lifecycle notes per spec.
 */
module dsluck.addons.dspec;

import core.stdc.stdio : FILE, fopen, fclose, fread, fseek, ftell, SEEK_END, SEEK_SET, snprintf;
import core.stdc.string : strlen, strcmp, memcpy;

import dsluck.memory : dslAlloc, dslFree;

public enum DsKind : int
{
    invalid   = 0,
    core      = 1,
    contract  = 2,   /// the "header" side: what a family expects
    plugin    = 3,   /// native library + spec
    extension = 4,   /// script package + spec
}

public enum DsCat : int
{
    none    = 0,
    fnDecl  = 1,
    element = 2,
    event   = 3,
    tool    = 4,
}

public enum DS_MAX_PROVIDES = 24;
public enum DS_MAX_NOTES    = 12;

// NOTE: D's .init for char is 0xFF, not 0 — every fixed char buffer here
// is explicitly zero-initialized with `= ""`, or nothing is a C string.

public struct DsProvide
{
    int cat;              /// DsCat
    char[48] name = "";   /// fn/element/event name, or tool id
    char[96] detail = ""; /// fn signature text / tool label
    int eventValue;       /// events only
}

public struct DsSpec
{
    bool ok;
    int  dspecVersion;
    int  kind;            /// DsKind
    char[48] name = "";
    char[12] versionStr = "";
    char[24] family = "";
    int  abi;             /// core ABI this module was built against
    char[48] library = "";/// plugins: base name ("renderer_null" -> librenderer_null.so)
    char[48] script = ""; /// extensions: entry script ("main.wren")
    char[24] implementsName = "";
    int  implementsVersion;
    DsProvide[DS_MAX_PROVIDES] provides;
    int providesLen;
    char[96][DS_MAX_NOTES] notes;   /// slots used strictly up to notesLen
    int notesLen;
}

// ---------------------------------------------------------------- errors
private __gshared char[256] g_lastError = "no error";

public const(char)* dsLastError() nothrow @nogc
{
    return g_lastError.ptr;
}

private void setError(uint line, const(char)* msg) nothrow @nogc
{
    snprintf(g_lastError.ptr, g_lastError.length, "line %u: %s", line, msg);
}

// ---------------------------------------------------------------- helpers
private size_t cstrlen(scope const(char)[] fixed) nothrow @nogc
{
    foreach (i, c; fixed)
        if (c == '\0')
            return i;
    return fixed.length;
}

private void copyStr(char[] dst, scope const(char)[] src) nothrow @nogc
{
    auto n = src.length < dst.length - 1 ? src.length : dst.length - 1;
    if (n > 0)
        memcpy(dst.ptr, src.ptr, n);
    dst[n] = '\0';
}

/// Slice view over a fixed char buffer (lifetime tied to the buffer).
public const(char)[] view(scope const(char)[] fixed) nothrow @nogc
{
    return fixed[0 .. cstrlen(fixed)];
}

// ---------------------------------------------------------------- lexer
private enum Tok : int
{
    eof = 0,
    lbrace = '{',
    rbrace = '}',
    colon = ':',
    eq = '=',
    at = '@',
    ident = 256,
    str = 257,
    num = 258,
}

private struct Lexer
{
    const(char)* s;
    uint line = 1;

    int tok;
    char[128] text;
    int numValue;

    bool next() nothrow @nogc
    {
        skipWs();
        char c = *s;
        if (c == '\0') { tok = Tok.eof; return true; }
        if (c == '{' || c == '}' || c == ':' || c == '=' || c == '@')
        {
            tok = cast(int) c;
            s++;
            return true;
        }
        if (isAlpha(c) || c == '_')
        {
            size_t n = 0;
            while (isAlphaNum(*s) || *s == '_')
            {
                if (n < text.length - 1)
                    text[n++] = *s;
                s++;
            }
            text[n] = '\0';
            tok = Tok.ident;
            return true;
        }
        if (isDigit(c))
        {
            int v = 0;
            while (isDigit(*s))
            {
                v = v * 10 + (*s - '0');
                s++;
            }
            numValue = v;
            tok = Tok.num;
            return true;
        }
        if (c == '"')
        {
            s++;
            size_t n = 0;
            while (*s != '"' && *s != '\0')
            {
                char ch = *s;
                if (ch == '\\' && (s[1] == '"' || s[1] == '\\'))
                {
                    ch = s[1];
                    s++;
                }
                if (ch == '\n')
                    line++;
                if (n < text.length - 1)
                    text[n++] = ch;
                s++;
            }
            if (*s == '\0')
            {
                setError(line, "unterminated string");
                return false;
            }
            s++;
            text[n] = '\0';
            tok = Tok.str;
            return true;
        }
        setError(line, "unexpected character");
        return false;
    }

    void skipWs() nothrow @nogc
    {
        for (;;)
        {
            char c = *s;
            if (c == ' ' || c == '\t' || c == '\r') { s++; continue; }
            if (c == '\n') { line++; s++; continue; }
            if (c == '/' && s[1] == '/')
            {
                while (*s != '\n' && *s != '\0')
                    s++;
                continue;
            }
            break;
        }
    }
}

private bool isAlpha(char c) nothrow @nogc { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }
private bool isDigit(char c) nothrow @nogc { return c >= '0' && c <= '9'; }
private bool isAlphaNum(char c) nothrow @nogc { return isAlpha(c) || isDigit(c); }

// ---------------------------------------------------------------- parser
private struct Parser
{
    Lexer lex;
    DsSpec* out_;

    bool fail(const(char)* msg) nothrow @nogc
    {
        setError(lex.line, msg);
        return false;
    }

    bool expect(int t, const(char)* what) nothrow @nogc
    {
        if (lex.tok != t)
            return fail(what);
        return lex.next();
    }

    bool identIs(const(char)* kw) nothrow @nogc
    {
        return lex.tok == Tok.ident && strcmp(lex.text.ptr, kw) == 0;
    }

    size_t textLen() nothrow @nogc
    {
        return cstrlen(lex.text);
    }

    bool run() nothrow @nogc
    {
        *out_ = DsSpec.init;
        if (!lex.next()) return false;      // prime the first token

        // header: dspec <int> { ... }
        if (!identIs("dspec"))
            return fail("expected 'dspec'");
        if (!lex.next()) return false;
        if (lex.tok != Tok.num)
            return fail("expected format version after 'dspec'");
        out_.dspecVersion = lex.numValue;
        if (!lex.next()) return false;
        if (out_.dspecVersion != 1)
            return fail("unsupported dspec version (want 1)");
        if (!expect(Tok.lbrace, "expected '{'"))
            return false;

        while (lex.tok != Tok.rbrace && lex.tok != Tok.eof)
        {
            if (lex.tok != Tok.ident)
                return fail("expected declaration");
            if (identIs("provides"))
            {
                if (!lex.next()) return false;
                if (!parseProvides()) return false;
            }
            else if (identIs("lifecycle"))
            {
                if (!lex.next()) return false;
                if (!parseLifecycle()) return false;
            }
            else
            {
                if (!parseKeyValue()) return false;
            }
        }
        if (!expect(Tok.rbrace, "expected '}'"))
            return false;
        return semanticCheck();
    }

    bool parseKeyValue() nothrow @nogc
    {
        char[24] key;
        copyStr(key[], lex.text[0 .. textLen()]);
        if (!lex.next()) return false;
        if (lex.tok != Tok.colon)
            return fail("expected ':' after key");
        if (!lex.next()) return false;

        if (strcmp(key.ptr, "kind") == 0)
        {
            if (lex.tok != Tok.ident)
                return fail("kind must be core|contract|plugin|extension");
            out_.kind = kindFromName(lex.text.ptr);
            if (out_.kind == DsKind.invalid)
                return fail("unknown kind");
            return lex.next();
        }
        if (strcmp(key.ptr, "name") == 0)
            return readString("name needs a string", out_.name[]);
        if (strcmp(key.ptr, "version") == 0)
            return readString("version needs a string", out_.versionStr[]);
        if (strcmp(key.ptr, "family") == 0)
            return readIdentOrStr("family value", out_.family[]);
        if (strcmp(key.ptr, "library") == 0)
            return readIdentOrStr("library value", out_.library[]);
        if (strcmp(key.ptr, "script") == 0)
            return readString("script needs a string", out_.script[]);
        if (strcmp(key.ptr, "abi") == 0)
        {
            if (lex.tok != Tok.num)
                return fail("abi must be a number");
            out_.abi = lex.numValue;
            return lex.next();
        }
        if (strcmp(key.ptr, "implements") == 0)
        {
            if (lex.tok != Tok.ident)
                return fail("implements must name a family");
            copyStr(out_.implementsName[], lex.text[0 .. textLen()]);
            if (!lex.next()) return false;
            if (lex.tok == Tok.at)
            {
                if (!lex.next()) return false;
                if (lex.tok != Tok.num)
                    return fail("expected version after @");
                out_.implementsVersion = lex.numValue;
                return lex.next();
            }
            out_.implementsVersion = 1;
            return true;
        }
        return fail("unknown key");
    }

    bool readString(const(char)* err, char[] dst) nothrow @nogc
    {
        if (lex.tok != Tok.str)
            return fail(err);
        copyStr(dst, lex.text[0 .. textLen()]);
        return lex.next();
    }

    bool readIdentOrStr(const(char)* err, char[] dst) nothrow @nogc
    {
        if (lex.tok != Tok.str && lex.tok != Tok.ident)
            return fail(err);
        copyStr(dst, lex.text[0 .. textLen()]);
        return lex.next();
    }

    bool parseProvides() nothrow @nogc
    {
        if (lex.tok != Tok.lbrace)
            return fail("expected '{' after provides");
        if (!lex.next()) return false;

        while (lex.tok != Tok.rbrace && lex.tok != Tok.eof)
        {
            if (out_.providesLen >= DS_MAX_PROVIDES)
                return fail("too many provides entries (max 24)");

            DsProvide* p = &out_.provides[out_.providesLen];
            *p = DsProvide.init;

            if (identIs("fn"))
            {
                p.cat = DsCat.fnDecl;
                if (!lex.next()) return false;
                if (lex.tok != Tok.ident)
                    return fail("fn needs a name");
                copyStr(p.name[], lex.text[0 .. textLen()]);
                if (!lex.next()) return false;
                if (lex.tok != Tok.str)
                    return fail("fn needs a signature string");
                copyStr(p.detail[], lex.text[0 .. textLen()]);
                if (!lex.next()) return false;
            }
            else if (identIs("element"))
            {
                p.cat = DsCat.element;
                if (!lex.next()) return false;
                if (lex.tok != Tok.ident)
                    return fail("element needs a name");
                copyStr(p.name[], lex.text[0 .. textLen()]);
                if (!lex.next()) return false;
            }
            else if (identIs("event"))
            {
                p.cat = DsCat.event;
                if (!lex.next()) return false;
                if (lex.tok != Tok.ident)
                    return fail("event needs a name");
                copyStr(p.name[], lex.text[0 .. textLen()]);
                if (!lex.next()) return false;
                if (lex.tok != Tok.eq)
                    return fail("event needs '= <int>'");
                if (!lex.next()) return false;
                if (lex.tok != Tok.num)
                    return fail("event value must be an int");
                p.eventValue = lex.numValue;
                if (!lex.next()) return false;
            }
            else if (identIs("tool"))
            {
                p.cat = DsCat.tool;
                if (!lex.next()) return false;
                if (lex.tok != Tok.str)
                    return fail("tool needs a label string");
                copyStr(p.detail[], lex.text[0 .. textLen()]);
                if (!lex.next()) return false;
            }
            else
            {
                return fail("provides entries are fn|element|event|tool");
            }
            out_.providesLen++;
        }
        return expect(Tok.rbrace, "expected '}'");
    }

    bool parseLifecycle() nothrow @nogc
    {
        if (lex.tok != Tok.lbrace)
            return fail("expected '{' after lifecycle");
        if (!lex.next()) return false;

        while (lex.tok != Tok.rbrace && lex.tok != Tok.eof)
        {
            if (out_.notesLen >= DS_MAX_NOTES)
                return fail("too many lifecycle notes (max 12)");
            if (lex.tok != Tok.ident)
                return fail("lifecycle note needs a key");

            char[24] key;
            copyStr(key[], lex.text[0 .. textLen()]);
            if (!lex.next()) return false;
            if (lex.tok != Tok.colon)
                return fail("expected ':' in lifecycle note");
            if (!lex.next()) return false;
            if (lex.tok != Tok.str)
                return fail("lifecycle note needs a string");

            char[96] line = void;
            auto klen = cstrlen(key);
            auto vlen = textLen();
            if (vlen > lex.text.length)
                vlen = lex.text.length;
            size_t total = klen + 2 + vlen;
            if (total > line.length - 1)
            {
                total = line.length - 1;
                vlen = total - (klen + 2);
            }
            memcpy(line.ptr, key.ptr, klen);
            line[klen] = ':';
            line[klen + 1] = ' ';
            if (vlen > 0)
                memcpy(line.ptr + klen + 2, lex.text.ptr, vlen);
            line[total] = '\0';

            copyStr(out_.notes[out_.notesLen][], line[0 .. cstrlen(line)]);
            out_.notesLen++;
            if (!lex.next()) return false;
        }
        return expect(Tok.rbrace, "expected '}'");
    }

    bool semanticCheck() nothrow @nogc
    {
        if (cstrlen(out_.name) == 0)
            return fail("spec needs a name");
        switch (out_.kind)
        {
            case DsKind.core:
            case DsKind.contract:
                break;
            case DsKind.plugin:
                if (cstrlen(out_.library) == 0)
                    return fail("plugin needs library: <base name>");
                if (cstrlen(out_.implementsName) == 0)
                    return fail("plugin needs implements: <family>");
                if (cstrlen(out_.family) == 0)
                    copyStr(out_.family[], out_.implementsName[0 .. cstrlen(out_.implementsName)]);
                break;
            case DsKind.extension:
                if (cstrlen(out_.script) == 0)
                    return fail("extension needs script: \"<file>\"");
                break;
            default:
                return fail("spec needs kind: core|contract|plugin|extension");
        }
        if (out_.abi < 0)
            return fail("abi must be >= 0");
        out_.ok = true;
        return true;
    }
}

private int kindFromName(const(char)* s) nothrow @nogc
{
    if (strcmp(s, "core") == 0)      return DsKind.core;
    if (strcmp(s, "contract") == 0)  return DsKind.contract;
    if (strcmp(s, "plugin") == 0)    return DsKind.plugin;
    if (strcmp(s, "extension") == 0) return DsKind.extension;
    return DsKind.invalid;
}

// ---------------------------------------------------------------- public
public bool dsParseFile(const(char)* path, DsSpec* out_) nothrow @nogc
{
    auto f = fopen(path, "rb");
    if (f is null)
    {
        setError(0, "cannot open file");
        return false;
    }
    scope (exit) fclose(f);

    fseek(f, 0, SEEK_END);
    auto size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size <= 0)
    {
        setError(0, "empty spec file");
        return false;
    }

    auto buf = cast(char*) dslAlloc(cast(size_t) size + 1, "dspec");
    if (buf is null)
    {
        setError(0, "out of memory");
        return false;
    }
    scope (exit) dslFree(buf, cast(size_t) size + 1);

    auto bytesRead = fread(buf, 1, cast(size_t) size, f);
    buf[bytesRead] = '\0';

    Parser p;
    p.out_ = out_;
    p.lex.s = buf;
    return p.run();
}
