`timescale 1ns/100ps

module rx_fifo_write_logic(sclk, presetn, valid, dout, wen, fifo_write);
input sclk, presetn, valid;
input [7:0] dout;
output reg wen;
output reg [7:0] fifo_write;

localparam idle = 0, latchdata = 1;
reg current_state, next_state;

always@(posedge sclk or negedge presetn)begin   
    if(~presetn) current_state <= idle;
    else current_state <= next_state;
end


always@(*)begin 
    if(current_state == idle) next_state = valid ? latchdata : idle;
    else next_state = idle;
end
//Whenever valid pulse is received, latch dout and send it to fifo
always@(posedge sclk or negedge presetn)begin
    if(~presetn) fifo_write <= 0;
    else if (current_state == latchdata) fifo_write <= dout;
end
always@(posedge sclk or negedge presetn)begin
    if(~presetn) wen <= 0;
    else wen <= (current_state == latchdata);
end
endmodule
