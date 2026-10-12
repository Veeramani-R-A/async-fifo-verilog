// Dual-port memory: write on wclk, read combinationally
module fifo_mem #(parameter DW=8, AW=4)(
    input wclk, wen,
    input [AW-1:0] waddr, raddr,
    input [DW-1:0] wdata,
    output [DW-1:0] rdata
);
    reg [DW-1:0] mem [0:(1<<AW)-1];
    assign rdata = mem[raddr];
    always @(posedge wclk)
        if (wen) mem[waddr] <= wdata;
endmodule

// Two-flop synchronizer: read pointer into write domain
module sync_r2w #(parameter AW=4)(
    input wclk, wrst_n,
    input [AW:0] rptr,
    output reg [AW:0] wq2_rptr
);
    reg [AW:0] wq1_rptr;
    always @(posedge wclk or negedge wrst_n)
        if (!wrst_n) {wq2_rptr, wq1_rptr} <= 0;
        else         {wq2_rptr, wq1_rptr} <= {wq1_rptr, rptr};
endmodule

// Two-flop synchronizer: write pointer into read domain
module sync_w2r #(parameter AW=4)(
    input rclk, rrst_n,
    input [AW:0] wptr,
    output reg [AW:0] rq2_wptr
);
    reg [AW:0] rq1_wptr;
    always @(posedge rclk or negedge rrst_n)
        if (!rrst_n) {rq2_wptr, rq1_wptr} <= 0;
        else         {rq2_wptr, rq1_wptr} <= {rq1_wptr, wptr};
endmodule

// Write pointer and full flag (write domain)
module wptr_full #(parameter AW=4)(
    input wclk, wrst_n, winc,
    input [AW:0] wq2_rptr,
    output reg wfull,
    output [AW-1:0] waddr,
    output reg [AW:0] wptr          // Gray
);
    reg  [AW:0] wbin;
    wire [AW:0] wbin_next  = wbin + (winc & ~wfull);
    wire [AW:0] wgray_next = (wbin_next >> 1) ^ wbin_next;
    wire wfull_val = (wgray_next ==
                     {~wq2_rptr[AW:AW-1], wq2_rptr[AW-2:0]});

    assign waddr = wbin[AW-1:0];

    always @(posedge wclk or negedge wrst_n)
        if (!wrst_n) begin wbin <= 0; wptr <= 0; wfull <= 0; end
        else begin
            wbin  <= wbin_next;
            wptr  <= wgray_next;
            wfull <= wfull_val;
        end
endmodule

// Read pointer and empty flag (read domain)
module rptr_empty #(parameter AW=4)(
    input rclk, rrst_n, rinc,
    input [AW:0] rq2_wptr,
    output reg rempty,
    output [AW-1:0] raddr,
    output reg [AW:0] rptr          // Gray
);
    reg  [AW:0] rbin;
    wire [AW:0] rbin_next  = rbin + (rinc & ~rempty);
    wire [AW:0] rgray_next = (rbin_next >> 1) ^ rbin_next;
    wire rempty_val = (rgray_next == rq2_wptr);

    assign raddr = rbin[AW-1:0];

    always @(posedge rclk or negedge rrst_n)
        if (!rrst_n) begin rbin <= 0; rptr <= 0; rempty <= 1'b1; end
        else begin
            rbin   <= rbin_next;
            rptr   <= rgray_next;
            rempty <= rempty_val;
        end
endmodule

// Top level
module async_fifo #(parameter DW=8, AW=4)(
    input  wclk, wrst_n, winc,
    input  [DW-1:0] wdata,
    output wfull,
    input  rclk, rrst_n, rinc,
    output [DW-1:0] rdata,
    output rempty
);
    wire [AW-1:0] waddr, raddr;
    wire [AW:0] wptr, rptr, wq2_rptr, rq2_wptr;

    sync_r2w #(AW) u_r2w (.wclk(wclk), .wrst_n(wrst_n),
                          .rptr(rptr), .wq2_rptr(wq2_rptr));
    sync_w2r #(AW) u_w2r (.rclk(rclk), .rrst_n(rrst_n),
                          .wptr(wptr), .rq2_wptr(rq2_wptr));
    fifo_mem #(DW, AW) u_mem (.wclk(wclk), .wen(winc & ~wfull),
                          .waddr(waddr), .raddr(raddr),
                          .wdata(wdata), .rdata(rdata));
    wptr_full #(AW) u_wptr (.wclk(wclk), .wrst_n(wrst_n), .winc(winc),
                          .wq2_rptr(wq2_rptr), .wfull(wfull),
                          .waddr(waddr), .wptr(wptr));
    rptr_empty #(AW) u_rptr (.rclk(rclk), .rrst_n(rrst_n), .rinc(rinc),
                          .rq2_wptr(rq2_wptr), .rempty(rempty),
                          .raddr(raddr), .rptr(rptr));
endmodule
