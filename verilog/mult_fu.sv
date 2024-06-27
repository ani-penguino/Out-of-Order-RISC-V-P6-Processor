// Version 1.0


`include "verilog/sys_defs.svh"

module mult_fu(
    // global signals
    input logic clock,
    input logic reset,
    // ack bit (from CDB)
    input logic ack,

    // input packets
    input FU_IN_PACKET fu_in_packet,

    // output packets
    output FU_OUT_PACKET fu_out_packet_comb,
    output FU_OUT_PACKET fu_out_packet

    // debug
    
);

    logic start, mult_done, fu_done;
    logic [63:0] product;
    logic mult_done_prev;

    assign fu_out_packet_comb.done = (!mult_done_prev && mult_done);
    assign fu_out_packet_comb.rob_tag = fu_in_packet.rob_tag;

    // convert issue signal into pulse for multiplier start
    // start only high for one clock cycle after issue_valid goes high
    logic issue_valid_prev, started;
    always_ff @(posedge clock) begin
        if (reset) begin
            start <= 0;
            issue_valid_prev <= 0;
        end else begin
            issue_valid_prev <= fu_in_packet.issue_valid;
            start <= fu_in_packet.issue_valid && !issue_valid_prev;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            started <= 0;
        end else begin
            if (fu_in_packet.issue_valid) begin
                started <= 1;
            end
            if (mult_done && ~mult_done_prev) begin
                started <= 0;
            end else started <= 1;
        end
    end


    mult u_mult (
        .clock      (clock),
        .reset      (reset),
        .mcand      ({{32{fu_in_packet.rs1_value[31]}}, fu_in_packet.rs1_value}),
        .mplier     ({{32{fu_in_packet.rs2_value[31]}}, fu_in_packet.rs2_value}),
        .start      (start),
        .product    (product),
        .done       (mult_done)
    );

    // hold done high until ack is received

    always_ff @(posedge clock) begin
        if (reset) begin
            fu_done <= 0;
            mult_done_prev <= 0;
        end else begin
            mult_done_prev <= mult_done;
            if (!mult_done_prev && mult_done) fu_done <= 1;
            if (ack) fu_done <= 0;
        end
    end

    // populate cdb packet
    assign fu_out_packet.done = fu_done;
    assign fu_out_packet.v = (fu_in_packet.inst.r.funct3 == 0) ? product[31:0] : product[63:32];
    assign fu_out_packet.rob_tag = fu_in_packet.rob_tag;


endmodule