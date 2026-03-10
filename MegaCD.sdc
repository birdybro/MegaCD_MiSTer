derive_pll_clocks
derive_clock_uncertainty

set_multicycle_path -to {*Hq2x*} -setup 4
set_multicycle_path -to {*Hq2x*} -hold 3

set_multicycle_path -from [get_clocks { *|pll|pll_inst|altera_pll_i|*[0].*|divclk}] -to {ascal|*} -setup 4
set_multicycle_path -from [get_clocks { *|pll|pll_inst|altera_pll_i|*[0].*|divclk}] -to {ascal|*} -hold 3

# Audio CDC FIFO: constrain synchronizer paths between clk_sys and clk_audio.
# Keeps routing delay short so gray-coded synchronizer flops can resolve metastability.

# Write pointer synced to read domain
set_max_delay -from [get_registers {*audio_cdc*wr_ptr_gray[*]}] \
              -to   [get_registers {*audio_cdc*wr_ptr_gray_rd1[*]}] 3

# Read pointer synced to write domain
set_max_delay -from [get_registers {*audio_cdc*rd_ptr_gray[*]}] \
              -to   [get_registers {*audio_cdc*rd_ptr_gray_wr1[*]}] 3

# FIFO memory to read-side output register
set_max_delay -from [get_registers {*audio_cdc*mem[*][*]}] \
              -to   [get_registers {*audio_cdc*rd_data_r[*]}] 3
