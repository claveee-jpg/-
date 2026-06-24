`timescale 1ns / 1ps

module digital_clock_tb;
    reg clk;
    reg [11:0] key_n;
    wire [7:0] seg;
    wire [2:0] sel;
    wire [11:0] led;

    digital_clock_top #(
        .CLK_HZ(1000),
        .SCAN_HZ(100),
        .DEBOUNCE_HZ(100),
        .BLINK_HZ(2),
        .REVERSE_DIGITS(0)
    ) dut (
        .clk_50m(clk),
        .key_n(key_n),
        .seg(seg),
        .sel(sel),
        .led(led)
    );

    always #5 clk = ~clk;

    function [3:0] tens;
        input integer value;
        begin tens = value / 10; end
    endfunction

    function [3:0] ones;
        input integer value;
        begin ones = value % 10; end
    endfunction

    function [23:0] ring_time;
        input integer hour_value;
        input integer min_value;
        input integer sec_value;
        begin
            ring_time = {ones(sec_value), tens(sec_value),
                         ones(min_value), tens(min_value),
                         ones(hour_value), tens(hour_value)};
        end
    endfunction

    task fail;
        input [255:0] msg;
        begin
            $display("FAIL at %0t: %0s", $time, msg);
            $stop;
        end
    endtask

    task reset_dut;
        begin
            key_n = 12'hFFF;
            key_n[11] = 1'b0;
            repeat (20) @(posedge clk);
            key_n[11] = 1'b1;
            repeat (40) @(posedge clk);
        end
    endtask

    task press_key;
        input integer idx;
        begin
            key_n[idx] = 1'b0;
            repeat (160) @(posedge clk);
            key_n[idx] = 1'b1;
            repeat (160) @(posedge clk);
        end
    endtask

    task wait_canonical;
        begin
            @(negedge dut.scan_clk);
            while (dut.u_control.phase !== 3'd0)
                @(negedge dut.scan_clk);
        end
    endtask

    task set_current;
        input integer hour_value;
        input integer min_value;
        input integer sec_value;
        begin
            wait_canonical;
            dut.u_control.current_time = ring_time(hour_value, min_value, sec_value);
            @(negedge dut.scan_clk);
        end
    endtask

    task set_auxiliary;
        input integer hour_value;
        input integer min_value;
        input integer sec_value;
        begin
            wait_canonical;
            dut.u_control.alarm_time = ring_time(hour_value, min_value, sec_value);
            @(negedge dut.scan_clk);
        end
    endtask

    task check_current;
        input integer hour_value;
        input integer min_value;
        input integer sec_value;
        begin
            wait_canonical;
            if (dut.u_control.current_time !==
                ring_time(hour_value, min_value, sec_value)) begin
                $display("Expected %0d:%0d:%0d", hour_value, min_value, sec_value);
                $display("Actual ring %h", dut.u_control.current_time);
                fail("current time mismatch");
            end
        end
    endtask

    task check_auxiliary;
        input integer hour_value;
        input integer min_value;
        input integer sec_value;
        begin
            wait_canonical;
            if (dut.u_control.alarm_time !==
                ring_time(hour_value, min_value, sec_value))
                fail("auxiliary time mismatch");
        end
    endtask

    task check_reminder_leds;
        input expected_hourly;
        input expected_alarm;
        begin
            force dut.blink = 1'b1;
            #1;
            if (led[8] !== expected_hourly)
                fail("D9 hourly indication mismatch");
            if (led[9] !== expected_alarm)
                fail("D10 alarm indication mismatch");
            release dut.blink;
        end
    endtask

    task wait_one_second;
        reg old_toggle;
        begin
            old_toggle = dut.tick_toggle;
            wait (dut.tick_toggle != old_toggle);
            repeat (16) @(posedge dut.scan_clk);
            wait_canonical;
        end
    endtask

    initial begin
        clk = 1'b0;
        key_n = 12'hFFF;

        reset_dut;
        check_current(0, 0, 0);

        press_key(0);
        if (led[0] !== 1'b1)
            fail("S1 did not start the clock");

        set_current(0, 0, 58);
        wait_one_second;
        check_current(0, 0, 59);
        wait_one_second;
        check_current(0, 1, 0);
        check_reminder_leds(1'b0, 1'b0);

        press_key(0);
        wait_one_second;
        check_current(0, 1, 0);

        dut.u_control.running = 1'b1;
        set_current(0, 59, 58);
        wait_one_second;
        wait_one_second;
        $display("CHECK minute rollover at %0t", $time);
        check_current(1, 0, 0);
        check_reminder_leds(1'b1, 1'b0);
        wait_one_second;
        check_current(1, 0, 1);
        check_reminder_leds(1'b0, 1'b0);

        press_key(6);
        set_current(23, 59, 58);
        wait_one_second;
        wait_one_second;
        check_current(0, 0, 0);
        repeat (12) @(posedge dut.scan_clk);
        if (dut.u_control.alarm_active !== 1'b1)
            fail("midnight alarm comparison did not trigger");
        check_reminder_leds(1'b1, 1'b1);
        wait_one_second;
        check_current(0, 0, 0);
        check_reminder_leds(1'b0, 1'b1);
        press_key(6);
        if ((dut.u_control.alarm_active !== 1'b0) ||
            (dut.u_control.alarm_enabled !== 1'b0))
            fail("S7 did not stop the midnight alarm reminder");

        dut.u_control.running = 1'b0;
        set_current(12, 34, 56);
        press_key(1);
        check_current(0, 0, 0);
        check_auxiliary(12, 34, 56);

        press_key(7);
        press_key(4);
        $display("CHECK hour edit at %0t", $time);
        check_current(1, 0, 0);
        press_key(3);
        press_key(5);
        check_current(1, 59, 0);
        press_key(3);
        press_key(4);
        check_current(1, 59, 1);

        press_key(7);
        set_current(0, 0, 0);
        set_auxiliary(0, 0, 1);
        press_key(7);
        press_key(6);
        press_key(0);
        wait_one_second;
        repeat (12) @(posedge dut.scan_clk);
        if (dut.u_control.alarm_active !== 1'b1)
            fail("alarm comparison did not trigger");
        wait_one_second;
        if (dut.u_control.alarm_active !== 1'b1)
            fail("alarm reminder did not hold the matching time");
        check_current(0, 0, 1);
        press_key(6);
        if ((dut.u_control.alarm_active !== 1'b0) ||
            (dut.u_control.alarm_enabled !== 1'b0))
            fail("S7 did not stop the alarm reminder");
        wait_one_second;
        check_current(0, 0, 2);

        force dut.u_display.active_digit = 4'd3;
        #1;
        if (seg[6:0] !== 7'b1001111)
            fail("seven-segment code for digit 3 is wrong");
        release dut.u_display.active_digit;

        $display("PASS: digital_clock_tb completed");
        $finish;
    end
endmodule
