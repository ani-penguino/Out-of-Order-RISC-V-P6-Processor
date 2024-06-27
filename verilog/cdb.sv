// Version 1.0

`include "verilog/sys_defs.svh"

// Very simple priority selector for testing
module ps(
    input logic  [`NUM_FU:0] req,
    output logic [`NUM_FU:0] ack
);

    // give priority to MSBs
    always_comb begin
        ack = '0;
        for (int i = `NUM_FU; i >= 0; i--) begin
            ack[i] = req[i] & !ack;
        end
    end

endmodule


module cdb(
    // global signals
    input logic clock,
    input logic reset,
    // input packets
    input EX_CDB_PACKET ex_cdb_packet,
    // output packets
    output CDB_EX_PACKET cdb_ex_packet,
    output CDB_PACKET cdb_packet,
    // debug
    output logic [`NUM_FU:0] dones_dbg,
    output logic [`NUM_FU:0] ack_dbg
);

    logic [`NUM_FU:0] ack;
    logic [`NUM_FU:0] dones;

    // unpack done bits;
    always_comb begin
        for (int i = 0; i <= `NUM_FU; i++) begin
            dones[i] = ex_cdb_packet.fu_out_packets[i].done;
        end
    end

    // priority selector (comb)
    ps u_ps (
        .req    (dones),
        .ack      (ack)
    );

    // selector logic for cdb
    always_comb begin
        cdb_packet = '0;
        for (int i = 0; i <= `NUM_FU; i++) begin
            if (ack[i]) begin   // if 
                cdb_packet.rob_tag = ex_cdb_packet.fu_out_packets[i].rob_tag;
                cdb_packet.v = ex_cdb_packet.fu_out_packets[i].v;
                cdb_packet.branch_mispredicted = ex_cdb_packet.fu_out_packets[i].take_branch;
                cdb_packet.branch_loc = ex_cdb_packet.fu_out_packets[i].branch_loc;
            end
        end
    end

    assign cdb_ex_packet.ack = ack;

    assign dones_dbg = dones;
    assign ack_dbg = ack;

endmodule
