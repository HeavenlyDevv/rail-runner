# Emulator tools

A headless Amstrad CPC 6128 for testing the game, built on [floooh/chips](https://github.com/floooh/chips), and the source of the web player. Everything runs inside the Docker image from this `Dockerfile` (the emulator is in `/opt/chips`).

## rrsim

```sh
gcc -O2 -std=c11 -o rrsim rrsim.c -I/opt/chips -I/opt/chips-test/examples/roms
./rrsim -s railrun.sna -m obj/railrun.map -o out -n 3000 -k 60:d:13 -k 66:u:13 -b
```

| Option | What it does |
|---|---|
| `-s game.sna` | Snapshot to run |
| `-m game.map` | Linker map, so the other options can use symbol names |
| `-o folder` | Output folder |
| `-n frames` | How many 50 Hz frames to run |
| `-k frame:d\|u:code` | Press (`d`) or release (`u`) a key; ASCII codes (`13` Enter, `111` O, `112` P) |
| `-b` | Let a simple bot play (avoids TNT, chases the other carts); `-F 15` is the flags offset in the entity, `-I n` how many frames it holds a key |
| `-P frame:symbol[+off]:value` | Write a byte to memory (jump to a level, set the score...) |
| `-w symbol[+off],...` | Log those bytes every frame to `watch.csv` |
| `-p symbol,...` | Profile those functions: `trace.csv` (every entry) and `calls.csv` (time per call) |
| `-f f1,f2,...` / `-e n` | Save the screen at those frames / every n frames (`f_NNNNN.ppm`) |
| `-D frame` | Dump all 64 KB of RAM at the next `game_wait` after that frame (`ram_NNNNN.bin`) |
| `-W hexaddr` | Log every write to that address, with the instructions leading up to the first one |

## Scripts

- `analyze.py out sym1,sym2,... game_wait`: loop length, frames per update and time per system.
- `calls.py out`: time per profiled function call, per loop.
- `states.py out [sym,...]`: the watched values each time one of them changes.
- `screencheck.py railrun.map out/ram_*.bin`: rebuilds what the visible screen should show from the entity data and compares it byte for byte with video memory.
- `pens.py project_folder`: which palette pens each sprite uses.
- `gridview.py out.png frames...` and `animpreview.py out.gif name=frame...`: enlarged frames and animated previews for drawing sprites.

## Web player

`cpcweb.c` is the emulator compiled to WebAssembly, without libc or ROMs (the game starts with both ROMs paged out). `shim/` has the two headers it needs.

```sh
clang --target=wasm32 -O2 -nostdlib -ffreestanding -fno-builtin -Ishim -I/opt/chips \
  -Wl,--no-entry -Wl,--initial-memory=4194304 -Wl,-z,stack-size=262144 -Wl,--strip-all \
  -o rr.wasm cpcweb.c
```

`web/index.html` carries `rr.wasm` and the game snapshot as gzip + base64 blocks (`bin-wasm` and `bin-game`); to update one, replace the block's text.
