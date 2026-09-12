module qspi_status(sclk, presetn, cs, busy, done, done_delayed);
input sclk, presetn, cs;
output reg busy, done, done_delayed;
reg done_temp, busy_temp;

localparam [1:0] idle = 2'd0, qspi_operation = 2'd1, qspi_done = 2'd2;
reg [1:0] current_state, next_state;

always@(posedge sclk or negedge presetn)begin
    if(~presetn) current_state <= idle;
    else current_state <= next_state;
end

always@(*)begin
    case(current_state)
    idle: next_state = cs ? idle : qspi_operation;
    qspi_operation: next_state = cs ? qspi_done : qspi_operation;
    qspi_done: next_state = idle;
    default: next_state = idle;
    endcase
end
always@(*)begin
    case(current_state)
    idle: begin
        busy_temp = 0;
        done_temp = 0;
    end
    qspi_operation: begin
        busy_temp = 1;
        done_temp = 0;
    end
    qspi_done: begin
        busy_temp = 0;
        done_temp = 1;
    end
    default: begin
        busy_temp = 0;
        done_temp = 0;
    end
    endcase
end

// Immediate done -- unchanged, feeds indirect_mode_status_decoder /
// busy_temp_reg. Write commands don't need the RX-drain margin, so this
// path stays at the original latency.
always@(posedge sclk or negedge presetn) begin
    if(~presetn) done <= 0;
    else done <= done_temp;
end

always@(posedge sclk or negedge presetn) begin
    if(~presetn) busy <= 0;
    else busy <= busy_temp;
end
// Buffered done -- 4-cycle fixed delay, feeds ONLY rx_fifo_read_logic's
// qspi_done input. Covers the rx write-latch(2) + fifo write(1) +
// gray-ptr register(1) pipeline so the FIFO's write pointer is visibly
// updated on the read side before the drain FSM starts pulling ren.
reg done_d1, done_d2, done_d3;
always@(posedge sclk or negedge presetn) begin
    if(~presetn) begin
        done_d1 <= 0;
        done_d2 <= 0;
        done_d3 <= 0;
        done_delayed  <= 0;
    end
    else begin
        done_d1 <= done_temp;
        done_d2 <= done_d1;
        done_d3 <= done_d2;
        done_delayed <= done_d3;
    end
end
endmodule
