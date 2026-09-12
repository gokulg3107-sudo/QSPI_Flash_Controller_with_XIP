`include "command_code.h"
`timescale 1ns/100ps

module ahb_slave(hsel, haddr, hwrite, hready, hsize, hburst, htrans, hwdata, hresetn, hclk,
                  hreadyout, hresp, hrdata,
                  indirect_path_busy, xip_path_busy,
                  tag_hit, hit_line, fill_pulse, fill_addr,
                  xip_request, xip_fetch_addr, xip_busy, xip_done, xip_timeout_error, haddr_latched_out, rx_drain_busy);

input hsel, hclk, hresetn, hwrite, hready, rx_drain_busy ;
input [2:0] hsize, hburst;
input [1:0] htrans;
input [31:0] haddr, hwdata;
wire hwdata_used = (hwdata === hwdata);
input indirect_path_busy;
output reg [31:0] hrdata;
output reg hreadyout, hresp;
output wire xip_path_busy;
output wire [31:0] haddr_latched_out;
//prefetch_buffer lives in top now (needs to be visible there for the APB
//write-overlap invalidation check); ahb_slave just consumes/drives its ports
input tag_hit;
input [127:0] hit_line;
output wire fill_pulse;
output wire [23:0] fill_addr;

output reg xip_request;
output wire [23:0] xip_fetch_addr;
input xip_busy, xip_done, xip_timeout_error;
wire xip_busy_used = (xip_busy === xip_busy);

localparam [2:0] idle=3'd0, check_prefetch_buffer=3'd1, data_tag_hit=3'd2,
                  write_reject=3'd3, wait_engine=3'd4, fetch_wait=3'd5, fill_prefetch_buffer=3'd6;
reg [2:0] current_state, next_state;

//address phase latch -- haddr/hsize/hburst/hwrite only stable during the
//accepting cycle, must latch for use through the following data phase
reg [31:0] haddr_latched;
reg [2:0]  hsize_latched, hburst_latched;
reg        hwrite_latched;

wire addr_phase_accept = hsel & (htrans == `htrans_nonseq | htrans == `htrans_seq) & hready;

always@(posedge hclk or negedge hresetn)begin
        if(~hresetn) begin
                haddr_latched  <= 0;
                hsize_latched  <= 0;
                hburst_latched <= 0;   //reserved for future prefetch-ahead prediction (multi-line stretch goal), unused here
                hwrite_latched <= 0;
        end
        else if(addr_phase_accept & hwdata_used & xip_busy_used) begin
                haddr_latched  <= haddr;
                hsize_latched  <= hsize;
                hburst_latched <= hburst;
                hwrite_latched <= hwrite;
        end
end

always@(posedge hclk or negedge hresetn)begin
        if(~hresetn) current_state <= idle;
        else current_state <= next_state;
end

always@(*)begin
        case(current_state)
        idle: next_state = (hsel & htrans == `htrans_nonseq & hready) ? check_prefetch_buffer : idle;

        check_prefetch_buffer: begin
                if(hwrite_latched) next_state = write_reject;         //XIP is read-only
                else if(tag_hit) next_state = data_tag_hit;
                else next_state = wait_engine;
        end

        write_reject: next_state = idle;

        data_tag_hit: begin
                if(htrans == `htrans_busy) next_state = data_tag_hit;
                else if(~hready) next_state = data_tag_hit;            //frozen mid-stall, not a new transfer
                else if(hsel & (htrans == `htrans_nonseq | htrans == `htrans_seq)) next_state = check_prefetch_buffer;
                else next_state = idle;
        end
        wait_engine: next_state = (indirect_path_busy | rx_drain_busy) ? wait_engine : fetch_wait;   //APB wins on conflict

        //xip_command_engine runs the RDSR-poll + QIOR sequence internally;
        //falls through on clean done or timeout -- a stuck WIP must not
        //wedge the AHB bus forever
        fetch_wait: next_state = (xip_done | xip_timeout_error) ? fill_prefetch_buffer : fetch_wait;

        fill_prefetch_buffer: next_state = check_prefetch_buffer;

        default: next_state = idle;
        endcase
end

always@(*)begin
        xip_request = (current_state == fetch_wait);
end
assign xip_fetch_addr = haddr_latched[23:0] & ~24'hF;   //line-aligned base, WRAP4 requirement
assign fill_pulse = (current_state == fill_prefetch_buffer);
assign fill_addr  = xip_fetch_addr;

always@(*)begin
        case(current_state)
        idle, data_tag_hit, fill_prefetch_buffer, write_reject: hreadyout = 1;
        default: hreadyout = 0;
        endcase
end
assign haddr_latched_out = haddr_latched;
//HRESP: ERROR on write-to-XIP attempt, or on WIP-poll timeout during the
//fetch that produced the current hit. NOTE: real AHB ERROR response needs
//a 2-phase HREADYOUT sequence per spec -- this is a single-cycle
//placeholder, verify against ARM_IHI0033A before signoff.
reg fetch_had_timeout;
always@(posedge hclk or negedge hresetn)begin
        if(~hresetn) fetch_had_timeout <= 0;
        else if(current_state == fetch_wait && xip_timeout_error) fetch_had_timeout <= 1;
        else if(current_state == fill_prefetch_buffer) fetch_had_timeout <= 0;
end

always@(*)begin
        hresp = (current_state == write_reject) ? 1'b1
              : (current_state == data_tag_hit && fetch_had_timeout) ? 1'b1
              : 1'b0;
end

//HRDATA mux -- byte/halfword/word extraction from the 128-bit line.
//Assumes naturally-aligned accesses; no explicit unaligned-access guard
//(flagged as open item).
wire [3:0] byte_off = haddr_latched[3:0];
always@(*)begin
        case(hsize_latched)
        3'd0: hrdata = {24'd0, hit_line[byte_off*8 +: 8]};                  //byte
        3'd1: hrdata = {16'd0, hit_line[{byte_off[3:1],1'b0}*8 +: 16]};     //halfword
        3'd2: hrdata = hit_line[{byte_off[3:2],2'b00}*8 +: 32];             //word
        default: hrdata = hit_line[{byte_off[3:2],2'b00}*8 +: 32];          //unsupported size, default word
        endcase
end

assign xip_path_busy = (current_state == fetch_wait);

endmodule
