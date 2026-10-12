`timescale 1ns/1ps
module tb_corner;
    reg wclk = 0, rclk = 0;
    reg wrst_n = 0, rrst_n = 0;
    reg winc = 0, rinc = 0;
    reg [7:0] wdata = 0;
    wire [7:0] rdata;
    wire wfull, rempty;
    integer errors = 0, e0, i, w, r;

    async_fifo dut (
        .wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),
        .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty));

    always #5 wclk = ~wclk;     // write clock
    always #7 rclk = ~rclk;     // read clock

    // wait a few clocks so the pointers cross between domains
    task settle;
        begin
            repeat (6) @(negedge wclk);
            repeat (6) @(negedge rclk);
        end
    endtask

    // reset both sides
    task do_reset;
        begin
            winc = 0; rinc = 0;
            wrst_n = 0; rrst_n = 0;
            #50;
            @(negedge wclk) wrst_n = 1;
            @(negedge rclk) rrst_n = 1;
            settle;
        end
    endtask

    // write one word (if the FIFO is full, the DUT should ignore it)
    task write_one(input [7:0] d);
        begin
            @(negedge wclk);
            winc = 1; wdata = d;
            @(negedge wclk);
            winc = 0;
        end
    endtask

    // read one word and check it (waits while the FIFO is empty)
    task read_one(input [7:0] expected);
        begin
            @(negedge rclk);
            while (rempty) @(negedge rclk);
            if (rdata !== expected) begin
                errors = errors + 1;
                $display("FAIL: expected %0d, got %0d", expected, rdata);
            end
            rinc = 1;
            @(negedge rclk);
            rinc = 0;
        end
    endtask

    task report(input integer id);
        begin
            if (errors == e0) $display("PASS: test %0d", id);
            else              $display("FAIL: test %0d", id);
        end
    endtask

    initial begin
        $dumpfile("corner.vcd");
        $dumpvars(0, tb_corner);

        // TEST 1: write when full
        e0 = errors;
        do_reset;
        for (i = 1; i <= 20; i = i + 1) write_one(i);   // only 16 fit
        settle;
        if (!wfull) begin errors = errors + 1; $display("FAIL: wfull should be 1"); end
        if (dut.u_wptr.wbin != 16) begin errors = errors + 1; $display("FAIL: write pointer should stop at 16"); end
        for (i = 1; i <= 16; i = i + 1) read_one(i);    // first 16 words, in order
        settle;
        if (!rempty) begin errors = errors + 1; $display("FAIL: rempty should be 1"); end
        if (wfull)   begin errors = errors + 1; $display("FAIL: wfull should be 0"); end
        report(1);

        // TEST 2: read when empty
        e0 = errors;
        do_reset;
        @(negedge rclk) rinc = 1;               // keep reading an empty FIFO
        repeat (5) @(negedge rclk);
        rinc = 0;
        if (!rempty) begin errors = errors + 1; $display("FAIL: rempty should stay 1"); end
        if (dut.u_rptr.rbin != 0) begin errors = errors + 1; $display("FAIL: read pointer moved"); end
        write_one(55);                          // FIFO must still work afterwards
        settle;
        read_one(55);
        settle;
        if (!rempty) begin errors = errors + 1; $display("FAIL: rempty should be 1 at end"); end
        report(2);

        // TEST 3: reset in the middle
        e0 = errors;
        do_reset;
        for (i = 0; i < 10; i = i + 1) write_one(100 + i);
        settle;
        if (rempty) begin errors = errors + 1; $display("FAIL: data should be stored"); end
        do_reset;                               // reset with data inside
        if (!rempty) begin errors = errors + 1; $display("FAIL: rempty should be 1 after reset"); end
        if (wfull)   begin errors = errors + 1; $display("FAIL: wfull should be 0 after reset"); end
        if (dut.u_wptr.wbin != 0 || dut.u_rptr.rbin != 0) begin
            errors = errors + 1; $display("FAIL: pointers should be 0 after reset");
        end
        for (i = 0; i < 3; i = i + 1) write_one(200 + i);
        settle;
        for (i = 0; i < 3; i = i + 1) read_one(200 + i);   // only the new words
        settle;
        if (!rempty) begin errors = errors + 1; $display("FAIL: old data still visible"); end
        report(3);

        // TEST 4: read and write at the same time
        e0 = errors;
        do_reset;
        fork
            begin for (w = 1; w <= 10; w = w + 1) write_one(w + 30); end
            begin for (r = 1; r <= 10; r = r + 1) read_one(r + 30);  end
        join
        settle;
        if (!rempty) begin errors = errors + 1; $display("FAIL: rempty should be 1 at end"); end
        report(4);

        if (errors == 0) $display("ALL CORNER TESTS PASSED");
        else             $display("TOTAL ERRORS: %0d", errors);
        $finish;
    end

    // stops the simulation if something gets stuck
    initial begin
        #500000;
        $display("TIMEOUT: simulation stuck");
        $finish;
    end
endmodule