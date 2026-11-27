// rrsim: headless Amstrad CPC 6128 runner for Rail Runner, built on floooh/chips.
//
//   rrsim -s game.sna -o outdir [-m mine.map] [-n frames] [-p sym,sym,..]
//         [-w sym[+off],..] [-k frame:d|u:keycode]... [-e every_n_frames]
//         [-f frame,frame,..] [-b] [-E entity_size] [-I key_hold_frames]
//
// Outputs in outdir:
//   trace.csv   tick,symbol  for every opcode fetch at a profiled symbol address
//   watch.csv   frame,sym=value,...  bytes sampled once per frame
//   f_NNNNN.ppm frames (768x272, CPC display area)
//   keys.csv    frame,key,down|up  (what the bot/script pressed)
#define CHIPS_IMPL
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
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
#include "cpc-roms.h"

#define MAX_SYMS 4096
static struct { char name[64]; uint16_t addr; } syms[MAX_SYMS];
static int num_syms;

static int sym_lookup(const char* name) {
    for (int i = 0; i < num_syms; i++) if (!strcmp(syms[i].name, name)) return syms[i].addr;
    return -1;
}

static void load_map(const char* path) {
    FILE* f = fopen(path, "r");
    if (!f) { perror(path); exit(1); }
    char line[512];
    while (fgets(line, sizeof line, f)) {
        unsigned v; char name[256];
        // sdld map lines look like: "     00003103  _main     cpct_keyboard"
        if (sscanf(line, " %8x %255s", &v, name) == 2 && strlen(name) < 64 && num_syms < MAX_SYMS) {
            if (v > 0xFFFF) continue;
            strcpy(syms[num_syms].name, name);
            syms[num_syms].addr = (uint16_t)v;
            num_syms++;
        }
    }
    fclose(f);
}

static cpc_t cpc;
static uint64_t tick_count;
static int16_t marker_of[65536];       // -1 = none, else index into marker names
static char marker_names[256][64];
static int num_markers;
static FILE* trace_f;
static bool prev_fetch;
static bool stopped = false;
static struct { uint16_t ret, sp; int m; uint64_t t; } pend[64]; static int npend; static FILE* calls_f;
static int dump_pc = -1; static int dump_pending = -1; static const char* dump_dir;
static void dump_ram(int fr);
static int watch_wr = -1; static uint16_t last_pc; static uint16_t ring[256]; static uint16_t ring_sp[256]; static int ring_i; static int dumped; static FILE* wr_f; static uint64_t prev_wr_pins;

static void debug_cb(void* ud, uint64_t pins) {
    (void)ud;
    tick_count++;
    const bool fetch = (pins & (Z80_M1|Z80_MREQ|Z80_RD)) == (Z80_M1|Z80_MREQ|Z80_RD);
    if (watch_wr >= 0 && (pins & (Z80_MREQ|Z80_WR)) == (Z80_MREQ|Z80_WR) && Z80_GET_ADDR(pins) == watch_wr
        && !((prev_wr_pins & (Z80_MREQ|Z80_WR)) == (Z80_MREQ|Z80_WR))) {
        if (wr_f) fprintf(wr_f, "%llu,pc=%04X,val=%02X,sp=%04X\n", (unsigned long long)tick_count, last_pc, Z80_GET_DATA(pins), cpc.cpu.sp);
        if (wr_f && !dumped && Z80_GET_DATA(pins) != 0) { dumped = 1; for (int k = 0; k < 200; k++) { int j = (ring_i - 200 + k) & 255; fprintf(wr_f, "  hist pc=%04X sp=%04X\n", ring[j], ring_sp[j]); } }
    }
    prev_wr_pins = pins;
    if (fetch && !prev_fetch) {
        last_pc = Z80_GET_ADDR(pins);
        ring[ring_i & 255] = last_pc; ring_sp[ring_i & 255] = cpc.cpu.sp; ring_i++;
        if (wr_f && !dumped && last_pc >= 0x40 && last_pc < 0x240) {
            dumped = 1; fprintf(wr_f, "ENTERED FONT AREA at tick %llu\n", (unsigned long long)tick_count);
            for (int k = 0; k < 250; k++) { int j = (ring_i - 250 + k) & 255; fprintf(wr_f, "  hist pc=%04X sp=%04X\n", ring[j], ring_sp[j]); }
        }
        uint16_t pc = Z80_GET_ADDR(pins);
        while (npend > 0 && pc == pend[npend-1].ret && cpc.cpu.sp == pend[npend-1].sp) {
            npend--;
            if (calls_f) fprintf(calls_f, "%s,%llu\n", marker_names[pend[npend].m], (unsigned long long)(tick_count - pend[npend].t));
        }
        if (dump_pending >= 0 && pc == dump_pc) { dump_ram(dump_pending); dump_pending = -1; }
        int m = marker_of[pc];
        if (m >= 0 && trace_f) fprintf(trace_f, "%llu,%s\n", (unsigned long long)tick_count, marker_names[m]);
        if (m >= 0 && calls_f && npend < 64) {
            uint16_t sp = cpc.cpu.sp;
            pend[npend].ret = mem_rd(&cpc.mem, sp) | (mem_rd(&cpc.mem, sp + 1) << 8);
            pend[npend].sp = sp + 2; pend[npend].m = m; pend[npend].t = tick_count; npend++;
        }
    }
    prev_fetch = fetch;
}

