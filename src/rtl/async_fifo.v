`timescale 1ns/100ps

module async_fifo #(parameter ADDR_WIDTH = 5) (wclk, wen, wrst, write_datain, rclk, ren, rrst, read_dataout, empty);
input wclk, wen, wrst, rclk, ren, rrst;
output wire empty;
wire full;
input [7:0] write_datain;
output reg [7:0] read_dataout;
integer i;
reg [7:0] fifo_register [(1<<ADDR_WIDTH)-1:0];
wire [ADDR_WIDTH:0] b_wptr, g_wptr, b_rptr, g_rptr;

write_pointer_handler #(.ADDR_WIDTH(ADDR_WIDTH)) w1(wclk, wen, wrst, g_wptr, b_wptr, g_rptr, full);
read_pointer_handler  #(.ADDR_WIDTH(ADDR_WIDTH)) w2(rclk, ren, rrst, g_rptr, b_rptr, g_wptr, empty);

always@(posedge wclk or negedge wrst)begin
        if(!wrst) for(i = 0; i < (1<<ADDR_WIDTH); i = i + 1) fifo_register[i] <= 0;
        else if(wen & !full) fifo_register[b_wptr[ADDR_WIDTH-1:0]] <= write_datain;
end
always@(posedge rclk or negedge rrst)begin
        if(!rrst) read_dataout <= 0;
        else if(ren & !empty) read_dataout <= fifo_register[b_rptr[ADDR_WIDTH-1:0]];
end
endmodule


module read_pointer_handler #(parameter ADDR_WIDTH = 5) (rclk, ren, rrst, g_rptr, b_rptr, g_wptr, empty);
input rclk, ren, rrst;
input [ADDR_WIDTH:0] g_wptr;
output reg [ADDR_WIDTH:0] b_rptr, g_rptr;
output empty;
reg [ADDR_WIDTH:0] g_wptr_sync, sync1;

//Dual rank synchronizer
always@(posedge rclk or negedge rrst)begin
        if(!rrst) sync1 <= 0;
        else sync1 <= g_wptr;
end
always@(posedge rclk or negedge rrst)begin
        if(!rrst) g_wptr_sync <= 0;
        else g_wptr_sync <= sync1;
end

//Read pointer management
always@(posedge rclk or negedge rrst)begin
        if(~rrst) b_rptr <= 0;
        else if (ren & !empty) b_rptr <= b_rptr + 1;
end

wire [ADDR_WIDTH:0] g_rptr_temp;
//Conversion of binary to gray coded read pointer for domain crossing to write
//pointer handler
assign g_rptr_temp = b_rptr ^ (b_rptr >> 1);

//Latching gray coded read pointer for domain crossing because directly
//transmitting combo block output to different domain can cause glitch
always@(posedge rclk or negedge rrst)begin
        if(!rrst) g_rptr <= 0;
        else g_rptr <= g_rptr_temp;
end

reg [ADDR_WIDTH:0] b_wptr;
//Convert synchronized gray coded write pointer to binary coded.
//Was a manually unrolled XOR chain at fixed width -- switched to a
//generate loop here since this module is now parameterized across two
//different widths (TX=9b, RX=6b) from the same source. Functionally
//identical to the manual chain: b_wptr[MSB] = g_wptr_sync[MSB], then
//each lower bit XORs the previous binary bit with the corresponding gray bit.
integer i;
always@(*)begin
        b_wptr[ADDR_WIDTH] = g_wptr_sync[ADDR_WIDTH];
        for(i = ADDR_WIDTH-1; i >= 0; i = i - 1)
                b_wptr[i] = b_wptr[i+1] ^ g_wptr_sync[i];
end

//Driving empty signal
assign empty = (b_wptr[ADDR_WIDTH] == b_rptr[ADDR_WIDTH]) & (b_wptr[ADDR_WIDTH-1:0] == b_rptr[ADDR_WIDTH-1:0]);
endmodule


module write_pointer_handler #(parameter ADDR_WIDTH = 5) (wclk, wen, wrst, g_wptr, b_wptr, g_rptr, full);
input wclk, wen, wrst;
input [ADDR_WIDTH:0] g_rptr;
output reg [ADDR_WIDTH:0] g_wptr, b_wptr;
reg [ADDR_WIDTH:0] sync1, g_rptr_sync;
output wire full;
reg [ADDR_WIDTH:0] b_rptr;

always@(posedge wclk or negedge wrst)begin
        if(!wrst) b_wptr <= 0;
        else if(wen & !full) b_wptr <= b_wptr + 1;
end

wire [ADDR_WIDTH:0] g_wptr_temp;
assign g_wptr_temp = b_wptr ^ (b_wptr >> 1);

always@(posedge wclk or negedge wrst)begin
        if(!wrst) g_wptr <= 0;
        else g_wptr <= g_wptr_temp;
end

//Dual rank synchronizer for gray coded read pointer from rclk domain
always@(posedge wclk or negedge wrst)begin
        if(!wrst) sync1 <= 0;
        else sync1 <= g_rptr;
end
always@(posedge wclk or negedge wrst)begin
        if(!wrst) g_rptr_sync <= 0;
        else g_rptr_sync <= sync1;
end

//Conversion of synchronized gray coded read pointer to binary coded
//(same generate-loop rationale as read_pointer_handler above)
integer i;
always@(*)begin
        b_rptr[ADDR_WIDTH] = g_rptr_sync[ADDR_WIDTH];
        for(i = ADDR_WIDTH-1; i >= 0; i = i - 1)
                b_rptr[i] = b_rptr[i+1] ^ g_rptr_sync[i];
end

assign full = (b_rptr[ADDR_WIDTH] != b_wptr[ADDR_WIDTH]) & (b_wptr[ADDR_WIDTH-1:0] == b_rptr[ADDR_WIDTH-1:0]);
endmodule
