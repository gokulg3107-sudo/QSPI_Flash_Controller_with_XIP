//Command code for QSPI
`define page_program 8'h02
`define write_enable 8'h06
`define read_status_reg 8'h05
`define read_jedec_id 8'h9f
`define sector_erase 8'h20
`define fast_read 8'h0b
`define quad_io_read 8'heb
`define write_status_register 8'h35
`define block_erase 8'hD8 // Block Erase
`define quad_input_pp 8'h38 // Quad Input Page Program (see NOTE at its test below)
`define quad_output_read 8'h6B // Quad Output Read
`define dual_output_read  8'h3B // Dual Output Read
`define dual_io_read  8'hBB // Dual I/O Read
`define read_status_reg_2 8'h35 //
//Register bank in APB
`define command_code  4'd0
`define  address_bytes  4'd1
`define  dummy_cycles_count  4'd2
`define  length_of_data  4'd3
`define  control_signals 4'd4
`define write_fifo_data 4'd5
`define read_fifo_data 4'd6
`define transfer_config_reg 4'd7 //address en, w
`define qspi_transfer_status_register 4'd8
`define mode_byte 4'd9
`define read_flash_output 4'd10
// bit-field macros for transfer_config_reg[9:0]
`define data_phase_line_width 9:8
`define addr_phase_line_width 7:6
`define addr_byte_count 5      // 0 -> 3-byte addr, 1 -> 4-byte addr
`define data_direction 4      // 0 -> read from flash, 1 -> write to flash
`define addr_phase_enable 3
`define data_phase_enable 2
`define mode_phase_enable 1
`define dummy_phase_enable 0

// ------------------------------------------------------------------
// AHB HTRANS encodings (XIP path) -- separate namespace from the
// bit-field macros above (these are 2-bit VALUES, not bit positions)
// ------------------------------------------------------------------
`define htrans_idle    2'b00
`define htrans_busy    2'b01
`define htrans_nonseq  2'b10
`define htrans_seq     2'b11

// ------------------------------------------------------------------
// XIP fixed transfer_config_reg presets (mirrors TCFG_* convention
// used in tb_5.v for indirect-mode transactions)
// ------------------------------------------------------------------
`define xip_tcfg_rdsr  10'b00_00_0_0_0100   // data-only, read, 1-wire
`define xip_tcfg_qior  10'b10_10_0_0_1101   // addr+mode+dummy+data, read, 4-wire
`define xip_qior_dummy 5'd5           // dummy cycles, matches tb_5.v TCFG_QIOR usage
`define xip_qior_mode  8'h00                // non-Fxh top nibble -- no continuous-read entry