static uint8_t rd(uint16_t a) { return mem_rd(&cpc.mem, a); }
static void dump_ram(int fr) {
    char dp[512]; snprintf(dp, sizeof dp, "%s/ram_%05d.bin", dump_dir, fr);
    FILE* df = fopen(dp, "wb"); for (int a = 0; a < 65536; a++) { uint8_t v = rd(a); fwrite(&v, 1, 1, df); } fclose(df);
}

static void write_ppm(const char* dir, int frame) {
    chips_display_info_t di = cpc_display_info(&cpc);
    const uint8_t* fb = (const uint8_t*)di.frame.buffer.ptr;
    const uint32_t* pal = (const uint32_t*)di.palette.ptr;
    char path[512];
    snprintf(path, sizeof path, "%s/f_%05d.ppm", dir, frame);
    FILE* f = fopen(path, "wb");
    fprintf(f, "P6\n%d %d\n255\n", AM40010_DISPLAY_WIDTH, AM40010_DISPLAY_HEIGHT);
    for (int y = 0; y < AM40010_DISPLAY_HEIGHT; y++) {
        for (int x = 0; x < AM40010_DISPLAY_WIDTH; x++) {
            uint32_t c = pal[fb[y * AM40010_FRAMEBUFFER_WIDTH + x]];
            uint8_t rgb[3] = { c & 0xFF, (c >> 8) & 0xFF, (c >> 16) & 0xFF };
            fwrite(rgb, 1, 3, f);
        }
    }
    fclose(f);
}

// ---------------------------------------------------------------- simple bot
// Reads the entity array and steers the miner: avoid TNT carts, chase others.
static int bot_e_array = -1, bot_e_size = 25, bot_flags_off = 18, bot_hold_frames = 5;
static int bot_hold = 0, bot_key = 0, bot_cooldown = 0;
static FILE* keys_f;

static void key(int frame, int code, bool down) {
    if (down) cpc_key_down(&cpc, code); else cpc_key_up(&cpc, code);
    if (keys_f) fprintf(keys_f, "%d,%d,%s\n", frame, code, down ? "down" : "up");
}

static int lane_of_y(int y, bool miner) {
    // rows: row_1=27, row_2=67, row_3=107. miner y = row-5, carts y = row+7
    int base = miner ? y + 5 : y - 7;
    if (base < 47) return 0;
    if (base < 87) return 1;
    return 2;
}

