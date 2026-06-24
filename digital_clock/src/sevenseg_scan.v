// Six active display positions driven from the head of the serial BCD rings.
module sevenseg_scan #(
    parameter integer REVERSE_DIGITS = 0
)(
    input clk,
    input rst,
    input [2:0] scan_phase,
    input [23:0] current_bcd,
    input [23:0] auxiliary_bcd,
    input show_auxiliary,
    output reg [7:0] seg,
    output reg [2:0] sel
);
    reg [3:0] active_digit;
    reg active_dp;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            active_digit <= 4'hF;
            active_dp <= 1'b0;
        end else begin
            if (show_auxiliary)
                active_digit <= auxiliary_bcd[23:20];
            else
                active_digit <= current_bcd[23:20];
            active_dp <= (scan_phase == 3'd2) || (scan_phase == 3'd4);
        end
    end

    always @(*) begin
        if (REVERSE_DIGITS == 0) begin
            case (scan_phase)
                3'd1: sel = 3'd6;
                3'd2: sel = 3'd5;
                3'd3: sel = 3'd4;
                3'd4: sel = 3'd3;
                3'd5: sel = 3'd2;
                default: sel = 3'd1;
            endcase
        end else begin
            case (scan_phase)
                3'd1: sel = 3'd1;
                3'd2: sel = 3'd2;
                3'd3: sel = 3'd3;
                3'd4: sel = 3'd4;
                3'd5: sel = 3'd5;
                default: sel = 3'd6;
            endcase
        end

        case (active_digit)
            4'd0: seg = 8'b0011_1111;
            4'd1: seg = 8'b0000_0110;
            4'd2: seg = 8'b0101_1011;
            4'd3: seg = 8'b0100_1111;
            4'd4: seg = 8'b0110_0110;
            4'd5: seg = 8'b0110_1101;
            4'd6: seg = 8'b0111_1101;
            4'd7: seg = 8'b0000_0111;
            4'd8: seg = 8'b0111_1111;
            4'd9: seg = 8'b0110_1111;
            default: seg = 8'b0000_0000;
        endcase
        if (active_digit != 4'hF)
            seg[7] = active_dp;
    end
endmodule
