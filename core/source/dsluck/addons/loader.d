/**
 * D's Luck — addon loader.
 *
 * Scans a directory for .ds specs, validates them, and loads what they
 * describe. Kinds:
 *   core/contract -> registered (metadata & family contracts)
 *   extension     -> registered (script wiring arrives with Wren, M6)
 *   plugin        -> library existence check -> dlopen -> family-contract
 *                    symbol check -> optional dsl_<family>_probe() call.
 *
 * Everything mechanical about "replaceability" lives in this one file.
 */
module dsluck.addons.loader;

import core.stdc.stdio : FILE, fopen, fclose, snprintf;
import core.stdc.string : strcmp, memcpy, strlen;

import dsluck.addons.dspec;
import dsluck.addons.families;
import dsluck.core.events : EventBus, DslEvent;
import dsluck.memory : dslAlloc, dslFree;

public enum AddonState : int
{
    invalid         = 0,
    registered      = 1,   /// spec valid, no native load needed (contract/extension)
    loaded          = 2,   /// native lib opened, contract symbols verified
    missingLibrary  = 3,   /// spec valid, but the .so isn't there (e.g. Box3D today)
    loadFailed      = 4,   /// dlopen failed or a required symbol is missing
}

public enum MAX_ADDONS = 32;

public struct AddonEntry
{
    void* lib;
    int   state;          /// AddonState
    int   probeValue;     /// result of dsl_<family>_probe(), when present
    int   kind;           /// DsKind
    int   abi;
    int   providesCount;
    char[48]  name = "";
    char[24]  family = "";
    char[12]  versionStr = "";
    char[48]  library = "";  /// base name, plugins only
    char[160] dir = "";      /// directory containing the spec
    char[48]  dsFile = "";   /// spec file name inside dir
}

public struct AddonRegistry
{
    int count;
    AddonEntry[MAX_ADDONS] entries;
}

// ---------------------------------------------------------------- platform
private bool fileExists(const(char)* path) nothrow @nogc
{
    auto f = fopen(path, "rb");
    if (f is null)
        return false;
    fclose(f);
    return true;
}

version (Posix)
{
    import core.sys.posix.dlfcn : dlopen, dlclose, dlsym, dlerror, RTLD_NOW, RTLD_LOCAL;
    import core.sys.posix.dirent : opendir, readdir, closedir, dirent, DT_DIR;

    private void* openLib(const(char)* path) nothrow @nogc { return dlopen(path, RTLD_NOW | RTLD_LOCAL); }
    private void* findSym(void* h, const(char)* s) nothrow @nogc { return h is null ? null : dlsym(h, s); }
    private void  closeLib(void* h) nothrow @nogc { if (h !is null) dlclose(h); }
    private enum LIB_PREFIX = "lib";
    private enum LIB_SUFFIX = ".so";
    private enum SUPPORTED  = true;
}
else version (Windows)
{
    // Windows plugin loading lands with the desktop bridge (LoadLibrary).
    // The registry, parsing and validation all work today; native load
    // reports unsupported instead of crashing.
    private void* openLib(const(char)*) nothrow @nogc { return null; }
    private void* findSym(void*, const(char)*) nothrow @nogc { return null; }
    private void  closeLib(void*) nothrow @nogc { }
    private enum LIB_PREFIX = "";
    private enum LIB_SUFFIX = ".dll";
    private enum SUPPORTED  = false;
}
else
{
    private void* openLib(const(char)*) nothrow @nogc { return null; }
    private void* findSym(void*, const(char)*) nothrow @nogc { return null; }
    private void  closeLib(void*) nothrow @nogc { }
    private enum LIB_PREFIX = "lib";
    private enum LIB_SUFFIX = ".so";
    private enum SUPPORTED  = false;
}

// ---------------------------------------------------------------- helpers
private void setLoadError(const(char)* msg) nothrow @nogc
{
    snprintf(g_loadError.ptr, g_loadError.length, "%s", msg);
}
private __gshared char[256] g_loadError = "no error";

public const(char)* dsLoaderLastError() nothrow @nogc
{
    return g_loadError.ptr;
}

