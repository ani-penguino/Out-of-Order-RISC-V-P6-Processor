module store_fu (
    // Inputs
    input clock, 
    input reset,
    input ack,
    input FU_IN_PACKET fu_in_packet,
	input logic mem_ack,
    // Outputs
    output FU_OUT_PACKET fu_out_packet_comb,
    output FU_OUT_PACKET fu_out_packet,
    output FU_MEM_PACKET fu_mem_packet,
	output logic mem_req
); 

    logic fu_done;
    logic [`XLEN-1:0] read_data;

	assign fu_mem_packet.proc2Dmem_command = BUS_STORE;
    assign fu_mem_packet.proc2Dmem_addr = fu_in_packet.rs1_value + `RV32_signext_Simm(fu_in_packet.inst);
    assign fu_mem_packet.proc2Dmem_data = fu_in_packet.rs2_value;
	assign fu_mem_packet.proc2Dmem_size = MEM_SIZE'(fu_in_packet.inst.r.funct3[1:0]); 
    
    assign fu_out_packet_comb.done = mem_ack;
    assign fu_out_packet_comb.rob_tag = fu_in_packet.rob_tag;

    // create output packet and manage done signal
    always_ff @(posedge clock) begin
		if (reset) begin
            fu_out_packet <= '0;
            mem_req <= 0;
        end else begin
            fu_out_packet.rob_tag <= fu_in_packet.rob_tag;
            // ack clear must have priority over setting done
            if (fu_in_packet.issue_valid && !mem_ack) begin
                mem_req <= 1 && ~fu_out_packet.done;
                fu_out_packet.v <= fu_in_packet.rs2_value;
            end
            if (mem_ack) begin
                fu_out_packet.done <= 1;
                mem_req <= 0;
            end
            if (ack) fu_out_packet <= '0;
        end
    end

endmodule