static void bot_step(int frame) {
    if (bot_e_array < 0) return;
    if (bot_hold > 0) { if (--bot_hold == 0) { key(frame, bot_key, false); bot_cooldown = 6; } return; }
    if (bot_cooldown > 0) { bot_cooldown--; return; }
    int miner_lane = -1;
    int danger[3] = {0, 0, 0};       // nearest TNT x per lane (0 = none)
    int prize_x[3] = {999, 999, 999};
    for (int i = 0; i < 24; i++) {
        uint16_t e = bot_e_array + i * bot_e_size;
        uint8_t type = rd(e + 0);
        if (type == 0) break;
        uint8_t x = rd(e + 1), y = rd(e + 2), flags = rd(e + bot_flags_off);
        if (type & 0x04) { miner_lane = lane_of_y(y, true); continue; }   // input entity = miner
        if (!(type & 0x08) || (type & 0x40)) continue;                     // carts that are alive
        int lane = lane_of_y(y, false);
        if (flags & 0x10) { if (x < 40 && (danger[lane] == 0 || x < danger[lane])) danger[lane] = x ? x : 1; }
        else if (x < prize_x[lane]) prize_x[lane] = x;
    }
    if (miner_lane < 0) return;
    int target = miner_lane;
    if (danger[miner_lane]) {             // dodge: go to a safe neighbour
        for (int d = 1; d <= 2; d++) {
            if (miner_lane - d >= 0 && !danger[miner_lane - d]) { target = miner_lane - 1; break; }
            if (miner_lane + d <= 2 && !danger[miner_lane + d]) { target = miner_lane + 1; break; }
        }
    } else {
        int best = miner_lane, bx = prize_x[miner_lane];
        for (int l = 0; l < 3; l++) if (!danger[l] && prize_x[l] < bx - 6) { best = l; bx = prize_x[l]; }
        if (best != miner_lane) {
            int next = miner_lane + (best > miner_lane ? 1 : -1);
            if (!danger[next]) target = next;
        }
    }
    if (target != miner_lane) {
        bot_key = (target < miner_lane) ? 'o' : 'p';   // O = up the screen, P = down
        key(frame, bot_key, true);
        bot_hold = bot_hold_frames;
    }
}

