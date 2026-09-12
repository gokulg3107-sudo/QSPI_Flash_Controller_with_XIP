// Simple 2-FF reset synchronizer, one instance per clock domain
module reset_sync(clk, async_rst_n, sync_rst_n);
input  clk, async_rst_n;
output sync_rst_n;
reg rst_meta, rst_sync;
always @(posedge clk or negedge async_rst_n) begin
    if (~async_rst_n) begin
        rst_meta <= 1'b0;
        rst_sync <= 1'b0;
    end else begin
        rst_meta <= 1'b1;
        rst_sync <= rst_meta;
    end
end
assign sync_rst_n = rst_sync;
endmodule
