/**
 * D's Luck — manual memory layer.
 *
 * No runtime GC anywhere in the core. Everything is malloc/free wrapped
 * with live counters so the Debug overlay (FPS / memory / logs) can show
 * real allocation truth per frame.
 *
 * Compiled in -betterC mode: no druntime, no exceptions, @nogc.
 */
module dsluck.memory;

import core.stdc.stdlib : malloc, calloc, free;

private __gshared ulong g_allocCount;
private __gshared ulong g_freeCount;
private __gshared ulong g_bytesLive;

extern (C) @nogc nothrow:

/// Raw allocation, tracked. Tag kept for future per-system breakdown.
void* dslAlloc(size_t size, const(char)* tag = null)
{
    if (size == 0)
        return null;
    auto p = malloc(size);
    if (p !is null)
    {
        g_allocCount++;
        g_bytesLive += size;
    }
    return p;
}

/// Free paired with dslAlloc. Size is required so byte accounting stays exact.
void dslFree(void* p, size_t size)
{
    if (p is null)
        return;
    g_freeCount++;
    if (g_bytesLive >= size)
        g_bytesLive -= size;
    free(p);
}

ulong dslAllocCount()  { return g_allocCount; }
ulong dslFreeCount()   { return g_freeCount; }
ulong dslBytesLive()   { return g_bytesLive; }
