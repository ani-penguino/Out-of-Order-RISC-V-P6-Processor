// `include "sys_defs.svh"
// `include "ISA.svh"
`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

`ifdef TESTBENCH
`include "RS_ENTRY_IF.sv"
`endif

`ifdef TESTBENCH
    `define INTERFACE_PORT ,RS_ENTRY_IF.producer if_rs
`else
    `define INTERFACE_PORT
`endif
module rs(
    input logic clock,
    input logic reset, 
    input logic dispatch_valid,
    input logic block_1, // Blocks entry 1 from allocation, for debugging purposes
    input logic squash, 
    // from stage_dp
    input ROB_EX_PACKET rob_ex_packet,
    input DP_PACKET dp_packet,
    input FU_DONE_PACKET fu_done_packet,
    // from CDB
    input CDB_PACKET cdb_packet,

    // from ROB
    input ROB_RS_PACKET rob_packet,
    // from map table, whether rs_T1/2 is empty or a specific #ROB
    input MAP_RS_PACKET map_packet,
    input BRANCH_PACKET branch_packet,
    // from reorder buffer, the entire reorder buffer and the tail indicating
    // the instruction being dispatched. 
    // to map table and ROB
    output RS_DP_PACKET avail_vec,
    output logic allocate,

    // TODO: this part tentatively goes to the execution stage. In milestone 2, Expand this part so that it goes to separate functional units
    output RS_EX_PACKET rs_ex_packet
    `INTERFACE_PORT
);

    // Define and initialize the entry packets array
    RS_ENTRY entry [`NUM_RS:0];
    logic final_allocate, free;
    RS_TAG allocate_tag;
    logic [`NUM_RS:0] free_tag;
    
    // Initialize FU types for each entry packet instance
    
    assign entry[1].fu = ALU;
    assign entry[2].fu = ALU;
    assign entry[3].fu = LOAD;
    assign entry[4].fu = STORE;
    assign entry[5].fu = MULT;
    assign entry[6].fu = MULT;
   

    always_comb begin
	    `ifdef TESTBENCH
	    foreach (if_rs.entry[i]) begin
                if_rs.entry[i] = entry[i];
            end
	    //if_rs.rs_ex_packet = rs_ex_packet;fu_in
        `endif
    end

    logic [`NUM_RS:0] squash_rs;
    always_comb begin
        squash_rs = '0;
	if (branch_packet.mispredicted) begin
        for (int i = 1; i <= `NUM_RS; i++) begin
            if (branch_packet.rob_tag <= rob_packet.rob_tail.rob_tag) begin
                if (entry[i].r > branch_packet.rob_tag && (entry[i].r <= rob_packet.rob_tail.rob_tag && entry[i].r != 0)) begin
                    squash_rs[i] = 1;
                end
            end else begin
                if (entry[i].r > branch_packet.rob_tag || (entry[i].r <= rob_packet.rob_tail.rob_tag && entry[i].r != 0)) begin
                    squash_rs[i] = 1;
                end
            end
        end
	end
    end

    // Free Entry Logic: Need to free multiple entries
    always_comb begin
        free = 0;
        free_tag = '0;
        for (int i = `NUM_RS; i >= 1; i--) begin
            //if (entry[i].r == cdb_packet.rob_tag) begin
            if (fu_done_packet[i]) begin
		free = 1;
                free_tag[i] = 1;
            end
        end
    end

    logic [`NUM_RS:0] clear_rs;
    always_comb begin
        clear_rs = '0;
        if (branch_packet.mispredicted) begin
            for (int i = 1; i <= `NUM_RS; i++) begin
                if (branch_packet.rob_tag <= rob_ex_packet.tail) begin
                    if (i > branch_packet.rob_tag && i <= rob_ex_packet.tail) begin
                        clear_rs[i] = 1;
                    end
                end else begin
                    if (i > branch_packet.rob_tag || i <= rob_ex_packet.tail) begin
                        clear_rs[i] = 1;
                    end
                end
            end
        end
    end

    // Allocate Logic
    always_comb begin
	allocate = 0;
	allocate_tag = 0; // Don't have 7 reservation station entries, so reserve 0 for invalid address
	
    case (dp_packet.fu_sel)
        LOAD: begin // LOAD
            for (int i = `NUM_RS; i >= 1; i--) begin
                if ((!entry[i].busy) && entry[i].fu == LOAD) begin
                    allocate = ~entry[4].busy;
                    // allocate = 1; 
                    allocate_tag = i;
                end
        end	    
        end
        STORE: begin // STORE
            for (int i = `NUM_RS; i >= 1; i--) begin
                if ((!entry[i].busy || free_tag[i]) && entry[i].fu == STORE) begin
                    allocate = 1;
                    // allocate = 1; 
                    allocate_tag = i;
                end
        end	    
    end
        MULT: begin // Floating Point
            for (int i = `NUM_RS; i >= 1; i--) begin
                if ((!entry[i].busy) && entry[i].fu == MULT) begin
                    allocate = 1;
                    // allocate = 1; 
                    allocate_tag = i; 
                end
        end	    
    end
        ALU: begin
            for (int i = `NUM_RS; i >= 1; i--) begin
                if ((!entry[i].busy || free_tag[i]) && entry[i].fu == ALU && i != block_1) begin
                    allocate = 1;
                    // allocate = 1; 
                    allocate_tag = i;
            end
        end	    
        end
    default: begin
        allocate = 0;
        allocate_tag = 0;
    end
    endcase
    final_allocate = allocate && dispatch_valid;
    end
    

    // Clearing mechanism on reset, preserving the FU content
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            for (int i = 1; i <= `NUM_RS; i++) begin
                entry[i].t1 <= '0;
                entry[i].t2 <= '0;
                entry[i].v1 <= '0;
                entry[i].v2 <= '0;
                entry[i].v1_valid <= 0;
                entry[i].v2_valid <= 0;
                entry[i].r <= '0;
                entry[i].opcode <= '0;
                entry[i].valid <= '0;
                entry[i].busy <= '0;
                // entry[i].issued <= '0;
                entry[i].dp_packet <= '0;
            end
        end else begin    
        if (free) begin
	    for (int i = 1; i <= `NUM_RS; i++) begin
		if (free_tag[i]) begin
		    entry[i].t1 <= '0;
		    entry[i].t2 <= '0;
		    entry[i].v1 <= '0;
		    entry[i].v2 <= '0;
		    entry[i].v1_valid <= 0;
		    entry[i].v2_valid <= 0;
		    entry[i].r <= '0;
		    entry[i].opcode <= 0;
		    entry[i].valid <= 0;
		    entry[i].busy <= 0; 
		    // entry[i].issued <= 0;
		    entry[i].dp_packet <= '0;
	        end
            end
        end // freed and allocated on the same clock cycle
	if (squash) begin
	    for (int i = 0; i < `NUM_RS; i++) begin
            if (squash_rs[i]) begin
                entry[i].t1 <= '0;
                entry[i].t2 <= '0;
                entry[i].v1 <= '0;
                entry[i].v2 <= '0;
                entry[i].v1_valid <= 0;
                entry[i].v2_valid <= 0;
                entry[i].r <= '0;
                entry[i].opcode <= 0;
                entry[i].valid <= 0;
                entry[i].busy <= 0; 
                // entry[i].issued <= 0;
                entry[i].dp_packet <= '0;
            end	
	    end		    
	end
        if (final_allocate) begin 
            entry[allocate_tag].t1 <= map_packet.map_packet_a.rob_tag;
            entry[allocate_tag].t2 <= map_packet.map_packet_b.rob_tag;
            entry[allocate_tag].v1 <= (map_packet.map_packet_a.t_plus) ? rob_packet.rob_dep_a.V:
		   		                      (map_packet.map_packet_a.rob_tag == `ZERO_REG) ? dp_packet.rs1_value : 
		                              (map_packet.map_packet_a.rob_tag == cdb_packet.rob_tag) ? cdb_packet.v:'0; // TODO: the logic for this part is not correct, be very careful how this part is handled
            
	        entry[allocate_tag].v2 <= (map_packet.map_packet_b.t_plus) ? rob_packet.rob_dep_b.V: 
				                      (map_packet.map_packet_b.rob_tag == `ZERO_REG) ? dp_packet.rs2_value : // TODO: the logic for this part is not correct, be very careful how this part is handled
		                              (map_packet.map_packet_b.rob_tag == cdb_packet.rob_tag) ? cdb_packet.v:'0;
	        entry[allocate_tag].v1_valid <= (dp_packet.rs1_valid) ? (map_packet.map_packet_a.t_plus | (map_packet.map_packet_a.rob_tag == cdb_packet.rob_tag) | (map_packet.map_packet_a.rob_tag == `ZERO_REG)) : 1; // If rs1 is not used, assume it's valid
	        entry[allocate_tag].v2_valid <= (dp_packet.rs2_valid) ? (map_packet.map_packet_b.t_plus | (map_packet.map_packet_b.rob_tag == cdb_packet.rob_tag) | (map_packet.map_packet_b.rob_tag == `ZERO_REG)) : 1; // If rs2 is not used, assume it's valid
            entry[allocate_tag].r <= rob_packet.rob_tail.rob_tag;
	        entry[allocate_tag].opcode <= dp_packet.inst[6:0];
	        entry[allocate_tag].valid <= dp_packet.valid;
            entry[allocate_tag].busy <= dp_packet.valid; // TODO: how to handle NOP and WFI
	        // entry[allocate_tag].issued <= dp_packet.valid && ((map_packet.map_packet_a.rob_tag == `ZERO_REG) | (map_packet.map_packet_a.t_plus) | (map_packet.map_packet_a.rob_tag == cdb_packet.rob_tag)) && ((map_packet.map_packet_b.rob_tag == `ZERO_REG) | (map_packet.map_packet_b.t_plus) | (map_packet.map_packet_a.rob_tag == cdb_packet.rob_tag)); // TODO: Check this logic
            entry[allocate_tag].dp_packet <= dp_packet;
	end
	// Update logic
        for (int i = `NUM_RS; i >= 1; i--) begin 
            if (entry[i].t1 == cdb_packet.rob_tag && entry[i].t1 != `ZERO_REG) begin
                entry[i].t1 <= `ZERO_REG;
                entry[i].v1 <= cdb_packet.v;
                entry[i].v1_valid <= 1;
            end
            if (entry[i].t2 == cdb_packet.rob_tag && entry[i].t2 != `ZERO_REG) begin
                entry[i].t2 <= `ZERO_REG;
                entry[i].v2 <= cdb_packet.v;
                entry[i].v2_valid <= 1;
            end
	    end
        end
    end

    logic [`NUM_RS:0] issued_comb;
    logic [`NUM_RS:0] issue_delay;
    always_comb begin
        for (int i = 1; i <= `NUM_RS; i++) begin
            issued_comb[i] = entry[i].v1_valid && entry[i].v2_valid && entry[i].valid;
        end
    end

    always_comb begin
        for (int i = 1; i <= `NUM_RS; i++) begin
            entry[i].issued = issued_comb[i];
            // if (allocate_tag == i) begin
            //     entry[i].issued = issued_comb[i];
            // end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            issue_delay <= '0;
        end
        for (int i = 1; i <= `NUM_RS; i++) begin
            issue_delay[i] <= issued_comb[i];
        end
    end



    always_comb begin
        for (int i = 1; i <= `NUM_RS; i++) begin
            rs_ex_packet.fu_in_packets[i].inst = entry[i].dp_packet.inst;
            rs_ex_packet.fu_in_packets[i].PC = entry[i].dp_packet.PC;
            rs_ex_packet.fu_in_packets[i].NPC = entry[i].dp_packet.NPC; // PC + 4
            rs_ex_packet.fu_in_packets[i].rs1_value = entry[i].v1;
            rs_ex_packet.fu_in_packets[i].rs2_value = entry[i].v2;
            rs_ex_packet.fu_in_packets[i].rs1_idx = entry[i].dp_packet.rs1_idx;
            rs_ex_packet.fu_in_packets[i].rs2_idx = entry[i].dp_packet.rs2_idx;
            rs_ex_packet.fu_in_packets[i].rs1_valid = entry[i].dp_packet.rs1_valid;
            rs_ex_packet.fu_in_packets[i].rs2_valid = entry[i].dp_packet.rs2_valid;
            rs_ex_packet.fu_in_packets[i].opa_select = entry[i].dp_packet.opa_select;
            rs_ex_packet.fu_in_packets[i].opb_select = entry[i].dp_packet.opb_select;
            rs_ex_packet.fu_in_packets[i].dest_reg_idx = entry[i].dp_packet.dest_reg_idx;
            rs_ex_packet.fu_in_packets[i].has_dest = entry[i].dp_packet.has_dest;
            rs_ex_packet.fu_in_packets[i].alu_func = entry[i].dp_packet.alu_func;
            rs_ex_packet.fu_in_packets[i].rd_mem = entry[i].dp_packet.rd_mem;
            rs_ex_packet.fu_in_packets[i].wr_mem = entry[i].dp_packet.wr_mem;
            rs_ex_packet.fu_in_packets[i].cond_branch = entry[i].dp_packet.cond_branch;
            rs_ex_packet.fu_in_packets[i].uncond_branch = entry[i].dp_packet.uncond_branch;
            rs_ex_packet.fu_in_packets[i].halt = entry[i].dp_packet.halt;
            rs_ex_packet.fu_in_packets[i].illegal = entry[i].dp_packet.illegal;
            rs_ex_packet.fu_in_packets[i].csr_op = entry[i].dp_packet.csr_op;
            rs_ex_packet.fu_in_packets[i].valid = entry[i].dp_packet.valid;
            rs_ex_packet.fu_in_packets[i].rob_tag = entry[i].r;
            rs_ex_packet.fu_in_packets[i].issue_valid = entry[i].issued;
            rs_ex_packet.fu_in_packets[i].fu_id = i;
	    rs_ex_packet.fu_in_packets[i].dp_packet = entry[i].dp_packet;
        end
    end

/*

    logic [4:0] rs1_idx; // reg A index
    logic [4:0] rs2_idx; // reg B index

    logic rs1_valid; // reg A used
    logic rs2_valid; // reg B used

    ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
    ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)

    logic [4:0] dest_reg_idx;  // destination (writeback) register index
    logic has_dest;            // destination register is used

    ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
    logic       rd_mem;        // Does inst read memory?
    logic       wr_mem;        // Does inst write memory?
    logic       cond_branch;   // Is inst a conditional branch?
    logic       uncond_branch; // Is inst an unconditional branch?
    logic       halt;          // Is this a halt?
    logic       illegal;       // Is this instruction illegal?
    logic       csr_op;        // Is this a CSR operation? (we use this to get return code)

    logic       valid;
    // DO NOT ADD ABOVE THIS LINE. CAN ADD BELOW

    ROB_TAG tag;
    logic issue_valid;      // goes high when RS issues instr
    logic [`RS_TAG_WIDTH-1:0] fu_id;
*/



    always_comb begin
	    avail_vec[1].fu = entry[1].fu;
	    avail_vec[1].available = ~entry[1].busy && (~block_1);
	    for (int i = 2; i <= `NUM_RS; i++) begin
		avail_vec[i].fu = entry[i].fu;
		avail_vec[i].available = ~entry[i].busy;
	    end
    end
    // TODO: Add an issue valid logic 
endmodule
