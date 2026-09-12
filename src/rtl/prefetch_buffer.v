`timescale 1ns/100ps

module prefetch_buffer(pclk, presetn, lookup_addr, tag_hit, hit_line, current_tag, current_valid, fill_pulse, fill_addr, fill_data, invalidate_pulse);

parameter LINE_SIZE = 16;
parameter ADDR_WIDTH = 24;
parameter OFFSET_BITS = 4;
localparam TAG_WIDTH = ADDR_WIDTH - OFFSET_BITS;

input pclk, presetn, fill_pulse, invalidate_pulse;
input [ADDR_WIDTH-1:0] lookup_addr, fill_addr;
input [LINE_SIZE*8-1:0] fill_data;
output tag_hit;
output [LINE_SIZE*8-1:0] hit_line;
output [TAG_WIDTH-1:0] current_tag;   // exposed for top's write-overlap invalidation check
output current_valid;

reg valid;
reg [TAG_WIDTH-1:0] tag_reg;
reg [LINE_SIZE*8-1:0] line_data;

wire [TAG_WIDTH-1:0] lookup_tag = lookup_addr[ADDR_WIDTH-1:OFFSET_BITS];

assign tag_hit = valid & (tag_reg == lookup_tag) & (lookup_addr[OFFSET_BITS-1:0] == lookup_addr[OFFSET_BITS-1:0]);
assign hit_line = line_data;
assign current_tag = tag_reg;
assign current_valid = valid;

//invalidate takes priority over fill if both land same cycle -- should
//never happen given arbitration (XIP owns engine during fill, APB can't
//be writing concurrently), safer default regardless
always@(posedge pclk or negedge presetn)begin
        if(~presetn) begin
                valid <= 0;
                tag_reg <= 0;
                line_data <= 0;
        end
        else if(invalidate_pulse) valid <= 0;
        else if(fill_pulse & (fill_addr[OFFSET_BITS-1:0] == fill_addr[OFFSET_BITS-1:0])) begin
                valid <= 1;
                tag_reg <= fill_addr[ADDR_WIDTH-1:OFFSET_BITS];
                line_data <= fill_data;
        end
end

endmodule
