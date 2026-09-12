`include "command_code.h"
`timescale 1ns/100ps

module fifo_read_fsm(sclk, presetn, data_direction, len_reg, start, byte_req, ren);
input sclk, presetn, start, byte_req;

input [8:0] len_reg;
input data_direction;
output reg ren;

localparam idle = 0, data_read = 1;
reg current_state, next_state;
reg [8:0] count_bytes_sent;

always@(posedge sclk or negedge presetn) begin
    if(~presetn) count_bytes_sent <= 0;
    else if(current_state == idle) count_bytes_sent <= 0;
    else if(byte_req) count_bytes_sent <= count_bytes_sent + 1;
end

always@(posedge sclk or negedge presetn) begin
    if(~presetn) current_state <= idle;
    else current_state <= next_state;
end

always@(*) begin
    if(current_state == idle)
        next_state = (data_direction & start) ? data_read : idle;
    else
        next_state = (count_bytes_sent == len_reg) ? idle : data_read;
end

always@(*) begin
    ren = (current_state == data_read) && byte_req;
end
endmodule