private bool endsWith(const(char)[] s, const(char)[] suffix) nothrow @nogc
{
    if (s.length < suffix.length)
        return false;
    foreach (i, c; suffix)
        if (s[$ - suffix.length + i] != c)
            return false;
    return true;
}

private void pushEvent(EventBus* events, int code) nothrow @nogc
{
    if (events !is null)
        events.push(code);
}

// ---------------------------------------------------------------- core logic
private void processSpec(AddonRegistry* reg, EventBus* events,
                         const(char)* dirPath, const(char)* fileName,
                         uint maxAbi) nothrow @nogc
{
    if (reg.count >= MAX_ADDONS)
        return;

    char[512] full;
    snprintf(full.ptr, full.length, "%s/%s", dirPath, fileName);

    DsSpec spec;
    if (!dsParseFile(full.ptr, &spec))
        return; // parser already recorded why

    AddonEntry* e = &reg.entries[reg.count];
    *e = AddonEntry.init;
    e.kind = spec.kind;
    e.abi = spec.abi;
    e.providesCount = spec.providesLen;
    copyC(e.name[], spec.name[]);
    copyC(e.family[], spec.family[]);
    copyC(e.versionStr[], spec.versionStr[]);
    copyC(e.library[], spec.library[]);
    copyC(e.dir[], dirPath[0 .. strlen(dirPath)]);
    copyC(e.dsFile[], fileName[0 .. strlen(fileName)]);

    if (spec.abi > maxAbi)
    {
        e.state = AddonState.loadFailed;
        setLoadError("spec targets a newer core ABI than this engine");
        reg.count++;
        pushEvent(events, DslEvent.addonFailed);
        return;
    }

    final switch (spec.kind)
    {
        case DsKind.core:
        case DsKind.contract:
        case DsKind.extension:
            e.state = AddonState.registered;
            reg.count++;
            break;

        case DsKind.plugin:
            resolvePlugin(reg, events, e, &spec);
            reg.count++;
            break;
    }
}

private void resolvePlugin(AddonRegistry* reg, EventBus* events,
                           AddonEntry* e, DsSpec* spec) nothrow @nogc
{
    char[512] libPath;
    snprintf(libPath.ptr, libPath.length, "%s/%s%.*s%s",
             e.dir.ptr, LIB_PREFIX.ptr,
             cast(int) strlen(spec.library.ptr), spec.library.ptr,
             LIB_SUFFIX.ptr);

    if (!fileExists(libPath.ptr))
    {
        // Not an error — spec is valid, library simply isn't built/shipped
        // yet (physics3d-box3d lives exactly here until its milestone).
        e.state = AddonState.missingLibrary;
        return;
    }

    if (!SUPPORTED)
    {
        e.state = AddonState.loadFailed;
        setLoadError("native plugin loading not yet supported on this platform");
        pushEvent(events, DslEvent.addonFailed);
        return;
    }

    e.lib = openLib(libPath.ptr);
    if (e.lib is null)
    {
        e.state = AddonState.loadFailed;
        setLoadError("dlopen failed for plugin");
        pushEvent(events, DslEvent.addonFailed);
        return;
    }

    // Family-contract symbol check: registry contracts first (by .ds),
    // then the built-in table.
    if (!checkContract(reg, e, spec))
    {
        closeLib(e.lib);
        e.lib = null;
        e.state = AddonState.loadFailed;
        pushEvent(events, DslEvent.addonFailed);
        return;
    }

    // Optional health probe: dsl_<family>_probe()
    char[96] probeName;
    snprintf(probeName.ptr, probeName.length, "dsl_%.*s_probe",
             cast(int) strlen(e.family.ptr), e.family.ptr);
    alias ProbeFn = extern (C) uint function() nothrow @nogc;
    auto probe = cast(ProbeFn) findSym(e.lib, probeName.ptr);
    if (probe !is null)
        e.probeValue = probe();

    e.state = AddonState.loaded;
    pushEvent(events, DslEvent.addonLoaded);
}

