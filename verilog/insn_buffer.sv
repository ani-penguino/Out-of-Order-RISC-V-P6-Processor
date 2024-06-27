module insn_buffer (
    input clock,
    input reset,
    input dispatch_valid_in,
    input squash_in, // Clear buffer
    input IF_IB_PACKET if_ib_packet, // Instruction input

    output logic ib_full, // Indicates the buffer is full
    output logic ib_empty, // Indicates the buffer is empty
    output IB_DP_PACKET ib_dp_packet // Instruction output
);

    logic [$clog2(`IBUFFER_SZ) : 0] tail, head, status;
    IF_IB_PACKET [`IBUFFER_SZ - 1 : 0] buffer;

    assign ib_empty = (status == '0);
    assign ib_full = (status == `IBUFFER_SZ);

    assign ib_dp_packet = buffer[head];

    // FIFO operation
    always_ff @(posedge clock) begin
        if (reset || squash_in) begin
            head <= '0;
            tail <= '0;
            status <= '0;
            buffer <= '0;
        end else begin
            // the order here is important
            if (dispatch_valid_in) begin
                buffer[head] <= '0;
                head <= (head + 1) % `IBUFFER_SZ;
                status <= status - 1;
            end
            if (!ib_full && if_ib_packet.valid) begin
                buffer[tail] <= if_ib_packet;
                tail <= (tail + 1) % `IBUFFER_SZ;
                status <= status + 1;
            end
            // necessary to keep status same if both reading and writing on some clock cycle
            if (!ib_full && if_ib_packet.valid && dispatch_valid_in) begin
                status <= status;
            end
        end
    end

endmodule