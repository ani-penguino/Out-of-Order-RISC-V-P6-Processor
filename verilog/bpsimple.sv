module bpsimple (
    input clock,
    input reset, 
    input IF_IB_PACKET if_ib_packet,
    input BRANCH_PACKET branch_packet,

    output logic [`XLEN-1:0] bp_pc,
    output logic [`XLEN-1:0] bp_npc,
    output logic bp_taken
);

    logic cond_branch, uncond_branch, jump, link;
    logic [6:0] branch_imm1;
    logic [4:0] branch_imm2;
    logic [`XLEN-1:0] branch_loc;
    logic [11:0] full_imm = 0;

    logic [2:0] bht_if_out;
    logic [2:0] bht_ex_out;
    logic [`XLEN-1:0] link_pc;
    logic predict_taken;

    logic hit;
    logic [`XLEN-1:0] predict_pc_out;

    assign bp_pc = ((cond_branch || uncond_branch) && !link && !jump)? branch_loc : if_ib_packet.NPC;
    assign bp_npc = ((cond_branch || uncond_branch) && !link && !jump)? branch_loc : if_ib_packet.NPC;
    assign bp_taken = ((cond_branch || uncond_branch) && !link && !jump)? predict_taken : 0; 

    assign branch_loc = if_ib_packet.PC + `RV32_signext_Bimm(if_ib_packet.inst);  
    

    pre_decode pre_decode_0(
        .inst(if_ib_packet.inst),
        .valid(if_ib_packet.valid),
        .cond_branch(cond_branch),
        .uncond_branch(uncond_branch),
	.branch_imm1(branch_imm1),
	.branch_imm2(branch_imm2),
        .jump(jump),
        .link(link)
    );

    BHT bht_0(
        .clock(clock),
        .reset(reset),
        .wr_en(branch_packet.cond_br_en),
        .ex_pc(branch_packet.origin_PC),
        .take_branch(branch_packet.branch_valid),
        .if_pc(if_ib_packet.PC),

        .bht_if_out(bht_if_out),
        .bht_ex_out(bht_ex_out)
    );

    PHT pht_0(
        .clock(clock),
        .reset(reset),
        .wr_en(branch_packet.cond_br_en),
        .ex_pc(branch_packet.origin_PC),
        .take_branch(branch_packet.branch_valid),
        .if_pc(if_ib_packet.PC),
        .bht_if_in(bht_if_out),
        .bht_ex_in(bht_ex_out),
        .predict_taken(predict_taken)
    );

    BTB btb_0(
        .clock(clock),
        .reset(reset),
        .wr_en(branch_packet.cond_br_en),
        .ex_pc(branch_packet.origin_PC),
        .ex_tg_pc(branch_packet.target_PC), 
        .if_pc(if_ib_packet.PC),
        .hit(hit),
        .predict_pc_out(predict_pc_out)
    );


endmodule
