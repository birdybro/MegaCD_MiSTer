derive_pll_clocks
derive_clock_uncertainty

set_multicycle_path -to {*Hq2x*} -setup 4
set_multicycle_path -to {*Hq2x*} -hold 3

set_multicycle_path -from [get_clocks { *|pll|pll_inst|altera_pll_i|*[0].*|divclk}] -to {ascal|*} -setup 4
set_multicycle_path -from [get_clocks { *|pll|pll_inst|altera_pll_i|*[0].*|divclk}] -to {ascal|*} -hold 3

# Audio CDC FIFO: clk_sys <-> clk_audio crossing is handled by the async FIFO
# in audio_out.v (audio_cdc_fifo). The synchronizer flops use the Quartus
# SYNCHRONIZER_IDENTIFICATION FORCED attribute for MTBF-aware placement,
# which works independently of timing analysis under set_clock_groups -exclusive.
