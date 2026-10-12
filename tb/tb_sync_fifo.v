`timescale 1ns/1ps
module tb_sync_fifo;
    parameter DW = 8, AW = 4;
    reg clk = 0, rst_n = 0, wr_en = 0, rd_en = 0;
    reg  [DW-1:0] wdata = 0;
    wire [DW-1:0] rdata;
    wire full, empty;
    integer i, errors = 0;
    reg [DW-1:0] expected [0:(1<<AW)-1];

    sync_fifo #(DW, AW) dut (.clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .rd_en(rd_en), .wdata(wdata),
        .rdata(rdata), .full(full), .empty(empty));

    always #5 clk = ~clk;   // 100 MHz

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_sync_fifo);

        #22 rst_n = 1;
        if (!empty) begin errors = errors + 1; $display("FAIL: not empty after reset"); end

        // Fill the FIFO with 16 values
        for (i = 0; i < 16; i = i + 1) begin
            @(negedge clk);
            wr_en = 1; wdata = i*3 + 1; expected[i] = wdata;
        end
        @(negedge clk); wr_en = 0;
        if (!full) begin errors = errors + 1; $display("FAIL: full not asserted"); end

        // Try one extra write (must be ignored)
        @(negedge clk); wr_en = 1; wdata = 8'hFF;
        @(negedge clk); wr_en = 0;

        // Read everything back and compare
        for (i = 0; i < 16; i = i + 1) begin
            @(negedge clk); rd_en = 1;
            @(posedge clk); #1;
            if (rdata !== expected[i]) begin
                errors = errors + 1;
                $display("FAIL: read %0d expected %0d got %0d", i, expected[i], rdata);
            end
        end
        @(negedge clk); rd_en = 0;
        if (!empty) begin errors = errors + 1; $display("FAIL: empty not asserted"); end

        if (errors == 0) $display("PASS: all checks OK");
        else             $display("DONE with %0d errors", errors);
        $finish;
    end
endmodule
