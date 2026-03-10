# Audio CDC Crackling Fixes — Summary

## Problem

Intermittent audio crackles on the PCM5102 DAC output (IO board analog audio). The crackles are:
- **Seed-dependent**: different Quartus fitter seeds produce different results
- **Placement-sensitive**: toggling video options (e.g. composite) changes whether crackles appear
- **Not fixed by the async FIFO alone**: the `audio_cdc_fifo` added on the `audio_cdc` branch was architecturally correct but still crackled on some builds

## Root Cause

The `set_clock_groups -exclusive` constraint in `sys/sys_top.sdc` declared `clk_sys` (core PLL) and `clk_audio` (`pll_audio`) as mutually exclusive clocks. This told Quartus that **no paths exist between these domains**, so it:

1. Never checked timing on the CDC synchronizer flops
2. Had no incentive to place synchronizer registers close together
3. Could scatter the CDC FIFO across the chip based on whatever made other timing easier

The result: synchronizer routing delay varied wildly by seed and placement pressure. When the delay was too long, metastability events propagated through to corrupt audio samples, producing crackles.

A secondary issue: the FIFO write side was unconditionally writing to memory every `clk_wr` cycle even when full, potentially corrupting the entry the read side was about to sample.

## Fixes Applied

### Fix 1: `MegaCD.sdc` — Add `set_max_delay` constraints for CDC paths

```sdc
set_max_delay -from [get_registers {*audio_cdc*wr_ptr_gray[*]}] \
              -to   [get_registers {*audio_cdc*wr_ptr_gray_rd1[*]}] 3
set_max_delay -from [get_registers {*audio_cdc*rd_ptr_gray[*]}] \
              -to   [get_registers {*audio_cdc*rd_ptr_gray_wr1[*]}] 3
set_max_delay -from [get_registers {*audio_cdc*mem[*][*]}] \
              -to   [get_registers {*audio_cdc*rd_data_r[*]}] 3
```

Forces the fitter to keep routing delay under 3ns on all cross-domain paths in the FIFO, ensuring the synchronizer flops have enough time to resolve metastability regardless of seed.

**Commit:** `3638644`

### Fix 2: `sys/sys_top.sdc` — Remove `pll_audio` from exclusive clock group

Removed `pll_audio` from the `set_clock_groups -exclusive` declaration. Without this, the `-exclusive` constraint overrides the `set_max_delay` constraints from Fix 1 — Quartus ignores all paths between exclusive groups, even those with explicit max delay.

Replaced with targeted `set_false_path` declarations between `pll_audio` and all other unrelated clock groups (HDMI, SPI, I2C) so the fitter still doesn't waste effort on those genuinely unrelated crossings.

**Commit:** `d5252fc`

### Fix 3: `sys/audio_out.v` — Add `SYNCHRONIZER_IDENTIFICATION FORCED` attributes

```verilog
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED", preserve, dont_merge *)
reg [AW:0] wr_ptr_gray_rd1 = 0;
```

Applied to all four synchronizer registers (`wr_ptr_gray_rd1`, `wr_ptr_gray_rd`, `rd_ptr_gray_wr1`, `rd_ptr_gray_wr`). This:
- Tells Quartus these are intentional synchronizer chains, enabling MTBF-aware placement
- `preserve` prevents the register from being optimized away
- `dont_merge` prevents combining with other logic

**Commit:** `5ea2c68`

### Fix 4: `sys/audio_out.v` — Guard FIFO memory write behind full check

Changed:
```verilog
// Before: wrote mem[] unconditionally, only gated pointer advance
mem[wr_ptr_bin[AW-1:0]] <= wr_data;
if (!wr_full) begin ...

// After: both write and pointer advance gated together
end else if (!wr_full) begin
    mem[wr_ptr_bin[AW-1:0]] <= wr_data;
    ...
```

With `clk_sys` (~53.7 MHz) running >2x faster than `clk_audio` (24.576 MHz), the 4-entry FIFO stays near capacity. The unconditional write was overwriting entries in-place even when full, corrupting data the read side was about to sample across the clock boundary.

**Commit:** `b1654dc`

## Testing Recommendations

1. Build with multiple seeds (e.g. seeds 1-5) and verify crackle-free audio on the IO board DAC across all builds
2. Toggle composite video / other video options during playback to confirm audio remains clean
3. Check Quartus timing reports for the `set_max_delay` constraints — they should all pass with positive slack
4. Run `report_metastability` in Quartus to verify the synchronizer chains are recognized and have acceptable MTBF
