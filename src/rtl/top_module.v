`include "command_code.h"
`timescale 1ns/100ps

module top_module(sclk, psel, penable, pclk, presetn, pwrite, paddr, pwdata, pready, pslverr, cmd_reg_sync, len_reg_sync, dummy_reg_sync, addr_reg_sync, start_toggle, start_out, busy_reg, rx_read_data, cs, si, so, wp, sio3, transmission_completed, indirect_path_busy, hsel, haddr, hwrite, hready, hsize, hburst, htrans, hwdata, hreadyout, hresp, hrdata, prdata);

input psel, penable, sclk, pclk, presetn, pwrite;
input [31:0] paddr, pwdata;

output wire pready;
output wire pslverr;

//  AHB-Lite XIP port bank (new top-level ports) 
input hsel, hwrite, hready;
input [2:0] hsize, hburst;
input [1:0] htrans;
input [31:0] haddr, hwdata;
output wire hreadyout, hresp;
output wire [31:0] hrdata;

//  APB read data
output wire [31:0] prdata;

//  APB / register bank 
wire [7:0] cmd_reg;
wire [23:0] addr_reg;
wire [4:0] dummy_reg;
wire [8:0] len_reg;
wire [7:0] tx_fifo_data;
output wire [7:0] cmd_reg_sync;
output wire [8:0] len_reg_sync;
wire [7:0] tx_fifo_reg;
wire tx_fifo_wr_pulse;
output wire start_toggle;
output wire busy_reg;
output wire [23:0] addr_reg_sync;
output wire [4:0] dummy_reg_sync;
output wire start_out;

output wire transmission_completed, indirect_path_busy;
wire rx_wen;
wire [7:0] rx_fifo_write_data;
wire rx_full, rx_empty;   //declared but unused, see notes
wire [7:0] rx_fifo_read_data;
wire rx_ren;
output wire [7:0] rx_read_data;
wire [9:0] transfer_config_reg;
wire [9:0] transfer_config_reg_sync;

wire presetn_pclk, presetn_sclk;
reset_sync u_rst_pclk (.clk(pclk), .async_rst_n(presetn), .sync_rst_n(presetn_pclk));
reset_sync u_rst_sclk (.clk(sclk), .async_rst_n(presetn), .sync_rst_n(presetn_sclk));

//  Indirect-path status (pclk domain) 
reg  start_toggle_d;
always@(posedge pclk or negedge presetn) begin
    if(~presetn) start_toggle_d <= 1'b0;
    else         start_toggle_d <= start_toggle;
end
wire start_pulse_pclk = start_toggle ^ start_toggle_d;

assign busy_reg = indirect_path_busy;
wire [7:0] mode_byte_reg, mode_data_reg_sync;
wire qspi_busy_status, qspi_done_status;

//  XIP / AHB path 
wire xip_path_busy;
wire tag_hit_xip, current_valid_xip;
wire [19:0] current_tag_xip;
wire [127:0] hit_line, xip_line_data;
wire fill_pulse, xip_done, xip_busy_unused, xip_timeout_error;
wire [23:0] fill_addr, xip_fetch_addr;
wire xip_request;
wire [31:0] haddr_latched_xip;

wire [7:0] xip_cmd_reg, xip_mode_reg;
wire [23:0] xip_addr_reg;
wire [4:0] xip_dummy_reg;
wire [8:0] xip_len_reg;
wire [9:0] xip_tcfg_reg;
wire xip_start_toggle;
reg  xip_start_toggle_d;
always@(posedge pclk or negedge presetn_pclk)begin
        if(~presetn_pclk) xip_start_toggle_d <= 0;
        else xip_start_toggle_d <= xip_start_toggle;
end

