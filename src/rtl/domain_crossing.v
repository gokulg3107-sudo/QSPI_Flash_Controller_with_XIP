`timescale 1ns/100ps

// Crosses a start request plus its associated register bank from pclk into
// sclk. Two independent owners can request a transfer -- APB (firmware,
// indirect mode) and XIP (the autonomous engine in xip_command_engine) --
// and each owner drives its own free-running toggle bit in pclk domain.
module domain_crossing(
    // APB-owned register bank + start toggle (pclk domain)
    apb_start, apb_cmd_reg, apb_addr_reg, apb_dummy_reg, apb_len_reg,
    apb_mode_data_reg, apb_transfer_config_reg,
    // XIP-owned register bank + start toggle (pclk domain)
    xip_start, xip_cmd_reg, xip_addr_reg, xip_dummy_reg, xip_len_reg,
    xip_mode_data_reg, xip_transfer_config_reg,
    // sclk-domain outputs (shared engine inputs)
    start_out, sclk, presetn,
    cmd_reg_sync, addr_reg_sync, transfer_config_reg_sync,
    dummy_reg_sync, len_reg_sync, mode_data_reg_sync
);

input sclk, presetn;

input apb_start, xip_start;

input [7:0]  apb_cmd_reg, apb_mode_data_reg;
input [8:0]  apb_len_reg;
input [23:0] apb_addr_reg;
input [4:0]  apb_dummy_reg;
input [9:0]  apb_transfer_config_reg;

input [7:0]  xip_cmd_reg, xip_mode_data_reg;
input [8:0]  xip_len_reg;
input [23:0] xip_addr_reg;
input [4:0]  xip_dummy_reg;
input [9:0]  xip_transfer_config_reg;

output reg [7:0] cmd_reg_sync, mode_data_reg_sync;
output reg [8:0] len_reg_sync;
output reg [23:0] addr_reg_sync;
output reg [4:0] dummy_reg_sync;
output reg [9:0] transfer_config_reg_sync;
output reg start_out;

localparam [1:0] idle = 2'd0, latch_inputdata = 2'd1, send_data = 2'd2;
reg [1:0] current_state, next_state;

// APB toggle: independent 3-stage synchronizer + edge detector
reg apb_sync1, apb_sync2, apb_sync3, apb_prev;
always@(posedge sclk or negedge presetn)begin
    if(~presetn)begin
        apb_sync1 <= 0; apb_sync2 <= 0; apb_sync3 <= 0;
    end
    else begin
        apb_sync1 <= apb_start;
        apb_sync2 <= apb_sync1;
        apb_sync3 <= apb_sync2;
    end
end
wire apb_sync_toggle = apb_sync2 ^ apb_sync3;
always@(posedge sclk or negedge presetn)begin
    if(~presetn) apb_prev <= 0;
    else apb_prev <= apb_sync_toggle;
end
wire apb_pulse = apb_sync_toggle & ~apb_prev;

// XIP toggle: independent 3-stage synchronizer + edge detector
// (identical structure, entirely separate state -- this is the point)
reg xip_sync1, xip_sync2, xip_sync3, xip_prev;
always@(posedge sclk or negedge presetn)begin
    if(~presetn)begin
        xip_sync1 <= 0; xip_sync2 <= 0; xip_sync3 <= 0;
    end
    else begin
        xip_sync1 <= xip_start;
        xip_sync2 <= xip_sync1;
        xip_sync3 <= xip_sync2;
    end
end
wire xip_sync_toggle = xip_sync2 ^ xip_sync3;
always@(posedge sclk or negedge presetn)begin
    if(~presetn) xip_prev <= 0;
    else xip_prev <= xip_sync_toggle;
end
wire xip_pulse = xip_sync_toggle & ~xip_prev;

// Combined, already-qualified launch pulse. Both being high on the same
// cycle should not happen given upstream arbitration (ahb_slave only
// requests the engine while indirect_path_busy is low); if it ever does,
// APB wins, per the existing "APB wins on conflict" policy.
wire start_pulse = apb_pulse | xip_pulse;

// Latch which owner's pulse actually fired, captured only on the cycle
// idle decides to move to latch_inputdata -- held stable through
// latch_inputdata so the correct register bank is selected.
reg owner_is_apb;
always@(posedge sclk or negedge presetn)begin
    if(~presetn) owner_is_apb <= 1'b1;
    else if(current_state == idle && start_pulse) owner_is_apb <= apb_pulse; // APB wins ties
end

always@(posedge sclk or negedge presetn)begin
    if(~presetn) current_state <= idle;
    else current_state <= next_state;
end

always@(*)begin
    case(current_state)
        idle: next_state = start_pulse ? latch_inputdata : idle;
        latch_inputdata: next_state = send_data;
        send_data: next_state = idle;
        default: next_state = idle;
    endcase
end

always@(*)begin
    case(current_state)
        idle: start_out = 0;
        latch_inputdata: start_out = 0;
        send_data: start_out = 1;
        default: start_out = 0;
    endcase
end

// Latch inputs from whichever owner's pulse launched this transfer --
// never from a level-based mux of "whoever currently owns the engine".
always@(posedge sclk or negedge presetn) begin
    if(~presetn) begin
        cmd_reg_sync   <= 0;
        addr_reg_sync  <= 0;
        dummy_reg_sync <= 0;
        len_reg_sync   <= 0;
        mode_data_reg_sync <= 0;
        transfer_config_reg_sync <= 0;
    end
    else if (current_state == latch_inputdata) begin
        if (owner_is_apb) begin
            cmd_reg_sync   <= apb_cmd_reg;
            addr_reg_sync  <= apb_addr_reg;
            dummy_reg_sync <= apb_dummy_reg;
            len_reg_sync   <= apb_len_reg;
            mode_data_reg_sync <= apb_mode_data_reg;
            transfer_config_reg_sync <= apb_transfer_config_reg;
        end
        else begin
            cmd_reg_sync   <= xip_cmd_reg;
            addr_reg_sync  <= xip_addr_reg;
            dummy_reg_sync <= xip_dummy_reg;
            len_reg_sync   <= xip_len_reg;
            mode_data_reg_sync <= xip_mode_data_reg;
            transfer_config_reg_sync <= xip_transfer_config_reg;
        end
    end
end

endmodule
