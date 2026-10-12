`timescale 1ns/1ps
module tb_async_fifo;
    parameter DW = 8, AW = 4;
    parameter N  = 100;                      // words to transfer

`ifdef SWAP
    localparam real WH = 13.5, RH = 5.0;     // slow writer, fast reader
`else
    localparam real WH = 5.0,  RH = 13.5;    // fast writer, slow reader
`endif

    reg wclk = 0, rclk = 0, wrst_n = 0, rrst_n = 0;
    reg winc = 0, rinc = 0;
    reg  [DW-1:0] wdata = 0, expected;
    wire [DW-1:0] rdata;
    wire wfull, rempty;
    integer wcount = 0, rcount = 0, errors = 0;
    reg saw_full = 0, saw_empty = 0;

    async_fifo #(DW, AW) dut (
        .wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),
        .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty));

    always #(WH) wclk = ~wclk;
    always #(RH) rclk = ~rclk;

    // Resets released at different times (asynchronous domains)
    initial begin
        #22 wrst_n = 1;
        #9  rrst_n = 1;
    end

    // Writer: push N words, pausing whenever the FIFO is full
    initial begin
        wait (wrst_n);
        while (wcount < N) begin
            @(negedge wclk);
            if (!wfull) begin
                winc  = 1;
                wdata = wcount*7 + 3;
                wcount = wcount + 1;
            end else winc = 0;
        end
        @(negedge wclk) winc = 0;
    end

    // Reader: starts late so the FIFO can fill up first
    initial begin
        wait (rrst_n);
        #400;
        while (rcount < N) begin
            @(negedge rclk);
            if (!rempty) begin
                expected = rcount*7 + 3;
                if (rdata !== expected) begin
                    errors = errors + 1;
                    $display("FAIL: word %0d expected %0d got %0d at %0t",
                             rcount, expected, rdata, $time);
                end
                rinc = 1;
                rcount = rcount + 1;
            end else rinc = 0;
        end
        @(negedge rclk) rinc = 0;
        repeat (5) @(negedge rclk);
        if (!rempty) begin
            errors = errors + 1;
            $display("FAIL: FIFO not empty after all words read");
        end
        $display("wfull seen: %0d | rempty seen: %0d", saw_full, saw_empty);
        if (errors == 0) $display("PASS: %0d words transferred in order", N);
        else             $display("DONE with %0d errors", errors);
        $finish;
    end

    always @(posedge wclk) if (wfull) saw_full = 1;
    always @(posedge rclk) if (rempty && rcount > 0) saw_empty = 1;

    // Watchdog
    initial begin
        #200000;
        $display("TIMEOUT: simulation stuck");
        $finish;
    end

    initial begin
        $dumpfile("async_fifo.vcd");
        $dumpvars(0, tb_async_fifo);
    end
endmodule