//  APB write-overlap invalidation (feeds prefetch_buffer below) 
wire is_write_class_cmd = transfer_config_reg[`data_direction] & transfer_config_reg[`addr_phase_enable];
reg apb_write_pending;
reg [23:0] apb_write_addr_latched;
always@(posedge pclk or negedge presetn_pclk)begin
        if(~presetn_pclk) begin
                apb_write_pending <= 0;
                apb_write_addr_latched <= 0;
        end
        else if(start_pulse_pclk & is_write_class_cmd) begin
                apb_write_pending <= 1;
                apb_write_addr_latched <= addr_reg;
        end
        else if(transmission_completed) apb_write_pending <= 0;
end
wire apb_write_done_pulse = apb_write_pending & transmission_completed;

wire is_erase_cmd = (cmd_reg == `sector_erase) | (cmd_reg == `block_erase);
wire [23:0] erase_range_mask = (cmd_reg == `block_erase)  ? 24'h00FFFF
                              : (cmd_reg == `sector_erase) ? 24'h000FFF
                              : 24'h0000FF;
wire [23:0] erase_base = apb_write_addr_latched & ~erase_range_mask;
wire [23:0] tag_addr   = {current_tag_xip, 4'd0};
wire addr_overlaps_tag = is_erase_cmd
                        ? ((tag_addr & ~erase_range_mask) == erase_base)
                        : (apb_write_addr_latched[23:4] == current_tag_xip);
wire invalidate_pulse = apb_write_done_pulse & current_valid_xip & addr_overlaps_tag;

prefetch_buffer #(.LINE_SIZE(16), .ADDR_WIDTH(24), .OFFSET_BITS(4)) prefetch(
        .pclk(pclk), .presetn(presetn_pclk),
        .lookup_addr(haddr_latched_xip[23:0]),   //FIX: latched, not raw haddr
        .tag_hit(tag_hit_xip),
        .hit_line(hit_line),
        .current_tag(current_tag_xip), .current_valid(current_valid_xip),
        .fill_pulse(fill_pulse), .fill_addr(fill_addr), .fill_data(xip_line_data),
        .invalidate_pulse(invalidate_pulse)
);

reg [2:0] rx_drain_settle;
wire rx_drain_busy = |rx_drain_settle;
ahb_slave xip_slave(
        .hsel(hsel), .haddr(haddr), .hwrite(hwrite), .hready(hready),
        .hsize(hsize), .hburst(hburst), .htrans(htrans), .hwdata(hwdata),
        .hresetn(presetn_pclk), .hclk(pclk),
        .hreadyout(hreadyout), .hresp(hresp), .hrdata(hrdata),
        .haddr_latched_out(haddr_latched_xip),
        .indirect_path_busy(indirect_path_busy), .xip_path_busy(xip_path_busy),
        .rx_drain_busy(rx_drain_busy),          //NEW
        .tag_hit(tag_hit_xip), .hit_line(hit_line),
        .fill_pulse(fill_pulse), .fill_addr(fill_addr),
        .xip_request(xip_request), .xip_fetch_addr(xip_fetch_addr),
        .xip_busy(xip_busy_unused), .xip_done(xip_done), .xip_timeout_error(xip_timeout_error)
);

wire rx_byte_ready;
wire rx_byte_ready_apb = rx_byte_ready & ~xip_path_busy;
wire rx_byte_ready_xip = rx_byte_ready & xip_path_busy;
xip_command_engine xip_engine(
        .pclk(pclk), .presetn(presetn_pclk),
        .request(xip_request), .fetch_addr(xip_fetch_addr),
        .busy(xip_busy_unused), .done(xip_done), .timeout_error(xip_timeout_error), .line_data(xip_line_data),
        .xip_cmd_reg(xip_cmd_reg), .xip_addr_reg(xip_addr_reg), .xip_dummy_reg(xip_dummy_reg),
        .xip_len_reg(xip_len_reg), .xip_tcfg_reg(xip_tcfg_reg), .xip_mode_reg(xip_mode_reg),
        .xip_start_toggle(xip_start_toggle),
        .rx_read_data(rx_read_data), .rx_byte_ready_xip(rx_byte_ready_xip)
);

