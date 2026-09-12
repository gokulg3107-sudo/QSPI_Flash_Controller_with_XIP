`include "command_code.h"
`timescale 1ns/100ps

module qspi_flash_controller(sclk, presetn, cmd_reg, addr_reg, dummy_reg, len_reg, data_reg, mode_reg, transfer_config_reg, start, cs, si, so, wp, sio3, dout, valid, tx_data_req);
input sclk, presetn, start;
input [7:0] cmd_reg, data_reg, mode_reg;
input [8:0] len_reg;
input [23:0] addr_reg;
input [4:0] dummy_reg;
input [9:0] transfer_config_reg;
output cs;
output reg valid;
output reg [7:0] dout;
inout si, so, wp, sio3;
output wire tx_data_req;
reg [3:0] io_out, io_oe;
localparam [2:0] idle = 0, opcode_phase = 1, address_phase = 2, mode_phase = 3, dummy_phase = 4, data_phase = 5;
reg [2:0] current_state, next_state;

wire [4:0] address_bits_size;
wire [3:0] io_in;
assign address_bits_size = transfer_config_reg[`addr_byte_count] == 0 ? 5'd23 : 5'd31;

//Counter to keep counts of number of bits of data sent
reg [20:0] count_bits_sent;
always@(posedge sclk or negedge presetn)begin
        if(~presetn) count_bits_sent <= 0;
        else begin
                if (current_state == idle) count_bits_sent <= 0;
                else if(current_state == opcode_phase) begin
                        if(count_bits_sent == 7) count_bits_sent <= 0;
                        else count_bits_sent <= count_bits_sent + 1;
                end
                else if(current_state == address_phase) begin
                        if(transfer_config_reg[`addr_phase_line_width] == 2'd0) begin
				if(count_bits_sent == address_bits_size) count_bits_sent <= 0;
				else count_bits_sent <= count_bits_sent + 1;
			end
                        else if (transfer_config_reg[`addr_phase_line_width] == 2'd1) begin
				if(count_bits_sent == (address_bits_size + 1)/2 - 1) count_bits_sent <= 0; 
				else count_bits_sent <= count_bits_sent + 1;
			end
                        else begin
				if(count_bits_sent == (address_bits_size + 1)/4 - 1) count_bits_sent <= 0;
				else count_bits_sent <= count_bits_sent + 1;
			end
                end
                else if(current_state == mode_phase) begin
                        if(transfer_config_reg[`addr_phase_line_width] == 2'd0) begin
				if(count_bits_sent == 20'd7) count_bits_sent <=  0;
				else  count_bits_sent <= count_bits_sent + 1;
			end
                        else if (transfer_config_reg[`addr_phase_line_width] == 2'd1) begin
				if(count_bits_sent == 20'd3) count_bits_sent <= 0; 
				else count_bits_sent <= count_bits_sent + 1;
			end
                        else begin
				if(count_bits_sent == 20'd1) count_bits_sent <= 0;
				else count_bits_sent <=  count_bits_sent + 1;
			end
                end
                else if(current_state == dummy_phase) begin
                        if(count_bits_sent == dummy_reg) count_bits_sent <= 0;
                        else count_bits_sent <= count_bits_sent + 1;
                end
                else if(current_state == data_phase) begin
                        if(transfer_config_reg[`data_phase_line_width] == 2'd0) begin
				if(count_bits_sent == 8 * len_reg - 1) count_bits_sent <= 0;
				else count_bits_sent <= count_bits_sent + 1;
			end
                        else if (transfer_config_reg[`data_phase_line_width] == 2'd1) begin
				if(count_bits_sent == 4 * len_reg - 1) count_bits_sent <= 0;
				else count_bits_sent <= count_bits_sent + 1;
			end
                        else begin
				if(count_bits_sent == 2 * len_reg - 1) count_bits_sent <= 0;
				else count_bits_sent <= count_bits_sent + 1;
			end
                end
        end
end

//Latch input register and shift them based on transfer phase
reg [7:0] cmd_reg_temp, data_reg_temp, mode_reg_temp;
reg [23:0] addr_reg_temp;
always@(posedge sclk or negedge presetn)begin
        if(~presetn) begin
                cmd_reg_temp <= 0;
                data_reg_temp <= 0;
                mode_reg_temp <= 0;
                addr_reg_temp <= 0;
        end
        else begin
                if(current_state == idle && start) begin
                        cmd_reg_temp <= cmd_reg;
                        addr_reg_temp <= addr_reg;
                        mode_reg_temp <= mode_reg;
                end
                else if(current_state == opcode_phase) begin
                        cmd_reg_temp <= {cmd_reg_temp[6:0] , 1'b0};
                        // Opcode -> data directly (e.g. WRSR 0x01): no address, mode, or dummy
                        // phase ahead, so preload data_reg_temp here or it'll still hold stale data.
                        if (transfer_config_reg[`addr_phase_enable] == 1'b0 &
                            transfer_config_reg[`dummy_phase_enable] == 1'b0 &
                            transfer_config_reg[`mode_phase_enable] == 1'b0)
                                data_reg_temp <= data_reg;
                end
                else if(current_state == address_phase) begin
                        if ( (transfer_config_reg[`addr_phase_line_width]==2'd0 && count_bits_sent == address_bits_size) ||
                             (transfer_config_reg[`addr_phase_line_width]==2'd1 && count_bits_sent == (address_bits_size+1)/2 - 1) ||
                             (transfer_config_reg[`addr_phase_line_width]==2'd2 && count_bits_sent == (address_bits_size+1)/4 - 1) )
                        begin
                                if (transfer_config_reg[`mode_phase_enable]) mode_reg_temp <= mode_reg;
                                else data_reg_temp <= transfer_config_reg[`data_phase_enable] ? data_reg : 8'd0;
                        end
                        else if(transfer_config_reg[`addr_phase_line_width] == 2'd0) addr_reg_temp <= {addr_reg_temp[22:0], 1'b0};
                        else if (transfer_config_reg[`addr_phase_line_width] == 2'd1) addr_reg_temp <= {addr_reg_temp[21:0], 2'd0};
                        else if(transfer_config_reg[`addr_phase_line_width] == 2'd2) addr_reg_temp <= {addr_reg_temp[19:0], 4'd0};
                end
                else if(current_state == mode_phase)begin
                        if ((transfer_config_reg[`addr_phase_line_width]==2'd0 && count_bits_sent==20'd7) ||
                            (transfer_config_reg[`addr_phase_line_width]==2'd1 && count_bits_sent==20'd3) ||
                            (transfer_config_reg[`addr_phase_line_width]==2'd2 && count_bits_sent==20'd1))
                                data_reg_temp <= transfer_config_reg[`data_phase_enable] ? data_reg : 8'd0;

                        if (transfer_config_reg[`addr_phase_line_width] == 2'd0) mode_reg_temp <= {mode_reg_temp[6:0], 1'b0};
                        else if (transfer_config_reg[`addr_phase_line_width] == 2'd1) mode_reg_temp <= {mode_reg_temp[5:0], 2'd0};
                        else if (transfer_config_reg[`addr_phase_line_width] == 2'd2) mode_reg_temp <= {mode_reg_temp[3:0], 4'd0}; 
                end
                else if(current_state == data_phase) begin
                        if ((transfer_config_reg[`data_phase_line_width]==2'd0 && count_bits_sent[2:0]==3'd7) ||
                            (transfer_config_reg[`data_phase_line_width]==2'd1 && count_bits_sent[1:0]==2'd3) ||
                            (transfer_config_reg[`data_phase_line_width]==2'd2 && count_bits_sent[0]==1'b1))
                                data_reg_temp <= data_reg;
                        else if(transfer_config_reg[`data_phase_line_width] == 2'd0) data_reg_temp <= {data_reg_temp[6:0], 1'b0};
                        else if (transfer_config_reg[`data_phase_line_width] == 2'd1) data_reg_temp <= {data_reg_temp[5:0], 2'd0};
                        else if (transfer_config_reg[`data_phase_line_width] == 2'd2) data_reg_temp <= {data_reg_temp[3:0], 4'd0};
                end
                // dummy_phase: no action — data_reg_temp holds whatever was preloaded, untouched.
        end
end

//state transition logic
always@(posedge sclk or negedge presetn)begin
        if(!presetn) current_state <= idle;
        else current_state <= next_state;
end

always@(*)begin
        case(current_state)
        idle: next_state = start ? opcode_phase : idle;
        opcode_phase: begin
                if(count_bits_sent == 7) begin
                        if(transfer_config_reg[`addr_phase_enable]) next_state = address_phase;
                        else if(transfer_config_reg[`mode_phase_enable]) next_state = mode_phase;
                        else if(transfer_config_reg[`dummy_phase_enable]) next_state = dummy_phase;
                        else if(transfer_config_reg[`data_phase_enable]) next_state = data_phase;
                        else next_state = idle;
                end
                else next_state = opcode_phase;
        end
        address_phase: begin
                if ( (transfer_config_reg[`addr_phase_line_width]==2'd0 && count_bits_sent == address_bits_size) ||
                     (transfer_config_reg[`addr_phase_line_width]==2'd1 && count_bits_sent == (address_bits_size+1)/2 - 1) ||
                     (transfer_config_reg[`addr_phase_line_width]==2'd2 && count_bits_sent == (address_bits_size+1)/4 - 1) ) begin
                        if(transfer_config_reg[`mode_phase_enable]) next_state = mode_phase;
                        else if(transfer_config_reg[`dummy_phase_enable]) next_state = dummy_phase;
                        else if(transfer_config_reg[`data_phase_enable]) next_state = data_phase;
                        else next_state = idle;
                end
                else next_state = address_phase;
        end
        mode_phase: begin
               if ((transfer_config_reg[`addr_phase_line_width]==2'd0 && count_bits_sent==20'd7) ||
                    (transfer_config_reg[`addr_phase_line_width]==2'd1 && count_bits_sent==20'd3) ||
                    (transfer_config_reg[`addr_phase_line_width]==2'd2 && count_bits_sent==20'd1)) begin
                        if(transfer_config_reg[`dummy_phase_enable]) next_state = dummy_phase;
                        else if(transfer_config_reg[`data_phase_enable]) next_state = data_phase;
                        else next_state = idle;
                end
                else next_state = mode_phase;
        end
        dummy_phase: begin
                if(count_bits_sent == dummy_reg) begin
                        if(transfer_config_reg[`data_phase_enable]) next_state = data_phase;
                        else next_state = idle;
                end
                else next_state = dummy_phase;
        end
        data_phase: begin
               next_state = ( (transfer_config_reg[`data_phase_line_width]==2'd0 && count_bits_sent == 8*len_reg-1) ||
                               (transfer_config_reg[`data_phase_line_width]==2'd1 && count_bits_sent == 4*len_reg-1) ||
                               (transfer_config_reg[`data_phase_line_width]==2'd2 && count_bits_sent == 2*len_reg-1) )
                             ? idle : data_phase;
        end
        default: next_state = idle;
        endcase
end

assign cs = current_state == idle;
assign si   = io_oe[0] ? io_out[0] : 1'bz;
assign so   = io_oe[1] ? io_out[1] : 1'bz;
assign wp   = io_oe[2] ? io_out[2] : 1'bz;
assign sio3 = io_oe[3] ? io_out[3] : 1'bz;
assign io_in = {sio3, wp, so, si};


always@(*)begin
        case(current_state)
        idle: begin
                io_oe = 4'd0;
                io_out = 4'd0;
        end
        opcode_phase: begin
                io_oe = 4'd1;
                io_out = {3'd0, cmd_reg_temp[7]};
        end
        address_phase: begin
                case(transfer_config_reg[`addr_phase_line_width])
                2'd0: begin io_out = {3'd0, addr_reg_temp[23]}; io_oe = 4'b0001; end
                2'd1: begin io_out = {2'd0, addr_reg_temp[23:22]}; io_oe = 4'b0011; end
                2'd2: begin io_out = addr_reg_temp[23:20]; io_oe = 4'b1111; end
                default: begin io_out = 4'd0; io_oe = 4'b0000; end
                endcase
        end
        mode_phase: begin
                case(transfer_config_reg[`addr_phase_line_width])
                2'd0: begin io_out = {3'd0, mode_reg_temp[7]}; io_oe = 4'b0001; end
                2'd1: begin io_out = {2'd0, mode_reg_temp[7:6]}; io_oe = 4'b0011; end
                2'd2: begin io_out = mode_reg_temp[7:4]; io_oe = 4'b1111; end
                default: begin io_out = 4'd0; io_oe = 4'b0000; end
                endcase
        end
        dummy_phase: begin
    if (transfer_config_reg[`addr_phase_line_width] == 2'd2 &&
        (count_bits_sent == 0 || count_bits_sent == 1)) begin
        io_out = 4'd0;      // both mode-byte nibbles = 0 -> XOR = 0 -> enhance_mode = 0
        io_oe  = 4'b1111;
    end
    else begin
        io_out = 4'd0;
        io_oe  = 4'd0;      // rest of dummy phase, and non-quad commands: float as before
    end
end
        data_phase: begin
                if (transfer_config_reg[`data_direction]) begin
                        case(transfer_config_reg[`data_phase_line_width])
                                2'd0: begin io_out = {3'd0, data_reg_temp[7]}; io_oe = 4'b0001; end
                                2'd1: begin io_out = {2'd0, data_reg_temp[7:6]}; io_oe = 4'b0011; end
                                2'd2: begin io_out = data_reg_temp[7:4]; io_oe = 4'b1111; end
                                default: begin io_out = 4'd0; io_oe = 4'b0000; end
                        endcase
                end
                else begin
                        io_oe  = 4'b0000;
                        io_out = 4'd0;
                end
        end
        default: begin io_out = 4'd0; io_oe = 4'd0; end
        endcase
end


// RX capture: dout/valid, driven only during data_phase with direction==read.
reg [7:0] rx_shift_reg;
always @(posedge sclk or negedge presetn) begin
    if (!presetn) begin
        rx_shift_reg <= 0;
        dout  <= 0;
        valid <= 0;
    end
    else if (current_state == data_phase && ~transfer_config_reg[`data_direction]) begin
        case (transfer_config_reg[`data_phase_line_width])
            2'd0: rx_shift_reg <= {rx_shift_reg[6:0], io_in[1]};
            2'd1: rx_shift_reg <= {rx_shift_reg[5:0], io_in[1:0]};
            2'd2: rx_shift_reg <= {rx_shift_reg[3:0], io_in[3:0]};
            default: rx_shift_reg <= rx_shift_reg;
        endcase
       if ((transfer_config_reg[`data_phase_line_width]==2'd0 && count_bits_sent[2:0]==3'd7) ||
            (transfer_config_reg[`data_phase_line_width]==2'd1 && count_bits_sent[1:0]==2'd3) ||
            (transfer_config_reg[`data_phase_line_width]==2'd2 && count_bits_sent[0]==1'b1)) begin
            case (transfer_config_reg[`data_phase_line_width])
                2'd0: dout <= {rx_shift_reg[6:0], io_in[1]};
                2'd1: dout <= {rx_shift_reg[5:0], io_in[1:0]};
                2'd2: dout <= {rx_shift_reg[3:0], io_in[3:0]};
                default: dout <= dout;
            endcase
            valid <= 1;
        end
        else valid <= 0;
    end
    else valid <= 0;
end

// tx_data_req: fires one cycle before data_reg_temp is about to (re)load,
// so async_fifo's registered read_dataout has already settled by the time
// data_reg_temp <= data_reg latches it. This is the direct fix for the
// "data_reg_temp reads constant 00" bug -- request and load used to land
// on the same edge, so the very first byte was always latched before the
// FIFO's ren pulse had propagated through its one-cycle read latency.
wire first_byte_req =
    transfer_config_reg[`data_direction] && transfer_config_reg[`data_phase_enable] &&
    (
        (current_state == opcode_phase && count_bits_sent == 3 &&
         ~transfer_config_reg[`addr_phase_enable] && ~transfer_config_reg[`mode_phase_enable] && ~transfer_config_reg[`dummy_phase_enable]) ||

        // one cycle before address_phase's (corrected) last cycle, only when data_reg_temp
        // -- not mode_reg_temp -- is what actually loads at that boundary
        (current_state == address_phase && ~transfer_config_reg[`mode_phase_enable] &&
         (
            (transfer_config_reg[`addr_phase_line_width]==2'd0 && count_bits_sent == address_bits_size - 1) ||
            (transfer_config_reg[`addr_phase_line_width]==2'd1 && count_bits_sent == (address_bits_size+1)/2 - 2) ||
            (transfer_config_reg[`addr_phase_line_width]==2'd2 && count_bits_sent == (address_bits_size+1)/4 - 2)
         )) ||

        // one cycle before mode_phase's last cycle (fires regardless of what follows,
        // matching the unconditional mode-phase preload in the latch block above)
        (current_state == mode_phase &&
         (
            (transfer_config_reg[`addr_phase_line_width]==2'd0 && count_bits_sent == 20'd6) ||
            (transfer_config_reg[`addr_phase_line_width]==2'd1 && count_bits_sent == 20'd2) ||
            (transfer_config_reg[`addr_phase_line_width]==2'd2 && count_bits_sent == 20'd0)
         ))
    );

wire mid_byte_req =
    transfer_config_reg[`data_direction] && (current_state == data_phase) &&
    (
        (transfer_config_reg[`data_phase_line_width]==2'd0 && count_bits_sent[2:0]==3'd6 && count_bits_sent < (8*len_reg - 8)) ||
        (transfer_config_reg[`data_phase_line_width]==2'd1 && count_bits_sent[1:0]==2'd2 && count_bits_sent < (4*len_reg - 4)) ||
        (transfer_config_reg[`data_phase_line_width]==2'd2 && count_bits_sent[0]==1'b0 && count_bits_sent < (2*len_reg - 2))
    );

assign tx_data_req = first_byte_req || mid_byte_req;

endmodule
