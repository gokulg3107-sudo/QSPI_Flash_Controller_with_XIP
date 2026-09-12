module rx_fifo_read_logic(pclk, presetn, start_pulse, fifo_empty, ren, read_data, fifo_data, len_reg, data_direction, rx_byte_ready);
input pclk, presetn, start_pulse, fifo_empty;
input [7:0] fifo_data;
input [8:0] len_reg;
input data_direction;
output reg ren;
output reg [7:0] read_data;
output reg rx_byte_ready;   // one-cycle pulse: fresh byte landed in read_data this cycle

reg [8:0] count_bytes_read;

// Drain concurrently: pull whenever the FIFO has data, this is a read
// command, and we haven't already drained len_reg bytes for this transfer.
wire drain_active = ~data_direction & ~fifo_empty & (count_bytes_read != len_reg);

always@(*) ren = drain_active;

// count resets on a fresh transaction start, not on FIFO-empty --
// otherwise a same-length back-to-back read would look "already done"
// the instant the new burst starts refilling the FIFO.
always@(posedge pclk or negedge presetn)begin
    if(~presetn) count_bytes_read <= 0;
    else if(start_pulse) count_bytes_read <= 0;
    else if(ren) count_bytes_read <= count_bytes_read + 1;
end

reg ren_d;
always@(posedge pclk or negedge presetn)begin
    if(~presetn) ren_d <= 0;
    else ren_d <= ren;
end

always@(posedge pclk or negedge presetn)begin
    if(~presetn) begin
        read_data     <= 0;
        rx_byte_ready <= 0;
    end
    else begin
        read_data     <= ren_d ? fifo_data : read_data;
        rx_byte_ready <= ren_d;
    end
end
endmodule

