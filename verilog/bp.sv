module bpsimple (
    input clock,
    input reset, 
    input DP_PACKET dp_packet,

    output logic [`XLEN-1:0] bp_pc,
    output logic [`XLEN-1:0] bp_npc,
    output logic bp_taken
);
// Assuming 32-bit instructions and PC. Adjust sizes as necessary.

    assign bp_pc = dp_packet.PC;
    assign bp_npc = dp_packet.NPC;
    assign bp_taken = 0;

    pre_decode pre_decode_0(
        .inst(inst),
        .valid(valid),
        .cond_branch(cond_branch),
        .uncond_branch(uncond_branch),
        .jump(jump),
        .link(link)
    );

endmodule
