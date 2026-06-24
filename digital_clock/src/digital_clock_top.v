// HR240B / EPM240 top-level module for the multi-function digital clock.
module digital_clock_top #(
    parameter integer CLK_HZ         = 50000000,
    parameter integer SCAN_HZ        = 4000,
    parameter integer DEBOUNCE_HZ    = 1000,
    parameter integer BLINK_HZ       = 2,
    parameter integer REVERSE_DIGITS = 0
)(
    input clk_50m,
    input [11:0] key_n,
    output [7:0] seg,
    output [2:0] sel,
    output [11:0] led
);
    wire rst;
    wire scan_clk;
    wire key_toggle;
    wire tick_toggle;
    wire blink;
    wire [2:0] scan_phase;
    wire [23:0] current_bcd;
    wire [23:0] auxiliary_bcd;
    wire show_auxiliary;

    assign rst = ~key_n[11];

    clock_divider #(
        .CLK_HZ(CLK_HZ),
        .SCAN_HZ(SCAN_HZ),
        .DEBOUNCE_HZ(DEBOUNCE_HZ),
        .BLINK_HZ(BLINK_HZ)
    ) u_divider (
        .clk(clk_50m),
        .rst(rst),
        .scan_clk(scan_clk),
        .key_toggle(key_toggle),
        .tick_toggle(tick_toggle),
        .blink(blink)
    );

    clock_control u_control (
        .clk(scan_clk),
        .rst(rst),
        .tick_toggle(tick_toggle),
        .key_toggle(key_toggle),
        .blink(blink),
        .key_n(key_n[7:0]),
        .scan_phase(scan_phase),
        .current_bcd(current_bcd),
        .auxiliary_bcd(auxiliary_bcd),
        .show_auxiliary(show_auxiliary),
        .led(led)
    );

    sevenseg_scan #(
        .REVERSE_DIGITS(REVERSE_DIGITS)
    ) u_display (
        .clk(scan_clk),
        .rst(rst),
        .scan_phase(scan_phase),
        .current_bcd(current_bcd),
        .auxiliary_bcd(auxiliary_bcd),
        .show_auxiliary(show_auxiliary),
        .seg(seg),
        .sel(sel)
    );
endmodule
