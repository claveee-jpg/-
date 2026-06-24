// Master divider. Slow square-wave taps are used as the scan clock, key
// sampling toggle, and visible blink source to minimize EPM240 logic usage.
module clock_divider #(
    parameter integer CLK_HZ      = 50000000,
    parameter integer SCAN_HZ     = 4000,
    parameter integer DEBOUNCE_HZ = 1000,
    parameter integer BLINK_HZ    = 2
)(
    input clk,
    input rst,
    output scan_clk,
    output key_toggle,
    output reg tick_toggle,
    output blink
);
    reg [25:0] counter;
    wire one_second;

    assign one_second = (counter == CLK_HZ - 1);

    generate
        if (CLK_HZ >= 1000000) begin : g_board_taps
            assign scan_clk  = counter[12];
            assign key_toggle = counter[18];
            assign blink = counter[23];
        end else begin : g_sim_taps
            assign scan_clk  = counter[2];
            assign key_toggle = counter[5];
            assign blink = counter[8];
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            counter <= 26'd0;
            tick_toggle <= 1'b0;
        end else if (one_second) begin
            counter <= 26'd0;
            tick_toggle <= ~tick_toggle;
        end else begin
            counter <= counter + 1'b1;
        end
    end
endmodule