private bool checkContract(AddonRegistry* reg, AddonEntry* e, DsSpec* spec) nothrow @nogc
{
    // 1) a registered contract spec for this family?
    foreach (i; 0 .. reg.count)
    {
        AddonEntry* c = &reg.entries[i];
        if (c.kind == DsKind.contract && strcmp(c.family.ptr, e.family.ptr) == 0)
        {
            char[512] cpath;
            snprintf(cpath.ptr, cpath.length, "%s/%s", c.dir.ptr, c.dsFile.ptr);
            DsSpec cspec;
            if (!dsParseFile(cpath.ptr, &cspec))
                return enforceSymbols(e, spec);
            return checkSymbolList(e, &cspec);
        }
    }
    // 2) built-in contract table
    return enforceSymbols(e, spec);
}

private bool enforceSymbols(AddonEntry* e, DsSpec* spec) nothrow @nogc
{
    auto contract = findContract(spec.family[0 .. cstrlenOf(spec.family)]);
    if (contract is null)
        return true; // custom family — v1: spec-only validation

    foreach (sref; contract.requiredSymbols)
    {
        char[96] sym;
        symFrom(sym, sref);
        if (findSym(e.lib, sym.ptr) is null)
        {
            setLoadError("plugin is missing a required family symbol");
            return false;
        }
    }
    return true;
}

private bool checkSymbolList(AddonEntry* e, DsSpec* contractSpec) nothrow @nogc
{
    foreach (i; 0 .. contractSpec.providesLen)
    {
        if (contractSpec.provides[i].cat != DsCat.fnDecl)
            continue;
        if (findSym(e.lib, contractSpec.provides[i].name.ptr) is null)
        {
            setLoadError("plugin is missing a symbol from a .ds contract");
            return false;
        }
    }
    return true;
}

private void symFrom(ref char[96] dst, string s) nothrow @nogc
{
    auto n = s.length < dst.length - 1 ? s.length : dst.length - 1;
    if (n > 0)
        memcpy(dst.ptr, s.ptr, n);
    dst[n] = '\0';
}

private size_t cstrlenOf(scope const(char)[] fixed) nothrow @nogc
{
    foreach (i, c; fixed)
        if (c == '\0')
            return i;
    return fixed.length;
}

private void copyC(char[] dst, scope const(char)[] src) nothrow @nogc
{
    auto n = src.length < dst.length - 1 ? src.length : dst.length - 1;
    // trim at first NUL of source
    size_t m = 0;
    while (m < n && src[m] != '\0')
        m++;
    if (m > 0)
        memcpy(dst.ptr, src.ptr, m);
    dst[m] = '\0';
}

// ---------------------------------------------------------------- scanning
version (Posix)
private void scanDir(AddonRegistry* reg, EventBus* events,
                     const(char)* path, uint maxAbi, int depth) nothrow @nogc
{
    auto d = opendir(path);
    if (d is null)
        return;
    scope (exit) closedir(d);

    while (true)
    {
        auto ent = readdir(d);
        if (ent is null)
            break;
        auto name = ent.d_name.ptr;
        auto len = strlen(name);
        if (len == 0 || name[0] == '.')
            continue;

        if (endsWith(name[0 .. len], ".ds"))
        {
            processSpec(reg, events, path, name, maxAbi);
        }
        else if (ent.d_type == DT_DIR && depth == 0)
        {
            char[512] sub;
            snprintf(sub.ptr, sub.length, "%s/%s", path, name);
            scanDir(reg, events, sub.ptr, maxAbi, depth + 1);
        }
    }
}

/// Scan `dir` (subdirs included, one level) and fill a fresh registry.
/// Caller owns the registry (allocated with dslAlloc by core on demand).
public void dsScanAddons(AddonRegistry* reg, EventBus* events,
                         const(char)* dir, uint maxAbi) nothrow @nogc
{
    reg.count = 0;
    version (Posix)
    {
        scanDir(reg, events, dir, maxAbi, 0);
    }
    else
    {
        setLoadError("addon scanning not yet supported on this platform");
    }
}

/// Close any open plugin libraries.
public void dsUnloadAll(AddonRegistry* reg) nothrow @nogc
{
    if (reg is null)
        return;
    foreach (i; 0 .. reg.count)
    {
        if (reg.entries[i].lib !is null)
        {
            closeLib(reg.entries[i].lib);
            reg.entries[i].lib = null;
        }
    }
}
