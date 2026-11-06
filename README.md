# PickAxePete — Atari 5200

A 32 KB NTSC Atari 5200 cartridge port of the supplied, updated Atari 800XL
fixed-display version. All ten mines, original artwork, game rules, POKEY sound,
door transitions and high-score display are retained. The player label is fixed
at PLYR1; there is no name-entry mode. Requires a standard
5200 with 16 KB RAM. No VBXE, expanded RAM or bank-switching hardware is needed.

Download PickAxePete5200.car from the GitHub Releases page and load it on the
A5200 PicoCart or in an emulator configured as
Atari 5200 / NTSC. The CAR header is type 4 (standard 32 KB 5200 cartridge).
The build also produces PickAxePete5200.bin without the 16-byte CAR header.

## Controller 1

| Input | Action |
|---|---|
| Keypad 0–9 on SELECT GAME | Start the corresponding mine immediately |
| START or lower fire on SELECT GAME | Start mine 0 |
| Joystick | Move; use up/down for ladder and pick positioning |
| Direction + lower fire | Original jump/dodge action |
| Down without fire | Low pick-axe stroke |
| PAUSE | Pause/resume |
| START during play | Resume if paused |
| RESET | Return to SELECT GAME |

The high score lasts until power-off or cartridge restart. PLYR1 remains the
label after every game. The analog stick has a center dead zone (POT counts
85–144). The * and # keypad buttons do not enter a name editor.

AltirraSDL's default absolute 5200 keyboard mapping uses arrows, Left Ctrl,
0–9, F2/F3/F4 for START/PAUSE/RESET, and minus/equals for */#.

## What changed for the 5200

Hardware registers, BIOS interrupt vectors and cartridge startup replace the
XL loader and OS shutdown. Writable display storage fits inside 16 KB RAM;
fixed artwork and tables run from cartridge ROM. Small self-modifying routines
are copied into RAM. A compact font image is expanded at scene setup.
Keypad interrupts latch presses and suppress repeats while a key is held.
The original game rules are retained; the 5200 build uses a fixed player label.

RAM: $0400 display list; $0500 glyph staging; $0700 transition row;
$0800–$0BFF state; $0C00 work map; $1000 background map; $1400 visible map;
$1800 player/missile block; $2000–$2BFF playfield fonts; $2C00 HUD font;
$3000 small writable routines; C software stack grows down from $4000.

## HUD separator and player label (current build)

The eight-pixel row immediately above the score now uses three bitmap floor
lines and five actual blank lines, instead of a character row. It cannot fetch
unwanted glyph pixels during the switch from the mine font to the HUD font.
The HUD display interrupt occurs at scanline 213, before the score starts at
216. Its original screen position and the side walls are preserved.

PLYR1 replaces the six question marks at startup and after a high score. The
5200 controller name editor is removed; gameplay never pauses for name entry.
The Atari 800XL source behavior is retained behind the PICKAXE_5200 build flag.

The focused regression checks the linked display-list geometry, the blank
strip in three captured screens, physical */# button presses, the death/high-
score path and 1,800 further frames. It records zero missed frames. The
high-score case uses a documented RAM fixture; it is not a five-level playtest.
One extra screenshot temporarily disables player/missile graphics to check the
background alone, since normal explosion sprites can overlap the separator.

    python3 tests/hud_boundary.py

## Earlier display-interrupt correction (retained)

The previous correction did not resolve the reported corruption. This build also
fixes scene rebuilding and display-interrupt synchronization:

- Display NMIs are disabled before a scene rebuild and re-enabled only after
  display memory is complete and stale NMI status is cleared.
- Each display interrupt selects its handler from VCOUNT. The mutable
  next-handler jump chain has been removed.
- Real vertical blank restores the playfield charset and palette every frame.

The linked-6502 test enters through the original BIOS NMI dispatcher and
intentionally omits combinations of the four display interrupts. The previous
build fails to recover in 14 of 16 cases; this build recovers in all 16 while
preserving A, X, Y and the CPU stack. Scene setup previously performed 13,132
shared-display writes with NMIs enabled; the current build performs zero.
This is a targeted fault-injection regression, not a claim that the exact user
input sequence from the reported failure has been reconstructed.

Checks at that revision passed all ten starting layouts, controller checks,
244 mine-transition frames, death/high-score restart, 6,000 gameplay frames
with zero missed frames, and 7,296,000 renderer pixel/PMG comparisons.

    ATARI5200_BIOS=/path/to/atari5200.rom python3 tests/interrupt_regression.py

