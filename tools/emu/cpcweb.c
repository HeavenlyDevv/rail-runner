// Amstrad CPC 6128 (floooh/chips) compiled to WebAssembly for the Rail Runner page.
// No libc, no ROMs: the Rail Runner snapshots run with both ROMs paged out.
#define CHIPS_IMPL
#define CHIPS_ASSERT(c) ((void)0)
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <string.h>

void* memcpy(void* d, const void* s, size_t n) { uint8_t* a = d; const uint8_t* b = s; while (n--) *a++ = *b++; return d; }
void* memset(void* d, int c, size_t n) { uint8_t* a = d; while (n--) *a++ = (uint8_t)c; return d; }
void* memmove(void* d, const void* s, size_t n) { uint8_t* a = d; const uint8_t* b = s; if (a < b) { while (n--) *a++ = *b++; } else { a += n; b += n; while (n--) *--a = *--b; } return d; }
int memcmp(const void* x, const void* y, size_t n) { const uint8_t* a = x; const uint8_t* b = y; for (; n; n--, a++, b++) if (*a != *b) return *a - *b; return 0; }
size_t strlen(const char* s) { size_t n = 0; while (s[n]) n++; return n; }

#include "chips/chips_common.h"
#include "chips/z80.h"
#include "chips/ay38910.h"
#include "chips/i8255.h"
#include "chips/mc6845.h"
#include "chips/am40010.h"
#include "chips/upd765.h"
#include "chips/kbd.h"
#include "chips/mem.h"
#include "chips/clk.h"
#include "chips/fdd.h"
#include "chips/fdd_cpc.h"
#include "systems/cpc.h"

#define OUT_X 48
#define OUT_Y 16
#define OUT_W 672
#define OUT_H 216

static cpc_t cpc;
static uint8_t rom_zero[0x4000];
static uint8_t sna[70000];
static uint32_t rgba[OUT_W * OUT_H];

__attribute__((export_name("sna_buffer"))) uint8_t* sna_buffer(void) { return sna; }
__attribute__((export_name("out_w"))) int out_w(void) { return OUT_W; }
__attribute__((export_name("out_h"))) int out_h(void) { return OUT_H; }

__attribute__((export_name("start"))) int start(int len) {
    cpc_init(&cpc, &(cpc_desc_t){
        .type = CPC_TYPE_6128,
        .roms = { .cpc6128 = {
            .os = { .ptr = rom_zero, .size = sizeof rom_zero },
            .basic = { .ptr = rom_zero, .size = sizeof rom_zero },
            .amsdos = { .ptr = rom_zero, .size = sizeof rom_zero },
        } },
    });
    return cpc_quickload(&cpc, (chips_range_t){ .ptr = sna, .size = (size_t)len }, false) ? 1 : 0;
}

// Runs one PAL frame (20 ms of CPC time) and returns the picture as RGBA.
__attribute__((export_name("frame"))) uint32_t* frame(void) {
    cpc_exec(&cpc, 19968);
    chips_display_info_t di = cpc_display_info(&cpc);
    const uint8_t* fb = (const uint8_t*)di.frame.buffer.ptr;
    const uint32_t* pal = (const uint32_t*)di.palette.ptr;
    for (int y = 0; y < OUT_H; y++) {
        const uint8_t* src = fb + (y + OUT_Y) * AM40010_FRAMEBUFFER_WIDTH + OUT_X;
        uint32_t* dst = rgba + y * OUT_W;
        for (int x = 0; x < OUT_W; x++) dst[x] = pal[src[x]];
    }
    return rgba;
}

__attribute__((export_name("key"))) void key(int code, int down) {
    if (down) cpc_key_down(&cpc, code); else cpc_key_up(&cpc, code);
}
