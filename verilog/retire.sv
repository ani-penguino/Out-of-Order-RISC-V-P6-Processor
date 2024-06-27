module retire(
    input   clock, reset, 
    input   ROB_RT_PACKET    rob_rt_packet,

    output  RT_DP_PACKET     rt_dp_packet,
    output logic halt
);

    // This enable computation is sort of overkill since the reg file
    // also handles the `ZERO_REG case, but there's no harm in putting this here
    // the valid check is also somewhat redundant

    /*
    // Branch generation logic
    always_comb begin
        branch_packet = '0;
        if (rob_rt_packet.data_retired.branch_mispredicted) begin
            branch_packet.rob_tag = rob_rt_packet.data_retired.rob_tag;
            branch_packet.branch_valid = 1;
            branch_packet.PC = rob_rt_packet.data_retired.branch_loc;
        end
    end
    */
    
    always_ff@(posedge clock) begin
	if (reset) begin
            halt <= 0;
            rt_dp_packet.wb_regfile_halt <= 0;
	end else begin
            halt <= rob_rt_packet.data_retired.dp_packet.halt;
            rt_dp_packet.wb_regfile_halt <= halt;
	end
    end
    assign rt_dp_packet.wb_regfile_en = (rob_rt_packet.data_retired.complete) && (rob_rt_packet.data_retired.r != `ZERO_REG);

    assign rt_dp_packet.wb_regfile_idx = rob_rt_packet.data_retired.r;

    // Select register writeback data:
    // ALU/MEM result, unless taken branch, in which case we write
    // back the old NPC as the return address. Note that ALL branches
    // and jumps write back the 'link' value, but those that don't
    // use it specify ZERO_REG as the destination.
    // assign wb_regfile_data = (rob_rt_packet.take_branch)? rob_rt_packet.NPC : rob_rt_packet.data_retired.V; 
    assign rt_dp_packet.wb_regfile_data = rob_rt_packet.data_retired.V;
endmodule // stage_wb