## Earlier terrain-copy correction (retained)

The self-modifying character-copy destination advanced after cell 32. Previously
that destination was reset only when preparing a new batch. The Pause path can
commit the same batch repeatedly, allowing a large batch to overwrite the next
playfield font and eventually the HUD. The destination is now reset at the start
of every commit. Game rules, assets, controller mapping and difficulty are unchanged.

The linked-code regression covers 0, 1, 31, 32, 33 and 45 cells in each of three
font banks, repeated 120 times per case: 2,160 commits with no protected-font
changes. The earlier cartridge fails the 33- and 45-cell repeat cases. These are
synthetic renderer fixtures; they are separate from controller-only gameplay.

## Validation history

The final PLYR1 build repeats the logic, renderer, HUD, interrupt and font-copy
regressions, plus the focused HUD-boundary check above. The full ten-layout
controller checks and longer gameplay runs below predate this HUD revision.

Tested with AltirraSDL in NTSC 5200 mode, 16 KB RAM, original Atari four-port
BIOS. This is emulator validation; physical 5200/PicoCart testing and PAL
validation remain outstanding. Other BIOS versions have not been validated.

- All ten keypad-selected layouts and held-key repeat suppression.
- All four analog directions, pause/resume input and reset.
- 20,000 terrain cases and 5,000 integrated linked-6502 ticks compared with
  the existing portable model: zero mismatches across 66 state fields.
- 7,296,000 renderer pixel/PMG-byte comparisons: zero mismatches.
- 82,432 HUD pixel comparisons covering all accepted glyphs: zero mismatches.
- Door/key transition: 244 frames checked, no stale ladder/item/effect bytes,
  floor removal and return to play verified. This case uses a seeded fixture.
- Death/high-score fixture verified; current build keeps PLYR1 permanently.
- 6,000-frame extended gameplay run and 1,800-frame controller-only recording:
  zero missed-frame counts. This does not certify every possible game state.

The earlier font-copy revision playtest used automated physical-key controller inputs,
read-only RAM observations and a separate copy of the C rule model for choosing
moves. It did not write game RAM, change difficulty, load states, or skip levels.
The best attempt cleared four successive mines and died in the fifth. The user
accepted that coverage before a five-clear run was completed. Terrain-font
invariants remained intact and the sampled missed-frame counter stayed zero.
The exact reported trigger has not been reconstructed. Physical hardware has
not been retested. See the current-build interrupt regression above.

Correction reports are included under evidence/. Full historical recordings
and progress logs are retained in the separate source-and-tests download.
Run tests/font_commit_regression.py to repeat the renderer regression; an optional
argument names an older native/build5200 directory for a before/after comparison.
The controller test additionally builds tests/frontend_tcp.c as a shared library:

    cc -shared -fPIC tests/frontend_tcp.c -o tests/frontend_tcp.so -ldl
    python3 tests/campaign_v6.py

That small shim changes only the local test-command transport to loopback TCP.

## Build

On Linux x86-64, the included cc65 tools can build the cartridge:

    chmod +x tools/cc65/bin/*
    python3 native/build5200.py

Outputs are in native/build5200/. Set CC65_BIN to another compatible toolchain's
bin directory if required; its sibling lib directory must contain none.lib.

Logic and pixel checks require Python, NumPy, py65 and a C compiler:

    cc -shared -fPIC -O2 -Dstatic= -DPICKAXE_5200 native/game.c native/entropy.c -o native/build5200/game_host.so
    python3 native/core5200_test.py
    python3 native/render5200_test.py
    python3 native/hud5200_test.py

AltirraSDL checks additionally require an emulator build supporting its physical
key test-script transport and Bridge, plus the matching Python SDK. Set
ALTIRRA_SDL, ALTIRRA_BRIDGE_SDK and ATARI5200_BIOS to those local dependencies.
Then run tests/acceptance.py, tests/scenarios.py and tests/hud_boundary.py from
the project root. The HUD boundary screenshot check also requires Pillow.
No console BIOS or emulator binary is included.

## Provenance

This continues the supplied 800XL source; it is not a new clean-room recreation
of the original game. Reference inputs and original artwork retain their
existing ownership. Dependency notices are retained in licenses/. This repository
does not apply a new license to the game or to third-party material.