int main(int argc, char** argv) {
    const char *sna = 0, *out = ".", *map = 0, *prof = 0, *watch = 0, *shots = 0;
    int nframes = 500, every = 0; bool bot = false;
    struct { int frame; bool down; int code; } ev[512]; int nev = 0;
    const char* pk_spec[64]; int npk = 0;
    int dump_frames[256]; int ndump = 0;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-s")) sna = argv[++i];
        else if (!strcmp(argv[i], "-o")) out = argv[++i];
        else if (!strcmp(argv[i], "-m")) map = argv[++i];
        else if (!strcmp(argv[i], "-n")) nframes = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-p")) prof = argv[++i];
        else if (!strcmp(argv[i], "-w")) watch = argv[++i];
        else if (!strcmp(argv[i], "-e")) every = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-f")) shots = argv[++i];
        else if (!strcmp(argv[i], "-b")) bot = true;
        else if (!strcmp(argv[i], "-W")) watch_wr = (int)strtol(argv[++i], 0, 16);
        else if (!strcmp(argv[i], "-D")) { int fr = atoi(argv[++i]); if (ndump < 256) dump_frames[ndump++] = fr; }
        else if (!strcmp(argv[i], "-E")) bot_e_size = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-F")) bot_flags_off = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-I")) bot_hold_frames = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-P")) { if (npk < 64) pk_spec[npk++] = argv[++i]; else ++i; }
        else if (!strcmp(argv[i], "-k")) {
            int fr, code; char ud;
            if (sscanf(argv[++i], "%d:%c:%d", &fr, &ud, &code) == 3 && nev < 512) {
                ev[nev].frame = fr; ev[nev].down = (ud == 'd'); ev[nev].code = code; nev++;
            }
        }
    }
    if (!sna) { fprintf(stderr, "need -s file.sna\n"); return 1; }
    if (map) load_map(map);

    cpc_init(&cpc, &(cpc_desc_t){
        .type = CPC_TYPE_6128,
        .debug = { .callback = { .func = debug_cb, .user_data = 0 }, .stopped = &stopped },
        .roms = { .cpc6128 = {
            .os = { .ptr = dump_cpc6128_os_bin, .size = sizeof(dump_cpc6128_os_bin) },
            .basic = { .ptr = dump_cpc6128_basic_bin, .size = sizeof(dump_cpc6128_basic_bin) },
            .amsdos = { .ptr = dump_cpc6128_amsdos_bin, .size = sizeof(dump_cpc6128_amsdos_bin) },
        } },
    });
    // let the machine boot, then quickload the snapshot
    cpc_exec(&cpc, 1000000);
    FILE* f = fopen(sna, "rb");
    if (!f) { perror(sna); return 1; }
    static uint8_t buf[200000];
    size_t n = fread(buf, 1, sizeof buf, f); fclose(f);
    if (!cpc_quickload(&cpc, (chips_range_t){ .ptr = buf, .size = n }, true)) { fprintf(stderr, "quickload failed\n"); return 1; }

    memset(marker_of, 0xFF, sizeof marker_of);
    char path[512];
    if (prof) {
        snprintf(path, sizeof path, "%s/trace.csv", out); trace_f = fopen(path, "w");
        snprintf(path, sizeof path, "%s/calls.csv", out); calls_f = fopen(path, "w");
        char tmp[4096]; strncpy(tmp, prof, sizeof tmp - 1);
        for (char* t = strtok(tmp, ","); t; t = strtok(0, ",")) {
            int a = sym_lookup(t);
            if (a < 0) { fprintf(stderr, "warn: symbol %s not in map\n", t); continue; }
            strcpy(marker_names[num_markers], t); marker_of[a] = num_markers++;
        }
    }
    int waddr[64]; char wname[64][80]; int nw = 0;
    if (watch) {
        char tmp[4096]; strncpy(tmp, watch, sizeof tmp - 1);
        for (char* t = strtok(tmp, ","); t && nw < 64; t = strtok(0, ",")) {
            char nm[80]; int off = 0; strcpy(nm, t);
            char* plus = strchr(nm, '+'); if (plus) { off = atoi(plus + 1); *plus = 0; }
            int a = sym_lookup(nm);
            if (a < 0) { fprintf(stderr, "warn: watch %s not in map\n", nm); continue; }
            waddr[nw] = a + off; strcpy(wname[nw], t); nw++;
        }
    }
    FILE* watch_f = 0;
    if (nw) { snprintf(path, sizeof path, "%s/watch.csv", out); watch_f = fopen(path, "w"); }
    struct { int frame; int addr; int val; } pk[64]; int npk2 = 0;
    for (int i = 0; i < npk; i++) {
        int fr, val; char nm[80];
        if (sscanf(pk_spec[i], "%d:%79[^:]:%d", &fr, nm, &val) != 3) continue;
        int off = 0; char* plus = strchr(nm, '+'); if (plus) { off = atoi(plus + 1); *plus = 0; }
        int a = sym_lookup(nm); if (a < 0) { fprintf(stderr, "warn: poke %s not in map\n", nm); continue; }
        pk[npk2].frame = fr; pk[npk2].addr = a + off; pk[npk2].val = val; npk2++;
    }
    dump_dir = out; dump_pc = sym_lookup("game_wait");
    if (bot) { bot_e_array = sym_lookup("e_array"); if (bot_e_array < 0) fprintf(stderr, "warn: no e_array\n"); }
    snprintf(path, sizeof path, "%s/keys.csv", out); keys_f = fopen(path, "w");
    if (watch_wr >= 0) { snprintf(path, sizeof path, "%s/writes.csv", out); wr_f = fopen(path, "w"); }

    int shot_list[1024]; int nshots = 0;
    if (shots) { char tmp[8192]; strncpy(tmp, shots, sizeof tmp - 1); for (char* t = strtok(tmp, ","); t; t = strtok(0, ",")) shot_list[nshots++] = atoi(t); }

    if (trace_f) fprintf(trace_f, "0,START\n");
    for (int fr = 0; fr < nframes; fr++) {
        for (int i = 0; i < nev; i++) if (ev[i].frame == fr) key(fr, ev[i].code, ev[i].down);
        for (int i = 0; i < npk2; i++) if (pk[i].frame == fr) mem_wr(&cpc.mem, pk[i].addr, pk[i].val);
        if (bot) bot_step(fr);
        cpc_exec(&cpc, 19968);
        if (watch_f) {
            fprintf(watch_f, "%d", fr);
            for (int i = 0; i < nw; i++) fprintf(watch_f, ",%s=%u", wname[i], rd(waddr[i]));
            fprintf(watch_f, "\n");
        }
        bool snap = every && (fr % every == 0);
        for (int i = 0; i < nshots; i++) if (shot_list[i] == fr) snap = true;
        if (snap) write_ppm(out, fr);
        for (int i = 0; i < ndump; i++) if (dump_frames[i] == fr) {
            if (dump_pc >= 0) dump_pending = fr;    /* esperar al punto estable (game_wait) */
            else dump_ram(fr);
        }
    }
    if (trace_f) fclose(trace_f);
    if (calls_f) fclose(calls_f);
    if (watch_f) fclose(watch_f);
    if (keys_f) fclose(keys_f);
    if (wr_f) fclose(wr_f);
    printf("ran %d frames, %llu ticks, pc=%04X\n", nframes, (unsigned long long)tick_count, cpc.cpu.pc);
    return 0;
}
