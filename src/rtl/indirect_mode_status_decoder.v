module indirect_mode_status_decoder(pclk, presetn, qspi_done, start, indirect_path_busy, transmission_completed);
input  qspi_done, start, pclk, presetn;
output reg transmission_completed, indirect_path_busy;

//start signal is a pulse which is active exactly for one clock cycle of PCLK, hence we detect the rising edge to 
//to compute busy status of indirect mode

//This module also receives qspi_done signal from the qspi_status module in SCLK domain
//Those signal are taken as input and sent via a dual rank sync
reg sync1, qspi_done_sync, qspi_done_sync_d;

always@(posedge pclk or negedge presetn)begin
    if(~presetn) begin
        sync1 <= 0;
        qspi_done_sync <= 0;
        qspi_done_sync_d <= 0;
    end
    else begin
        sync1 <= qspi_done;
        qspi_done_sync <= sync1;
        qspi_done_sync_d <= qspi_done_sync;
    end
end

wire qspi_done_pulse = qspi_done_sync & ~qspi_done_sync_d;

localparam [1:0] idle = 2'd0, transmission_begun = 2'd1, transmission_completed_by_qspi = 2'd2;
reg [1:0] current_state, next_state;

always@(posedge pclk or negedge presetn)begin
    if(~presetn) current_state <= idle;
    else current_state <= next_state;
end

always@(*)begin
    case(current_state)
    idle: next_state = start ? transmission_begun : idle;
    transmission_begun: next_state = qspi_done_pulse ? transmission_completed_by_qspi : transmission_begun;
    transmission_completed_by_qspi: next_state = idle;
    default: next_state = idle;
endcase
end

always@(*)begin
    case(current_state)
    idle: begin
        transmission_completed = 1;
        indirect_path_busy = 0;
    end
    transmission_begun: begin
        transmission_completed = 0;
        indirect_path_busy = 1;
    end
    transmission_completed_by_qspi: begin
        transmission_completed = 1;
        indirect_path_busy = 0;
    end
    default: begin
        transmission_completed = 1;
        indirect_path_busy = 0;
    end
    endcase
end
endmodule
