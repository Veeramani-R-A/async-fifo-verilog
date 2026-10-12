module sync_fifo #(parameter DW = 8, AW = 4)(
    input               clk, rst_n,
    input               wr_en, rd_en,
    input  [DW-1:0]     wdata,
    output reg [DW-1:0] rdata,
    output              full, empty
);
    reg [DW-1:0] mem [0:(1<<AW)-1];
    reg [AW:0] wptr, rptr;   // one extra bit

    assign empty = (wptr == rptr);
    assign full  = (wptr[AW] != rptr[AW]) &&
                   (wptr[AW-1:0] == rptr[AW-1:0]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= 0; rptr <= 0; rdata <= 0;
        end else begin
            if (wr_en && !full) begin
                mem[wptr[AW-1:0]] <= wdata;
                wptr <= wptr + 1;
            end
            if (rd_en && !empty) begin
                rdata <= mem[rptr[AW-1:0]];
                rptr <= rptr + 1;
            end
        end
    end
endmodule

