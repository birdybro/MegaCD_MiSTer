# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MiSTer FPGA core implementing the Sega Mega CD (Sega CD). Targets Altera/Intel FPGAs using **Quartus 17.0.2 Standard Edition**. The output is an RBF bitstream file for the MiSTer platform.

## Build

Compilation is done via Quartus. There are no Makefiles or scripts — use the Quartus GUI or CLI:

```bash
# Full compilation (synthesis → fitting → assembly → timing)
quartus_sh --flow compile MegaCD

# Individual steps
quartus_map MegaCD          # Analysis & synthesis
quartus_fit MegaCD          # Fitter (place & route)
quartus_asm MegaCD          # Assembler (generate RBF)
quartus_sta MegaCD          # Timing analysis
```

Project files: `MegaCD.qpf` (primary, Quartus 17), `MegaCD_Q13.qpf` (Quartus 13 legacy). Top-level entity is `sys_top` (defined in `sys/sys_top.v`).

## Architecture

### Top-Level Module: `MegaCD.sv`

The `emu` module is the main emulation wrapper that interfaces with the MiSTer `sys/` framework. It instantiates two major subsystems:

- **Genesis/Mega Drive** (`gen` instance) — 68000 CPU, Z80, YM2612 FM, PSG, VDP, cartridge/ROM interface
- **Mega CD extension** (`mcd` instance) — Sub-68000, CD controller, Word RAM, PCM, CD-DA

### RTL Organization

| Directory | Language | Contents |
|-----------|----------|----------|
| `rtl/MCD/` | VHDL | Mega CD hardware: `ASIC.vhd` (main controller, 83KB), `CDC.vhd` (CD controller), `CDDA.vhd` (CD audio), `PCM.vhd` (sample playback), `MCD.vhd` (top-level) |
| `rtl/GEN/` | Mixed | Genesis hardware: `gen.sv` (system wrapper), `vdp.vhd` (video), `jt12/` (YM2612 FM), `jt89/` (PSG), `T80/` (Z80), `CART.vhd`, I/O controllers |
| `rtl/FX68K/` | SystemVerilog | Motorola 68000 CPU core (`fx68k.sv` + microcode ROMs) |
| `sys/` | Mixed | MiSTer platform layer (shared across cores): `sys_top.v`, `hps_io.sv` (HPS bridge), `audio_out.v`, `ascal.vhd` (video scaler), `pll.v`, `ddram.sv`, `sdram.sv` |

### Audio Signal Path

```
GEN (FM+PSG) ──→ halve ──┐
                          ├──→ mix ──→ compressor (optional) ──→ audio_out.v
MCD (PCM+CDDA) ─→ halve ─┘                                        │
                                                          ├─→ CDC FIFO (clk_core → clk_audio)
                                                          ├─→ IIR filter
                                                          └─→ I2S / SPDIF / Sigma-Delta
```

Audio mixing and per-source enable/disable is controlled via OSD status bits in `MegaCD.sv` (~lines 829-850).

### Memory Subsystem

- **SDRAM**: 2 banks — Bank 0-1 for Genesis ROM/BIOS/Cart RAM, Bank 2-3 for MCD Program RAM
- **DDR3**: Optional secondary interface via `ddram.sv`
- **Cache**: 2-way set-associative L2 cache (`sys/cache_2way.sv`)

### Clock Domains

- `clk_core` — system clock (~53.7 MHz, Genesis timing)
- `clk_audio` — 24.576 MHz from dedicated audio PLL (`sys/pll_audio.v`)
- CDC crossings between these domains are handled in `sys/audio_out.v`

### File Include Structure

`files.qip` is the master file list that references:
- `rtl/FX68K/fx68k.qip`
- `rtl/GEN/GEN.qip`
- `rtl/MCD/MCD.qip`
- Individual sys/ and top-level files

## Key Files for Common Tasks

- **OSD menu / status bits**: `MegaCD.sv` (status register decoding, active flags like `status[27]`, `status[58]`)
- **CD controller logic**: `rtl/MCD/CDC.vhd` and `rtl/MCD/ASIC.vhd`
- **Audio output / CDC**: `sys/audio_out.v`
- **HPS communication** (SD card, joystick, IOCTL): `sys/hps_io.sv`
- **Timing constraints**: `MegaCD.sdc`
- **Hardware reference docs**: `docs/` directory (Mega CD hardware/software manuals, Sanyo LC8950/8951 CD decoder IC specs)

## HDL Conventions

- Mega CD core modules (`rtl/MCD/`) are written in VHDL with package definitions in `ASIC_PKG.vhd`
- Genesis modules use a mix of VHDL (VDP, cartridge) and SystemVerilog (gen.sv, I/O)
- The `sys/` layer is primarily Verilog/SystemVerilog — this is shared MiSTer infrastructure, not core-specific