//  domain_crossing now synchronizes APB's and XIP's start toggles
//  independently and latches whichever owner's register bank corresponds
//  to the pulse that actually fired (see domain_crossing.v header comment
//  for why level-muxing two free-running toggles ahead of one synchronizer
//  is unsafe -- it let a stale APB register bank get launched into the
//  shared engine at an ownership handoff boundary).
//
//  rx_fifo_read_logic still needs a "which owner is this transfer for"
//  signal in pclk domain; that is safe to derive from xip_path_busy here
//  because ownership only changes at transfer boundaries (never mid
//  data-phase), unlike the sclk-domain toggle mux above which could
//  glitch on any cycle.
wire [8:0] rx_len_in = xip_path_busy ? xip_len_reg : len_reg;
wire rx_start_pulse_in = xip_path_busy ? (xip_start_toggle ^ xip_start_toggle_d) : start_pulse_pclk;
wire rx_data_direction_in = xip_path_busy ? xip_tcfg_reg[`data_direction] : transfer_config_reg[`data_direction];

//gate rx_byte_ready fanout -- prevents APB and XIP from seeing each
//other's captured bytes when the shared RX chain drains for either path

//  APB slave 
apb_slave slave(
    .qspi_busy(qspi_busy_status),
    .transmission_completed(transmission_completed),
    .indirect_path_busy(indirect_path_busy),
    .xip_path_busy(xip_path_busy),
    .start_toggle(start_toggle),
    .rx_fifo_dataout(rx_read_data),
    .psel(psel), .penable(penable), .paddr(paddr), .pwdata(pwdata), .pwrite(pwrite),
    .pready(pready), .pslverr(pslverr), .prdata(prdata),
    .cmd_reg(cmd_reg), .addr_reg(addr_reg), .dummy_reg(dummy_reg),
    .transfer_config_reg(transfer_config_reg),
    .pclk(pclk), .presetn(presetn_pclk),
    .len_reg(len_reg), .tx_fifo_data(tx_fifo_reg),
    .rx_byte_ready(rx_byte_ready_apb),   //FIX: gated, was raw rx_byte_ready
    .tx_fifo_wr_pulse(tx_fifo_wr_pulse), .mode_data_reg(mode_byte_reg)
);

//  Indirect-mode status decoder (pclk domain) 
// FIX: use the pipeline-compensated done pulse, not the immediate one --
// qspi_status.done_delayed already accounts for the rx write-latch(2) +
// fifo write(1) + gray-ptr register(1) pipeline the last RX byte still has
// to cross before it's visible on the pclk side. Wiring the immediate
// qspi_done here let indirect_path_busy drop (and rx_fifo_empty read back
// as genuinely empty) up to 4 sclk cycles before the last byte had
// actually landed, so every last-byte readback was stale by one byte.
indirect_mode_status_decoder indirect_status(
    .pclk(pclk), .presetn(presetn_pclk),
    .qspi_done(qspi_done_status_delayed),
    .start(start_pulse_pclk),
    .indirect_path_busy(indirect_path_busy),
    .transmission_completed(transmission_completed)
);

//  pclk -> sclk domain crossing 
domain_crossing cdc(
    .apb_start(start_toggle),
    .apb_cmd_reg(cmd_reg), .apb_addr_reg(addr_reg), .apb_dummy_reg(dummy_reg),
    .apb_len_reg(len_reg), .apb_mode_data_reg(mode_byte_reg),
    .apb_transfer_config_reg(transfer_config_reg),
    .xip_start(xip_start_toggle),
    .xip_cmd_reg(xip_cmd_reg), .xip_addr_reg(xip_addr_reg), .xip_dummy_reg(xip_dummy_reg),
    .xip_len_reg(xip_len_reg), .xip_mode_data_reg(xip_mode_reg),
    .xip_transfer_config_reg(xip_tcfg_reg),
    .start_out(start_out),
    .sclk(sclk), .presetn(presetn_sclk),
    .cmd_reg_sync(cmd_reg_sync), .addr_reg_sync(addr_reg_sync),
    .transfer_config_reg_sync(transfer_config_reg_sync),
    .dummy_reg_sync(dummy_reg_sync), .len_reg_sync(len_reg_sync), .mode_data_reg_sync(mode_data_reg_sync)
);

