// Six-nibble serial BCD rings, clocked by the display scan clock.
// Ring order at phase 0: SO, ST, MO, MT, HO, HT.
module clock_control(
    input clk,
    input rst,
    input tick_toggle,
    input key_toggle,
    input blink,
    input [7:0] key_n,

    output [2:0] scan_phase,
    output [23:0] current_bcd,
    output [23:0] auxiliary_bcd,
    output show_auxiliary,
    output reg [11:0] led
);
    localparam [1:0] MODE_NORMAL    = 2'd0;
    localparam [1:0] MODE_SET_TIME  = 2'd1;
    localparam [1:0] MODE_SET_ALARM = 2'd2;
    localparam [1:0] FIELD_HOUR = 2'd0;
    localparam [1:0] FIELD_MIN  = 2'd1;
    localparam [1:0] FIELD_SEC  = 2'd2;

    reg [23:0] current_time;
    reg [23:0] alarm_time;
    reg [2:0] phase;
    reg [1:0] mode;
    reg [1:0] field;
    reg running;
    reg alarm_enabled;
    reg alarm_equal;
    reg alarm_active;

    reg tick_seen;
    reg tick_pending;
    reg tick_carry;

    reg key_seen;
    reg key_locked;

    reg edit_pending;
    reg edit_tens_pending;
    reg edit_up;
    reg edit_alarm;
    reg [1:0] edit_field;

    wire [7:0] key_down;
    wire key_sample;
    wire alarm_digit_equal;
    wire hourly_chime;
    wire edit_phase_match;
    wire [3:0] edit_ones;
    wire [3:0] edit_tens;
    wire edit_is_hour;
    wire [3:0] edit_max_tens;
    wire [3:0] edit_max_ones;
    reg [3:0] edited_ones;
    reg edit_needs_tens;

    assign scan_phase = phase;
    assign current_bcd = current_time;
    // The alarm and saved value share one auxiliary BCD bank.
    assign auxiliary_bcd = alarm_time;
    assign key_down = ~key_n;
    assign key_sample = (key_toggle != key_seen);
    assign show_auxiliary = key_down[2] || (mode == MODE_SET_ALARM);
    assign alarm_digit_equal = (current_time[23:20] == alarm_time[23:20]);
    // EPM240 is full, so edit_up is reused in normal mode as the one-second
    // hourly indication latch. In setting modes it remains the edit direction.
    assign hourly_chime = (mode == MODE_NORMAL) && edit_up;

    assign edit_phase_match = ((edit_field == FIELD_SEC)  && (phase == 3'd0)) ||
                              ((edit_field == FIELD_MIN)   && (phase == 3'd2)) ||
                              ((edit_field == FIELD_HOUR)  && (phase == 3'd4));
    assign edit_ones = edit_alarm ? alarm_time[23:20] : current_time[23:20];
    assign edit_tens = edit_alarm ? alarm_time[19:16] : current_time[19:16];
    assign edit_is_hour = (edit_field == FIELD_HOUR);
    assign edit_max_tens = edit_is_hour ? 4'd2 : 4'd5;
    assign edit_max_ones = edit_is_hour ? 4'd3 : 4'd9;

    always @(*) begin
        edited_ones = edit_ones;
        edit_needs_tens = 1'b0;
        if (edit_up) begin
            if (edit_is_hour && (edit_ones == 4'd3) && (edit_tens == 4'd2)) begin
                edited_ones = 4'd0;
                edit_needs_tens = 1'b1;
            end else if (edit_ones == 4'd9) begin
                edited_ones = 4'd0;
                edit_needs_tens = 1'b1;
            end else begin
                edited_ones = edit_ones + 1'b1;
            end
        end else if (edit_ones == 4'd0) begin
            edit_needs_tens = 1'b1;
            if (edit_tens == 4'd0) begin
                edited_ones = edit_max_ones;
            end else begin
                edited_ones = 4'd9;
            end
        end else begin
            edited_ones = edit_ones - 1'b1;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_time      <= 24'h000000;
            alarm_time        <= 24'h000000;
            phase             <= 3'd0;
            mode              <= MODE_NORMAL;
            field             <= FIELD_HOUR;
            running           <= 1'b0;
            alarm_enabled     <= 1'b0;
            alarm_equal       <= 1'b0;
            alarm_active      <= 1'b0;
            tick_seen         <= 1'b0;
            tick_pending      <= 1'b0;
            tick_carry        <= 1'b0;
            key_seen          <= 1'b0;
            key_locked        <= 1'b0;
            edit_pending      <= 1'b0;
            edit_tens_pending <= 1'b0;
            edit_up           <= 1'b0;
            edit_alarm        <= 1'b0;
            edit_field        <= FIELD_HOUR;
        end else begin
            // Both BCD banks rotate once per digit. Modified head digits are
            // written into the low nibble by later assignments in this block.
            current_time <= {current_time[19:0], current_time[23:20]};
            alarm_time   <= {alarm_time[19:0], alarm_time[23:20]};
            phase <= (phase == 3'd5) ? 3'd0 : phase + 1'b1;

            if (tick_toggle != tick_seen) begin
                tick_seen <= tick_toggle;
                // End the previous hourly indication after one real second,
                // even if an active alarm is currently holding the clock.
                if (mode == MODE_NORMAL)
                    edit_up <= 1'b0;
                if (running && (mode == MODE_NORMAL) && !alarm_active)
                    tick_pending <= 1'b1;
            end

            // Accumulate all six BCD comparisons. While a match is active,
            // one-second updates are held until S7 disables the alarm.
            if (phase == 3'd0) begin
                alarm_equal <= alarm_digit_equal;
            end else if (phase <= 3'd4) begin
                alarm_equal <= alarm_equal && alarm_digit_equal;
            end else begin
                alarm_active <= alarm_enabled && (mode == MODE_NORMAL) &&
                                alarm_equal && alarm_digit_equal;
            end

            if (key_sample) begin
                key_seen <= key_toggle;

                if (key_down == 8'd0) begin
                    key_locked <= 1'b0;
                end else if (!key_locked) begin
                    key_locked <= 1'b1;

                if (key_down[7]) begin
                    field <= FIELD_HOUR;
                    edit_up <= 1'b0;
                    if (mode == MODE_NORMAL)
                        mode <= MODE_SET_TIME;
                    else if (mode == MODE_SET_TIME)
                        mode <= MODE_SET_ALARM;
                    else
                        mode <= MODE_NORMAL;
                end

                if (key_down[3] && (mode != MODE_NORMAL)) begin
                    if (field == FIELD_SEC)
                        field <= FIELD_HOUR;
                    else
                        field <= field + 1'b1;
                end

                if (key_down[0] && (mode == MODE_NORMAL))
                    running <= ~running;

                if ((key_down[4] || key_down[5]) && (mode != MODE_NORMAL)) begin
                    edit_pending <= 1'b1;
                    edit_up      <= key_down[4];
                    edit_alarm   <= (mode == MODE_SET_ALARM);
                    edit_field   <= field;
                end

                if (key_down[1]) begin
                    alarm_time   <= {current_time[19:0], current_time[23:20]};
                    current_time <= 24'h000000;
                    running      <= 1'b0;
                    alarm_enabled <= 1'b0;
                    tick_pending <= 1'b0;
                    tick_carry   <= 1'b0;
                    edit_up      <= 1'b0;
                end

                if (key_down[6]) begin
                    alarm_enabled <= ~alarm_enabled;
                end
                end
            end

            if (tick_pending && (phase == 3'd0)) begin
                tick_pending <= 1'b0;
                if (current_time[23:20] == 4'd9) begin
                    current_time[3:0] <= 4'd0;
                    tick_carry <= 1'b1;
                end else begin
                    current_time[3:0] <= current_time[23:20] + 1'b1;
                    tick_carry <= 1'b0;
                end
            end else if (tick_carry) begin
                case (phase)
                    3'd1, 3'd3: begin
                        if (current_time[23:20] == 4'd5) begin
                            current_time[3:0] <= 4'd0;
                            tick_carry <= 1'b1;
                            // A carry through minute tens is exactly
                            // HH:59:59 -> (HH+1):00:00.
                            if (phase == 3'd3)
                                edit_up <= 1'b1;
                        end else begin
                            current_time[3:0] <= current_time[23:20] + 1'b1;
                            tick_carry <= 1'b0;
                        end
                    end
                    3'd2: begin
                        if (current_time[23:20] == 4'd9) begin
                            current_time[3:0] <= 4'd0;
                            tick_carry <= 1'b1;
                        end else begin
                            current_time[3:0] <= current_time[23:20] + 1'b1;
                            tick_carry <= 1'b0;
                        end
                    end
                    3'd4: begin
                        if ((current_time[23:20] == 4'd3) &&
                            (current_time[19:16] == 4'd2)) begin
                            current_time[3:0] <= 4'd0;
                            tick_carry <= 1'b1;
                        end else if (current_time[23:20] == 4'd9) begin
                            current_time[3:0] <= 4'd0;
                            tick_carry <= 1'b1;
                        end else begin
                            current_time[3:0] <= current_time[23:20] + 1'b1;
                            tick_carry <= 1'b0;
                        end
                    end
                    3'd5: begin
                        current_time[3:0] <= (current_time[23:20] == 4'd2) ?
                                             4'd0 : current_time[23:20] + 1'b1;
                        tick_carry <= 1'b0;
                    end
                    default: tick_carry <= 1'b0;
                endcase
            end

            if (edit_pending && edit_phase_match) begin
                if (edit_alarm)
                    alarm_time[3:0] <= edited_ones;
                else
                    current_time[3:0] <= edited_ones;
                edit_pending <= 1'b0;
                edit_tens_pending <= edit_needs_tens;
            end else if (edit_tens_pending) begin
                if (edit_alarm) begin
                    if (edit_up)
                        alarm_time[3:0] <= (alarm_time[23:20] == edit_max_tens) ?
                                             4'd0 : alarm_time[23:20] + 1'b1;
                    else
                        alarm_time[3:0] <= (alarm_time[23:20] == 4'd0) ?
                                             edit_max_tens : alarm_time[23:20] - 1'b1;
                end else begin
                    if (edit_up)
                        current_time[3:0] <= (current_time[23:20] == edit_max_tens) ?
                                               4'd0 : current_time[23:20] + 1'b1;
                    else
                        current_time[3:0] <= (current_time[23:20] == 4'd0) ?
                                               edit_max_tens : current_time[23:20] - 1'b1;
                end
                edit_tens_pending <= 1'b0;
            end

        end
    end

    always @(*) begin
        led = 12'd0;
        led[0] = running;
        led[1] = (mode == MODE_SET_TIME);
        led[2] = (mode == MODE_SET_ALARM);
        led[3] = alarm_enabled;
        led[8] = hourly_chime && blink;
        led[9] = alarm_active && blink;
    end
endmodule
