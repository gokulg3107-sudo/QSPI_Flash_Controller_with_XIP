`include "command_code.h"
`timescale 1ns/100ps
module apb_slave(xip_path_busy, qspi_busy, transmission_completed, indirect_path_busy, start_toggle, rx_fifo_dataout, rx_byte_ready, prdata, mode_data_reg, psel, penable, paddr, pwdata, pwrite, pready, pslverr, cmd_reg, addr_reg, dummy_reg, transfer_config_reg, pclk, presetn, len_reg, tx_fifo_data, tx_fifo_wr_pulse);
input psel, penable, pclk, presetn, pwrite, transmission_completed, indirect_path_busy, rx_byte_ready;
input xip_path_busy;   //from ahb_slave, prevents APB starting mid-XIP-fetch
input [31:0] paddr, pwdata;
input [7:0] rx_fifo_dataout;
output reg pready;
output wire pslverr;
input qspi_busy;
//Register bank
output reg [7:0] cmd_reg, mode_data_reg, tx_fifo_data;
output reg [8:0] len_reg;
output reg [23:0] addr_reg;
output reg [4:0] dummy_reg;
output reg [31:0] prdata;

reg [1:0] ctrl_reg;
//format of transfer_config -> {data_io_width[1:0], addr[1:0], addr_bytes, direction, addr_en, data_en, mode_byte_en, dummy_en}
output reg [9:0] transfer_config_reg;
reg [7:0] read_rx_fifo_data;
reg [2:0] qspi_transfer_status_register;  // {transmission_completed, indirect_path_busy, rx_data_valid}
reg rx_data_valid;
output wire tx_fifo_wr_pulse;
localparam [1:0] idle = 2'b00, setup = 2'b01, access_state = 2;
reg [1:0] current_state, next_state;

output reg start_toggle;
wire start;

reg ctrl_reg_prev;
//Whenever firmware assert start flag in control status reg, we detect the low to high transition and send a start signal
//to "domain crossing logic" module to initiate the transmission of data.
assign start = ~ctrl_reg_prev & ctrl_reg[0];

//state transition logic of APB Block
always@(posedge pclk or negedge presetn)begin
        if(!presetn) current_state <= idle;
        else current_state <= next_state;
end

//next state logic of APB 
always@(current_state, psel, penable)begin
        case(current_state)
        idle: next_state = psel ? setup : idle;
        setup: next_state = (psel & penable) ? access_state : setup;
        access_state: next_state = (psel & penable) ? setup : idle;
        default: next_state = idle;
        endcase
end
//Yet to figure out use case of pslverr signal
assign pslverr = 0;
//Send a pulse everytime firmware is writing an input into the "write fifo data" register in the APB register bank. 
//tx_fifo_wr_pulse is used by "fifo_write_fsm" module to assert wen signal to write into the fifo
assign tx_fifo_wr_pulse = (current_state == setup) & pwrite & (paddr[3:0] == `write_fifo_data);
//PREADY logic 
always@(*)begin
        case(current_state)
        idle: pready = 1;
        setup: pready = 1;
        access_state: pready = 1;
        default: pready = 1;
        endcase
end
reg start_pending;
always @(posedge pclk or negedge presetn) begin
    if (~presetn) start_pending <= 1'b0;
    else if (start) start_pending <= 1'b1;
    else if (transmission_completed) start_pending <= 1'b0;
end
reg sync1, qspi_busy_sync;
//Dual rank synchronizer for qspi busy signal received from SCLK domain
always@(posedge pclk or negedge presetn)begin
        if(~presetn) begin
                sync1 <= 0;
                qspi_busy_sync <= 0;
        end
        else begin
                sync1 <= qspi_busy;
                qspi_busy_sync <= sync1;
        end
end
//Read only register for status of qspi transfer.
//QSPI status blocks sends busy and done signal based on status of the transaction of data. The synchronized signals are then
//written into QSPI_TRANSFEFR_STATUS_REGISTER. Firmware reads this register, once it reads a logic high in done flag it starts fetching data
//from rx_fifo_data if any
always@(posedge pclk or negedge presetn)begin
        if(~presetn) begin
                read_rx_fifo_data <= 0;
                rx_data_valid <= 0;
        end
        else begin
                read_rx_fifo_data <= rx_fifo_dataout;   // always mirror, no gating
                if (rx_byte_ready) rx_data_valid <= 1'b1;
                else if (current_state == setup & ~pwrite & paddr[3:0] == `read_fifo_data)
                        rx_data_valid <= 1'b0;          // read-clear
        end
end
always@(posedge pclk or negedge presetn)begin
        if(~presetn) qspi_transfer_status_register <= 0;
        else qspi_transfer_status_register <= {transmission_completed, indirect_path_busy, rx_data_valid};
end

reg xip_wait_pending;
always@(posedge pclk or negedge presetn)begin
        if(!presetn) xip_wait_pending <= 1'b0;
        else if(current_state == setup & pwrite & (paddr[3:0] == `control_signals) &
                pwdata[0] & xip_path_busy & ~indirect_path_busy & ~start_pending)
                xip_wait_pending <= 1'b1;
        else if(xip_wait_pending & ~xip_path_busy) xip_wait_pending <= 1'b0;
end

//latch input if qspi is not busy and on the transition of current state from setup to access
always@(posedge pclk or negedge presetn)begin
        if(!presetn) begin
                cmd_reg <= 0;
                addr_reg <= 0;
                dummy_reg <= 0;
                len_reg <= 0;
                tx_fifo_data <= 0;
                ctrl_reg <= 0;
                ctrl_reg_prev <= 0;
                transfer_config_reg <= 0;
                mode_data_reg <= 0;
                prdata <= 0;
        end
        else begin
                if (ctrl_reg[0]) ctrl_reg <= 0; //Start signal is a self clearing pulse
                else if (xip_wait_pending & ~xip_path_busy & ~indirect_path_busy & ~start_pending) ctrl_reg <= 2'b01;
                else if (current_state == setup & pwrite & (paddr[3:0] == `control_signals) &
                         ~indirect_path_busy & ~start_pending & ~xip_path_busy)
                        ctrl_reg <= pwdata[1:0];

                ctrl_reg_prev <= ctrl_reg[0];

                if (current_state == setup & pwrite) begin
                 case (paddr[3:0])
                 `command_code: if(~indirect_path_busy) cmd_reg <= pwdata[7:0];
                 `address_bytes: if(~indirect_path_busy) addr_reg <= pwdata[23:0];
                 `dummy_cycles_count: if(~indirect_path_busy) dummy_reg <= pwdata[4:0];
                 `length_of_data: if(~indirect_path_busy) len_reg <= pwdata[8:0];
                 `write_fifo_data: tx_fifo_data <= pwdata[7:0];
                 `transfer_config_reg: if(~indirect_path_busy) transfer_config_reg <= pwdata[9:0];
                 `mode_byte: if(~indirect_path_busy) mode_data_reg <= pwdata[7:0];
                 endcase
                end
                else if(current_state == setup & ~pwrite) begin
                        case(paddr[3:0])
                        `read_fifo_data: prdata <= {24'd0, read_rx_fifo_data};
                        `qspi_transfer_status_register: prdata <= {29'd0, qspi_transfer_status_register};
                        default: prdata <= prdata;
                        endcase
                end
        end
end
//Toggle synchronizer for fast to slow clock domain
always@(posedge pclk or negedge presetn) begin
        if(~presetn) start_toggle <= 0;
        else if(start) start_toggle <= ~start_toggle;
        else start_toggle <= start_toggle;
end

endmodule