//  RX path 
output cs;
inout si, so, wp, sio3;
wire valid;
wire [7:0] dout;

//  TX path 
wire tx_wen;
wire [7:0] fifo_data_in;
wire tx_ren;
wire tx_full, tx_empty;
wire [7:0] fifo_read;
wire tx_data_req;

//  TX FIFO chain (firmware -> flash) 
fifo_write_fsm tx_write_logic(pclk, presetn_pclk, tx_fifo_reg, tx_fifo_wr_pulse, tx_wen, fifo_data_in);
wire tx_fifo_empty_unused;
async_fifo #(.ADDR_WIDTH(8)) tx_fifo_module(pclk, tx_wen, presetn_pclk, fifo_data_in, sclk, tx_ren, presetn_sclk, fifo_read, tx_fifo_empty_unused);
fifo_read_fsm tx_read_logic(sclk, presetn_sclk, transfer_config_reg_sync[`data_direction], len_reg_sync, start_out, tx_data_req, tx_ren);

qspi_flash_controller qspi_flash(
    .sclk(sclk), .presetn(presetn_sclk),
    .cmd_reg(cmd_reg_sync), .addr_reg(addr_reg_sync), .dummy_reg(dummy_reg_sync), .len_reg(len_reg_sync),
    .data_reg(fifo_read),
    .mode_reg(mode_data_reg_sync),
    .transfer_config_reg(transfer_config_reg_sync),
    .start(start_out),
    .cs(cs), .si(si), .so(so), .wp(wp), .sio3(sio3),
    .dout(dout), .valid(valid), .tx_data_req(tx_data_req)
);

rx_fifo_write_logic rx_write_logic(sclk, presetn_sclk, valid, dout, rx_wen, rx_fifo_write_data);
wire rx_fifo_empty;
//  RX drain settle guard for XIP arbitration (see ahb_slave.rx_drain_busy)
// indirect_path_busy drops on the qspi engine's "done" pulse (cs deassert),
// but the RX FIFO can still be draining the last few APB bytes for several
// pclk cycles after that. XIP stealing the shared engine here would issue
// its own RDSR start_pulse into the same rx_fifo_read_logic drain FSM,
// resetting count_bytes_read mid-stream and truncating the APB read (this
// is exactly what was happening in the concurrent-QOR test). Hold XIP off
// until the FIFO has read empty for 3 straight pclk cycles.
always@(posedge pclk or negedge presetn_pclk)begin
        if(~presetn_pclk) rx_drain_settle <= 3'b111;
        else if(~rx_fifo_empty) rx_drain_settle <= 3'b111;
        else rx_drain_settle <= {1'b0, rx_drain_settle[2:1]};
end
async_fifo #(.ADDR_WIDTH(5)) rx_fifo_module(sclk, rx_wen, presetn_sclk, rx_fifo_write_data, pclk, rx_ren, presetn_pclk, rx_fifo_read_data, rx_fifo_empty);

rx_fifo_read_logic rx_read_logic(
    .pclk(pclk), .presetn(presetn_pclk),
    .start_pulse(rx_start_pulse_in),
    .fifo_empty(rx_fifo_empty),
    .ren(rx_ren),
    .read_data(rx_read_data),
    .fifo_data(rx_fifo_read_data),
    .len_reg(rx_len_in),
    .data_direction(rx_data_direction_in),   // reflects current owner (safe: only changes at transfer boundaries)
    .rx_byte_ready(rx_byte_ready)
);

qspi_status status(sclk, presetn_sclk, cs, qspi_busy_status, qspi_done_status, qspi_done_status_delayed);
endmodule


