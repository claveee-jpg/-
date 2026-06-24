create_clock -name clk_50m -period 20.000 [get_ports {clk_50m}]
create_clock -name scan_clk -period 163840.000 \
    [get_pins {u_divider|counter[12]|regout}]
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50m}] \
    -group [get_clocks {scan_clk}]
