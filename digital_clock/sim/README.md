# Simulation Guide

Run these commands from the `sim` directory in ModelSim-Altera:

```tcl
vlib work
vlog ../src/clock_divider.v
vlog ../src/clock_control.v
vlog ../src/sevenseg_scan.v
vlog ../src/digital_clock_top.v
vlog digital_clock_tb.v
vsim work.digital_clock_tb
run -all
```

Expected result:

```text
PASS: digital_clock_tb completed
```

The testbench reduces `CLK_HZ` to 1000 and checks rollover, pause, clear/save,
field increase/decrease, alarm comparison, and seven-segment encoding.

Verified with ModelSim-Altera 10.1d. The complete self-checking run finishes at
about `112476 ns` and prints `PASS: digital_clock_tb completed`.
