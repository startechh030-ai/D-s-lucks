/**
 * D's Luck — null renderer plugin.
 *
 * The quietest possible renderer: correct symbols, zero pixels. It exists
 * to prove the seam end-to-end (scan -> spec -> dlopen -> contract check
 * -> probe) before Filament arrives. Swapping it for the Filament shim is
 * a file-level operation, not a code operation.
 */
module null_renderer;

private __gshared int g_inits;
private __gshared int g_submits;

extern (C) @nogc nothrow:

/// Family contract: renderer v1
int  dsl_renderer_init()            { g_inits++; return 0; }   /// 0 = success
void dsl_renderer_resize(int w, int h) { }
void dsl_renderer_submit(double dt) { g_submits++; }
void dsl_renderer_shutdown()        { }

/// Optional health probe: dsl_<family>_probe()
uint dsl_renderer_probe()           { return 0x0000_D51C; }    /// "DSLC"
