`include "command_code.h"
`timescale 1ns/100ps

// Autonomous WIP-poll + QIOR fetch sequencer, pclk domain. Drives its own
// register set which top muxes into the shared domain_crossing/
// qspi_flash_controller inputs whenever xip_path_busy is asserted. Consumes
// rx_read_data/rx_byte_ready_xip -- the gated fanout from top so this never
// sees APB's bytes and APB never sees XIP's (see top-level gating).
//
// Completion is detected by counting rx_byte_ready_xip pulses to the
// expected length (1 for RDSR, 16 for QIOR), not by waiting on a
// transmission_completed/cs-deassert signal -- same reasoning as
// qspi_status's done_delayed margin: byte-count reaching the expected
// value is the authoritative "all data captured" signal.

module xip_command_engine #(parameter MAX_WIP_POLLS = 16'hFFFF) (
    pclk, presetn,
    request, fetch_addr,
    busy, done, timeout_error, line_data,
    xip_cmd_reg, xip_addr_reg, xip_dummy_reg, xip_len_reg, xip_tcfg_reg, xip_mode_reg, xip_start_toggle,
    rx_read_data, rx_byte_ready_xip
);

input pclk, presetn;
input request;                 // level, held by ahb_slave while it wants a line
input [23:0] fetch_addr;       // line-aligned base address

output wire busy;
output wire done;              // one-cycle pulse: clean completion, line_data valid
output reg  timeout_error;      // latched: WIP never cleared within MAX_WIP_POLLS
output reg [127:0] line_data;

output reg [7:0] xip_cmd_reg, xip_mode_reg;
output reg [23:0] xip_addr_reg;
output reg [4:0] xip_dummy_reg;
output reg [8:0] xip_len_reg;
output reg [9:0] xip_tcfg_reg;
output reg xip_start_toggle;

input [7:0] rx_read_data;
input rx_byte_ready_xip;

localparam [2:0] s_idle=3'd0, s_issue_rdsr=3'd1, s_wait_rdsr=3'd2, s_issue_qior=3'd3, s_wait_qior=3'd4, s_done=3'd5;
reg [2:0] state, next_state;

reg [4:0] byte_counter;
reg wip_bit_captured;
reg [15:0] poll_counter;

wire timeout_hit = (state == s_wait_rdsr) && (byte_counter == 5'd1) && (poll_counter >= MAX_WIP_POLLS);

always@(posedge pclk or negedge presetn)begin
    if(~presetn) state <= s_idle;
    else state <= next_state;
end

always@(*)begin
    case(state)
    s_idle:       next_state = request ? s_issue_rdsr : s_idle;
    s_issue_rdsr: next_state = s_wait_rdsr;
    s_wait_rdsr: begin
        if(byte_counter == 5'd1) begin
            if(timeout_hit) next_state = s_done;                          // bail out, don't hang the bus
            else next_state = wip_bit_captured ? s_issue_rdsr : s_issue_qior;
        end
        else next_state = s_wait_rdsr;
    end
    s_issue_qior: next_state = s_wait_qior;
    s_wait_qior:  next_state = (byte_counter == 5'd16) ? s_done : s_wait_qior;
    s_done:       next_state = request ? s_done : s_idle;                 // hold until ahb_slave drops request
    default:      next_state = s_idle;
    endcase
end

assign busy = (state != s_idle);
// clean completion only -- timeout path is reported separately via timeout_error
assign done = (state == s_wait_qior) && (next_state == s_done);

always@(posedge pclk or negedge presetn)begin
    if(~presetn) timeout_error <= 0;
    else if(state == s_wait_rdsr && next_state == s_done && timeout_hit) timeout_error <= 1;
    else if(state == s_idle) timeout_error <= 0;   // cleared once a fresh request begins
end

always@(posedge pclk or negedge presetn)begin
    if(~presetn) poll_counter <= 0;
    else if(state == s_idle) poll_counter <= 0;
    else if(state == s_wait_rdsr && byte_counter == 5'd1 && wip_bit_captured && poll_counter < MAX_WIP_POLLS)
        poll_counter <= poll_counter + 1;
end

always@(posedge pclk or negedge presetn)begin
    if(~presetn) begin
        byte_counter <= 0;
        line_data <= 0;
        wip_bit_captured <= 0;
    end
    else begin
        case(state)
        s_issue_rdsr, s_issue_qior: byte_counter <= 0;   // reset at the start of each step
        s_wait_rdsr: if(rx_byte_ready_xip && byte_counter == 0) begin
            wip_bit_captured <= rx_read_data[0];
            byte_counter <= byte_counter + 1;
        end
        s_wait_qior: if(rx_byte_ready_xip && byte_counter < 16) begin
            line_data[{byte_counter[3:0],3'b000} +: 8] <= rx_read_data;
            byte_counter <= byte_counter + 1;
        end
        endcase
    end
end

//register bank driven to the shared domain_crossing input mux (top level)
always@(posedge pclk or negedge presetn)begin
    if(~presetn) begin
        xip_cmd_reg   <= 0;
        xip_addr_reg  <= 0;
        xip_dummy_reg <= 0;
        xip_len_reg   <= 0;
        xip_tcfg_reg  <= 0;
        xip_mode_reg  <= 0;
        xip_start_toggle <= 0;
    end
    else begin
        case(state)
        s_issue_rdsr: begin
            xip_cmd_reg   <= `read_status_reg;
            xip_addr_reg  <= 24'd0;
            xip_dummy_reg <= 5'd0;
            xip_len_reg   <= 9'd1;
            xip_tcfg_reg  <= `xip_tcfg_rdsr;
            xip_mode_reg  <= 8'd0;
            xip_start_toggle <= ~xip_start_toggle;
        end
        s_issue_qior: begin
            xip_cmd_reg   <= `quad_io_read;
            xip_addr_reg  <= fetch_addr;
            xip_dummy_reg <= `xip_qior_dummy;
            xip_len_reg   <= 9'd16;
            xip_tcfg_reg  <= `xip_tcfg_qior;
            xip_mode_reg  <= `xip_qior_mode;
            xip_start_toggle <= ~xip_start_toggle;
        end
        endcase
    end
end

endmodule
