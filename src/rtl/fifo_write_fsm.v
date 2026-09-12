`include "command_code.h"
`timescale 1ns/100ps

module fifo_write_fsm(pclk, presetn, write_data, wr_pulse, wen, fifo_data_in);
input pclk, presetn, wr_pulse;
input [7:0] write_data;
output reg wen;
output reg [7:0] fifo_data_in;

reg wr_pulse_d;
//Send a pulse whenever a new byte is written into fifo
always@(posedge pclk or negedge presetn) begin
    if(~presetn) begin
        wr_pulse_d   <= 0;
        wen          <= 0;
        fifo_data_in <= 0;
    end
    else begin
        wr_pulse_d   <= wr_pulse;      // stage 1: catch the pulse
        wen          <= wr_pulse_d;    // stage 2: fire wen one cycle later
        fifo_data_in <= write_data;    // by now tx_fifo_data has settled to the new byte
    end
end
endmodule
