/////////////////////////////////////////////////////////////////////////
//                                                                     //
//  Modulename :  stage_dp.sv                                          //
//  Version: 1.0                                                       //
//  Description :  dispatch stage of the module                        //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

module stage_dp(
	// Inputs
    input clock,
    input reset,
	input squash,
	input dispatch_valid,
    input RT_DP_PACKET rt_dp_packet,
    input IB_DP_PACKET ib_dp_packet,
	// Outputs
    output DP_PACKET dp_packet,
	output logic halted
);
    logic [4:0] rs1_idx, rs2_idx;
    regfile regfile(
        .clock(clock),
        .read_idx_1(ib_dp_packet.inst.r.rs1),
        .read_idx_2(ib_dp_packet.inst.r.rs2),
        .write_en(rt_dp_packet.wb_regfile_en),
        .write_idx(rt_dp_packet.wb_regfile_idx),
        .write_data(rt_dp_packet.wb_regfile_data),

        .read_out_1(dp_packet.rs1_value),
        .read_out_2(dp_packet.rs2_value)
    );

	always_ff @(posedge clock) begin
		if (reset || squash) begin
			halted <= 0;
		end else begin
			halted <= (dp_packet.halt && dispatch_valid) || halted;
		end 
	end

		assign dp_packet.inst  = ib_dp_packet.inst;
		assign dp_packet.NPC   = ib_dp_packet.NPC;
		assign dp_packet.PC    = ib_dp_packet.PC;
		assign dp_packet.rs1_idx = ib_dp_packet.inst.r.rs1;
		assign dp_packet.rs2_idx = ib_dp_packet.inst.r.rs2;
		assign dp_packet.predicted_branch = ib_dp_packet.pred_bp_taken;

		decoder decorder (
			// input
			.if_packet(ib_dp_packet),
			// outputs
			.opa_select(dp_packet.opa_select),
			.opb_select(dp_packet.opb_select),
			.has_dest(dp_packet.has_dest), 
			.alu_func(dp_packet.alu_func),
			.rd_mem(dp_packet.rd_mem),
			.wr_mem(dp_packet.wr_mem),
			.cond_branch(dp_packet.cond_branch),
			.uncond_branch(dp_packet.uncond_branch),
			.csr_op(dp_packet.csr_op),
			.halt(dp_packet.halt),
			.illegal(dp_packet.illegal),
			.valid_inst_out(dp_packet.valid),
			.has_rs1(dp_packet.rs1_valid),
			.has_rs2(dp_packet.rs2_valid),
			.fu_sel(dp_packet.fu_sel)
		);

	assign dp_packet.dest_reg_idx = dp_packet.has_dest ? ib_dp_packet.inst.r.rd : `ZERO_REG;
   
endmodule // module stage_dp

