/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  vtuber_test.sv                                      //
//                                                                     //
//  Description :  Visual Debugger for project 4                       //
//                 Outputs only IF part                                //
//                                                                     //
/////////////////////////////////////////////////////////////////////////


`include "verilog/sys_defs.svh"

extern void initcurses(int,int,int,int,int,int,int,int,int,int);
extern void flushpipe();
extern void waitforresponse();
extern void initmem();
extern int get_instr_at_pc(int);
extern int not_valid_pc(int);

module testbench;
    string program_memory_file;

    // Registers and wires used in the testbench
    logic        clock;
    logic        reset;
    logic [31:0] clock_count;
    logic [31:0] instr_count;
    int          wb_fileno;
    logic [63:0] debug_counter; // counter used for when pipeline infinite loops, forces termination

    logic [1:0]       proc2mem_command;
    logic [`XLEN-1:0] proc2mem_addr;
    logic [63:0]      proc2mem_data;
    logic [3:0]       mem2proc_response;
    logic [63:0]      mem2proc_data;
    logic [3:0]       mem2proc_tag;
`ifndef CACHE_MODE
    MEM_SIZE          proc2mem_size;
`endif

    logic [3:0]            pipeline_completed_insts;
    EXCEPTION_CODE         pipeline_error_status;
    logic [4:0]            pipeline_commit_wr_idx;
    logic [`XLEN-1:0]      pipeline_commit_wr_data;
    logic                   pipeline_commit_wr_en;
    logic [`XLEN-1:0]      pipeline_commit_NPC;
    logic [`XLEN-1:0]      if_NPC_dbg;
    logic [31:0]           if_inst_dbg;
    logic                   if_valid_dbg;
    logic [`XLEN-1:0]      ex_mem_NPC_dbg;
    logic [31:0]           ex_mem_inst_dbg;
    logic                   ex_mem_valid_dbg;
    logic [`XLEN-1:0]      mem_wb_NPC_dbg;
    logic [31:0]           mem_wb_inst_dbg;
    logic                   mem_wb_valid_dbg;
    MAP_PACKET [31:0]      m_table_dbg;
    logic [`NUM_FU:0]      dones_dbg;
    logic [`NUM_FU:0]      ack_dbg;
    CDB_PACKET             cdb_packet_dbg;
    CDB_EX_PACKET          cdb_ex_packet_dbg;
    MAP_RS_PACKET          map_rs_packet_dbg;
    MAP_ROB_PACKET         map_rob_packet_dbg;
    EX_CDB_PACKET          ex_cdb_packet_dbg;
    DP_PACKET              dp_packet_dbg;
    logic                  dp_packet_req_dbg;
    RS_DP_PACKET           avail_vec_dbg;
    RS_EX_PACKET           rs_ex_packet_dbg;
    ROB_RS_PACKET          rob_rs_packet_dbg;
    ROB_MAP_PACKET         rob_map_packet_dbg;
    logic                  rob_dp_available_dbg;
    ROB_RT_PACKET          rob_rt_packet_dbg;
    logic                  dispatch_valid_dbg;
    logic [`XLEN-1:0]      id_ex_inst_dbg;
    RT_DP_PACKET           rt_dp_packet_dbg;
    IB_DP_PACKET           ib_dp_packet_dbg;
    IF_IB_PACKET           if_ib_packet_dbg;
    logic                  ib_full_dbg;
    logic                  ib_empty_dbg;
    logic                  squash_dbg;

    // Instantiate the Pipeline
    pipeline pipeline_0 (
        // Inputs
        .clock             (clock),
        .reset             (reset),
        .mem2proc_response (mem2proc_response),
        .mem2proc_data     (mem2proc_data),
        .mem2proc_tag      (mem2proc_tag),

        // Outputs
        .proc2mem_command (proc2mem_command),
        .proc2mem_addr    (proc2mem_addr),
        .proc2mem_data    (proc2mem_data),
        .proc2mem_size    (proc2mem_size),

        .pipeline_completed_insts (pipeline_completed_insts),
        .pipeline_error_status    (pipeline_error_status),
        .pipeline_commit_wr_data  (pipeline_commit_wr_data),
        .pipeline_commit_wr_idx   (pipeline_commit_wr_idx),
        .pipeline_commit_wr_en    (pipeline_commit_wr_en),
        .pipeline_commit_NPC      (pipeline_commit_NPC),

        .if_NPC_dbg       (if_NPC_dbg),
        .if_inst_dbg      (if_inst_dbg),
        .if_valid_dbg     (if_valid_dbg),
        .ex_mem_NPC_dbg   (ex_mem_NPC_dbg),
	.ex_mem_inst_dbg  (ex_mem_inst_dbg),
	.ex_mem_valid_dbg (ex_mem_valid_dbg),
	.mem_wb_NPC_dbg   (mem_wb_NPC_dbg),
	.mem_wb_inst_dbg  (mem_wb_inst_dbg),
	.mem_wb_valid_dbg (mem_wb_valid_dbg),
	.m_table_dbg      (m_table_dbg),
	.dones_dbg        (dones_dbg),
	.ack_dbg          (ack_dbg),
	.cdb_packet_dbg	  (cdb_packet_dbg),
	.cdb_ex_packet_dbg(cdb_ex_packet_dbg),
	.map_rs_packet_dbg(map_rs_packet_dbg),
	.map_rob_packet_dbg    (map_rob_packet_dbg),
	.ex_cdb_packet_dbg     (ex_cdb_packet_dbg),
	.dp_packet_dbg         (dp_packet_dbg),
	.dp_packet_req_dbg     (dp_packet_req_dbg),
	.avail_vec_dbg         (avail_vec_dbg),
	.rs_ex_packet_dbg      (rs_ex_packet_dbg),
	.rob_rs_packet_dbg     (rob_rs_packet_dbg),
	.rob_map_packet_dbg    (rob_map_packet_dbg),
	.rob_dp_available_dbg  (rob_dp_available_dbg),
	.rob_rt_packet_dbg     (rob_rt_packet_dbg),
	.dispatch_valid_dbg    (dispatch_valid_dbg),
	.id_ex_inst_dbg        (id_ex_inst_dbg),
	.rt_dp_packet_dbg      (rt_dp_packet_dbg),
	.ib_dp_packet_dbg      (ib_dp_packet_dbg),
	.if_ib_packet_dbg      (if_ib_packet_dbg),
	.ib_full_dbg           (ib_full_dbg),
	.ib_empty_dbg          (ib_empty_dbg),
	.squash_dbg            (squash_dbg)
	
    );

    // Instantiate the Data Memory
    mem memory (
        // Inputs
        .clk              (clock),
        .proc2mem_command (proc2mem_command),
        .proc2mem_addr    (proc2mem_addr),
        .proc2mem_data    (proc2mem_data),
`ifndef CACHE_MODE
        .proc2mem_size    (proc2mem_size),
`endif

        // Outputs
        .mem2proc_response (mem2proc_response),
        .mem2proc_data     (mem2proc_data),
        .mem2proc_tag      (mem2proc_tag)																																																																																																																																																																																														
    );


    // Generate System Clock
    always begin
    #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end


    // Count the number of posedges and number of instructions completed
    // till simulation ends
    always @(posedge clock) begin
        if (reset) begin
            clock_count <= 0;
            instr_count <= 0;
        end else begin
            clock_count <= (clock_count + 1);
            instr_count <= (instr_count + pipeline_completed_insts);
        end
    end


    initial begin
        clock = 0;
        reset = 0;

        // Call to initialize visual debugger
        // *Note that after this, all stdout output goes to visual debugger*
        // each argument is number of registers/signals for the group
       initcurses(
            8,  // IF
            27,  // IB
            41, // DP
            56, // RS
            41,  // MT 
            53,  // ROB
            32,  // EX
            14,  // CDB
            12,  // GLOBAL
            44   // Miscellaneous
        );

        // Pulse the reset signal
        reset = 1'b1;
        @(posedge clock);
        @(posedge clock);

        // set paramterized strings, see comment at start of module
        if ($value$plusargs("MEMORY=%s", program_memory_file)) begin
            $display("Loading memory file: %s", program_memory_file);
        end else begin
            $display("Loading default memory file: program.mem");
            program_memory_file = "program.mem";
        end

        // Read program contents into memory array
        $readmemh(program_memory_file, memory.unified_memory);
        @(posedge clock);
        @(posedge clock);
        #1;
        // This reset is at an odd time to avoid the pos & neg clock edges
        reset = 1'b0;
    end


    always @(negedge clock) begin
        if (!reset) begin
            #2;
            // deal with any halting conditions
            if (pipeline_error_status!=NO_ERROR) begin
                #100
                $display("\nDONE\n");
                waitforresponse();
                flushpipe();
                $finish;
            end
        end
    end 


    // This block is where we dump all of the signals that we care about to
    // the visual debugger.  Notice this happens at *every* clock edge.
    always @(clock) begin
        #2;

        // Dump clock and time onto stdout
        $display("c%h%7.0d",clock,clock_count);
        $display("t%8.0f",$time);
        $display("z%h",reset);

        // Dump register file contents
        $write("a");
        for(int i = 0; i < 32; i=i+1) begin
            $write("%h", pipeline_0.u_stage_dp.regfile.registers[i]);
        end
        $display("");

        // Dump instructions and their validity for each stage
        $write("p");
        $write("%h%h ",
               if_inst_dbg,      if_valid_dbg,
               );
        $display("");

        // Dump interesting register/signal contents onto stdout
        // format is "<reg group prefix><name> <width in hex chars>:<data>"
        // Current register groups (and prefixes) are:
        // f: IF   d: ID   e: EX   m: MEM    w: WB  v: misc. reg
        // g: IF/ID   h: ID/EX  i: EX/MEM  j: MEM/WB

        // IF signals (5) - prefix 'f'
        $display("finst_h 8:%h",        pipeline_0.if_ib_packet.inst);
	$display("fPC_h 8:%h",          pipeline_0.if_ib_packet.PC);
	$display("fNPC_h 8:%h",         pipeline_0.if_ib_packet.NPC);
        $display("fPC_reg 8:%h",        pipeline_0.u_if_stage.PC_reg);
        $display("fvalid_h 1:%h",       pipeline_0.if_ib_packet.valid);
	$display("fImem_addr_h 8:%h",   pipeline_0.proc2Imem_addr);
	$display("ftakebran1 8:%h",   pipeline_0.u_ex.fu_1.take_conditional);
	$display("ftakebran2_h 8:%h",   pipeline_0.u_ex.fu_2.take_conditional);

        // IB signals (27) - prefix 'g'
        $display("ghead_b 5:%h",        pipeline_0.u_insn_buffer.head);
        $display("gtail_b 5:%h",          pipeline_0.u_insn_buffer.tail);
	$display("gfull_h 1:%h",        pipeline_0.u_insn_buffer.ib_full);
        $display("gempty_h 1:%h",          pipeline_0.u_insn_buffer.ib_empty);

        $display("ginst_h 8:%h",        pipeline_0.ib_dp_packet.inst);
        $display("gPC_h 8:%h",          pipeline_0.ib_dp_packet.PC);
	$display("gNPC_h 8:%h",         pipeline_0.ib_dp_packet.NPC);
        $display("gvalid_h 1:%h",       pipeline_0.ib_dp_packet.valid);
	$display("gib_full_h 1:%h",     pipeline_0.ib_full);
        $display("gib_empty_h 1:%h",    pipeline_0.ib_empty);
	$display("gIB_BUFFER");
	$display("ge0_NPC_h 8:%h",      pipeline_0.u_insn_buffer.buffer[0].NPC);
	$display("ge1_NPC_h 8:%h",      pipeline_0.u_insn_buffer.buffer[1].NPC);
	$display("ge2_NPC_h 8:%h",      pipeline_0.u_insn_buffer.buffer[2].NPC);
	$display("ge3_NPC_h 8:%h",      pipeline_0.u_insn_buffer.buffer[3].NPC);
	$display("ge4_NPC_h 8:%h",      pipeline_0.u_insn_buffer.buffer[4].NPC);
	$display("ge5_NPC_h 8:%h",      pipeline_0.u_insn_buffer.buffer[5].NPC);
	$display("ge6_NPC_h 8:%h",      pipeline_0.u_insn_buffer.buffer[6].NPC);
	$display("ge7_NPC_h 8:%h",      pipeline_0.u_insn_buffer.buffer[7].NPC);
	$display("ge8_NPC_h 8:%h",      pipeline_0.u_insn_buffer.buffer[8].NPC);
	$display("ge9_NPC_h 8:%h",      pipeline_0.u_insn_buffer.buffer[9].NPC);
	$display("ge10_NPC_h 8:%h",      pipeline_0.u_insn_buffer.buffer[10].NPC);
	$display("ge11_NPC_h 8:%h",      pipeline_0.u_insn_buffer.buffer[11].NPC);
	$display("ge12_NPC_h 8:%h",      pipeline_0.u_insn_buffer.buffer[12].NPC);
	$display("ge13_NPC_h 8:%h",      pipeline_0.u_insn_buffer.buffer[13].NPC);
	$display("ge14_NPC_h 8:%h",      pipeline_0.u_insn_buffer.buffer[14].NPC);
	$display("ge15_NPC_h 8:%h",      pipeline_0.u_insn_buffer.buffer[15].NPC);



        // DP signals (23) - prefix 'd'
        $display("dfu_sel_h 1:%h",     		pipeline_0.dp_packet.fu_sel);
        $display("dinst_h 8:%h",       		pipeline_0.dp_packet.inst);
        $display("dPC_h 8:%h",         		pipeline_0.dp_packet.PC);
        $display("dNPC_h 8:%h",         	pipeline_0.dp_packet.NPC);
        $display("drs1_value_h 8:%h",  		pipeline_0.dp_packet.rs1_value);
        $display("drs2_value_h 8:%h",  		pipeline_0.dp_packet.rs2_value);
        $display("drs1_idx_h 2:%h",    		pipeline_0.dp_packet.rs1_idx);
        $display("drs2_idx_h 2:%h",    		pipeline_0.dp_packet.rs2_idx);
        $display("drs1_valid_h 1:%h",  		pipeline_0.dp_packet.rs1_valid); 
        $display("drs2_valid_h 1:%h",  		pipeline_0.dp_packet.rs2_valid);
        $display("dopa_select_h 1:%h", 		pipeline_0.dp_packet.opa_select);
        $display("dopb_select_h 1:%h", 		pipeline_0.dp_packet.opb_select);
        $display("ddest_reg_idx_h 2:%h",       	pipeline_0.dp_packet.dest_reg_idx);
	$display("dhas_dest_h 1:%h",     	pipeline_0.dp_packet.has_dest);
        $display("dalu_func_h 2:%h",       	pipeline_0.dp_packet.alu_func);
        $display("drd_mem_h 1:%h",         	pipeline_0.dp_packet.rd_mem);
        $display("dwr_mem_h 1:%h",         	pipeline_0.dp_packet.wr_mem);
        $display("dcond_branch_h 1:%h",  	pipeline_0.dp_packet.cond_branch);
        $display("duncond_branch_h 1:%h",  	pipeline_0.dp_packet.uncond_branch);
        $display("dhalt_h 1:%h",    		pipeline_0.dp_packet.halt);
        $display("dillegal_h 1:%h",    		pipeline_0.dp_packet.illegal);
        $display("dcsr_op_h 1:%h",  		pipeline_0.dp_packet.csr_op);
	$display("drt_en_h 1:%h",               pipeline_0.rt_dp_packet.wb_regfile_en);
	$display("drt_r_h 8:%h",               pipeline_0.rt_dp_packet.wb_regfile_idx);
	$display("drt_v_h 8:%h",               pipeline_0.rt_dp_packet.wb_regfile_data);

        $display("de1v1valid 1:%h",     	pipeline_0.u_rs.entry[1].v1_valid);
        $display("de1v2valid 1:%h",     	pipeline_0.u_rs.entry[1].v2_valid);
	$display("de2v1valid 1:%h",     	pipeline_0.u_rs.entry[2].v1_valid);
        $display("de2v2valid 1:%h",     	pipeline_0.u_rs.entry[2].v2_valid);
        $display("de3v1valid 1:%h",     	pipeline_0.u_rs.entry[3].v1_valid);
        $display("de3v2valid 1:%h",     	pipeline_0.u_rs.entry[3].v2_valid);
        $display("de4v1valid 1:%h",     	pipeline_0.u_rs.entry[4].v1_valid);
        $display("de4v2valid 1:%h",     	pipeline_0.u_rs.entry[4].v2_valid);
        $display("de5v1valid 1:%h",     	pipeline_0.u_rs.entry[5].v1_valid);
        $display("de5v2valid 1:%h",     	pipeline_0.u_rs.entry[5].v2_valid);
        $display("de6v1valid 1:%h",     	pipeline_0.u_rs.entry[6].v1_valid);
        $display("de6v2valid 1:%h",     	pipeline_0.u_rs.entry[6].v2_valid);
	$display("drobrs_a 8:%h",               pipeline_0.u_rob.rob_rs_packet.rob_dep_a.V);
	$display("drobrs_a 8:%h",               pipeline_0.u_rob.rob_rs_packet.rob_dep_b.V);
	$display("dmpacket_a 8:%h",             pipeline_0.u_map_table.map_packet_a.rob_tag);
	$display("dmpacket_b 8:%h",             pipeline_0.u_map_table.map_packet_b.rob_tag);

        // RS signals (18) - prefix 'h'

        $display("he1_fu_h 1:%h",      	pipeline_0.u_rs.entry[1].fu);
        $display("he1_busy_h 1:%h",      	pipeline_0.u_rs.entry[1].busy);
	$display("he1_r_h 3:%h",      	pipeline_0.u_rs.entry[1].r);
	$display("he1_t1 4:%b",      	pipeline_0.u_rs.entry[1].t1);
	$display("he1_t2 4:%b",      	pipeline_0.u_rs.entry[1].t2);
	$display("he1_v1_h 8:%h",      	pipeline_0.u_rs.entry[1].v1);
	$display("he1_v2_h 8:%h",      	pipeline_0.u_rs.entry[1].v2);
	$display("he1_issued_h 1:%h",     pipeline_0.u_rs.entry[1].issued);
	$display("he1_NPC_h 8:%h",     pipeline_0.u_rs.entry[1].dp_packet.NPC);

	$display("he2_fu_h 1:%h",      	pipeline_0.u_rs.entry[2].fu);
        $display("he2_busy_h 1:%h",      	pipeline_0.u_rs.entry[2].busy);
	$display("he2_r_h 3:%h",      	pipeline_0.u_rs.entry[2].r);
	$display("he2_t1 4:%b",      	pipeline_0.u_rs.entry[2].t1);
	$display("he2_t2 4:%b",      	pipeline_0.u_rs.entry[2].t2);
	$display("he2_v1_h 8:%h",      	pipeline_0.u_rs.entry[2].v1);
	$display("he2_v2_h 8:%h",      	pipeline_0.u_rs.entry[2].v2);
	$display("he2_issued_h 1:%h",     pipeline_0.u_rs.entry[2].issued);
	$display("he2_NPC_h 8:%h",     pipeline_0.u_rs.entry[2].dp_packet.NPC);
	$display("he2_dp_branch 1:%h", pipeline_0.u_rs.entry[2].dp_packet.predicted_branch);

	$display("he3_fu_h 1:%h",      	pipeline_0.u_rs.entry[3].fu);
        $display("he3_busy_h 1:%h",      	pipeline_0.u_rs.entry[3].busy);
	$display("he3_r_h 3:%h",      	pipeline_0.u_rs.entry[3].r);
	$display("he3_t1 4:%b",      	pipeline_0.u_rs.entry[3].t1);
	$display("he3_t2 4:%b",      	pipeline_0.u_rs.entry[3].t2);
	$display("he3_v1_h 8:%h",      	pipeline_0.u_rs.entry[3].v1);
	$display("he3_v2_h 8:%h",      	pipeline_0.u_rs.entry[3].v2);
	$display("he3_issued_h 1:%h",     pipeline_0.u_rs.entry[3].issued);
	$display("he3_NPC_h 8:%h",     pipeline_0.u_rs.entry[3].dp_packet.NPC);

	$display("he4_fu_h 1:%h",      	pipeline_0.u_rs.entry[4].fu);
        $display("he4_busy_h 1:%h",      	pipeline_0.u_rs.entry[4].busy);
	$display("he4_r_h 3:%h",      	pipeline_0.u_rs.entry[4].r);
	$display("he4_t1 4:%b",      	pipeline_0.u_rs.entry[4].t1);
	$display("he4_t2 4:%b",      	pipeline_0.u_rs.entry[4].t2);
	$display("he4_v1_h 8:%h",      	pipeline_0.u_rs.entry[4].v1);
	$display("he4_v2_h 8:%h",      	pipeline_0.u_rs.entry[4].v2);
	$display("he4_issued_h 1:%h",     pipeline_0.u_rs.entry[4].issued);
	$display("he4_NPC_h 8:%h",     pipeline_0.u_rs.entry[4].dp_packet.NPC);

	$display("he5_fu_h 1:%h",      	pipeline_0.u_rs.entry[5].fu);
        $display("he5_busy_h 1:%h",      	pipeline_0.u_rs.entry[5].busy);
	$display("he5_r_h 3:%h",      	pipeline_0.u_rs.entry[5].r);
	$display("he5_t1 4:%b",      	pipeline_0.u_rs.entry[5].t1);
	$display("he5_t2 4:%b",      	pipeline_0.u_rs.entry[5].t2);
	$display("he5_v1_h 8:%h",      	pipeline_0.u_rs.entry[5].v1);
	$display("he5_v2_h 8:%h",      	pipeline_0.u_rs.entry[5].v2);
	$display("he5_issued_h 1:%h",     pipeline_0.u_rs.entry[5].issued);
	$display("he5_NPC_h 8:%h",     pipeline_0.u_rs.entry[5].dp_packet.NPC);


	$display("he6_fu_h 1:%h",      	pipeline_0.u_rs.entry[6].fu);
        $display("he6_busy_h 1:%h",      	pipeline_0.u_rs.entry[6].busy);
	$display("he6_r_h 3:%h",      	pipeline_0.u_rs.entry[6].r);
	$display("he6_t1 4:%b",      	pipeline_0.u_rs.entry[6].t1);
	$display("he6_t2 4:%b",      	pipeline_0.u_rs.entry[6].t2);
	$display("he6_v1_h 8:%h",      	pipeline_0.u_rs.entry[6].v1);
	$display("he6_v2_h 8:%h",       	pipeline_0.u_rs.entry[6].v2);
	$display("he6_issued_h 1:%h",     pipeline_0.u_rs.entry[6].issued);
	$display("he6_NPC_h 8:%h",     pipeline_0.u_rs.entry[6].dp_packet.NPC);
	$display("hd_valid 1:%b", pipeline_0.rs_dispatch_valid);

        // MT signals (4) - prefix 'e'
	$display("ee0 4:%b",     pipeline_0.u_map_table.m_table[0].rob_tag);
	$display("ee0 1:%b",     pipeline_0.u_map_table.m_table[0].t_plus);
        $display("ee1 4:%b",     pipeline_0.u_map_table.m_table[1].rob_tag);
	$display("ee1 1:%b",     pipeline_0.u_map_table.m_table[1].t_plus);
	$display("ee2 4:%b",     pipeline_0.u_map_table.m_table[2].rob_tag);
	$display("ee2 1:%b",     pipeline_0.u_map_table.m_table[2].t_plus);
	$display("ee3 4:%b",     pipeline_0.u_map_table.m_table[3].rob_tag);
	$display("ee3 1:%b",     pipeline_0.u_map_table.m_table[3].t_plus);
	$display("ee4 4:%b",     pipeline_0.u_map_table.m_table[4].rob_tag);
	$display("ee4 1:%b",     pipeline_0.u_map_table.m_table[4].t_plus);
	$display("ee5 4:%b",     pipeline_0.u_map_table.m_table[5].rob_tag);
	$display("ee5 1:%b",     pipeline_0.u_map_table.m_table[5].t_plus);
        $display("ee6 4:%b",     pipeline_0.u_map_table.m_table[6].rob_tag);
	$display("ee6 1:%b",     pipeline_0.u_map_table.m_table[6].t_plus);
	$display("ee7 4:%b",     pipeline_0.u_map_table.m_table[7].rob_tag);
	$display("ee7 1:%b",     pipeline_0.u_map_table.m_table[7].t_plus);
	$display("ee8 4:%b",     pipeline_0.u_map_table.m_table[8].rob_tag);
	$display("ee8 1:%b",     pipeline_0.u_map_table.m_table[8].t_plus);
	$display("ee9 4:%b",     pipeline_0.u_map_table.m_table[9].rob_tag);
	$display("ee9 1:%b",     pipeline_0.u_map_table.m_table[9].t_plus);
	$display("ee10 4:%b",     pipeline_0.u_map_table.m_table[10].rob_tag);
	$display("ee10 1:%b",     pipeline_0.u_map_table.m_table[10].t_plus);
        $display("ee11 4:%b",     pipeline_0.u_map_table.m_table[11].rob_tag);
	$display("ee11 1:%b",     pipeline_0.u_map_table.m_table[11].t_plus);
	$display("ee12 4:%b",     pipeline_0.u_map_table.m_table[12].rob_tag);
	$display("ee12 1:%b",     pipeline_0.u_map_table.m_table[12].t_plus);
	$display("ee13 4:%b",     pipeline_0.u_map_table.m_table[13].rob_tag);
	$display("ee13 1:%b",     pipeline_0.u_map_table.m_table[13].t_plus);
	$display("ee14 4:%b",     pipeline_0.u_map_table.m_table[14].rob_tag);
	$display("ee14 1:%b",     pipeline_0.u_map_table.m_table[14].t_plus);	
	$display("ee15 4:%b",     pipeline_0.u_map_table.m_table[15].rob_tag);
	$display("ee15 1:%b",     pipeline_0.u_map_table.m_table[15].t_plus);
        $display("eh1_busy 1:%b", pipeline_0.u_map_table.m_table_heap_busy[1]);
        $display("eh1_tag 4:%b", pipeline_0.u_map_table.snapshot_rob_tag[1]);
        $display("eh2_busy 1:%b", pipeline_0.u_map_table.m_table_heap_busy[2]);
        $display("eh2_tag 4:%b", pipeline_0.u_map_table.snapshot_rob_tag[2]);
        $display("eh3_busy 1:%b", pipeline_0.u_map_table.m_table_heap_busy[3]);
        $display("eh3_tag 4:%b", pipeline_0.u_map_table.snapshot_rob_tag[3]);
        $display("eh4_busy 1:%b", pipeline_0.u_map_table.m_table_heap_busy[4]);
        $display("eh4_tag 4:%b", pipeline_0.u_map_table.snapshot_rob_tag[4]);
        $display("ert 1: %b", pipeline_0.u_map_table.m_table[5].rob_tag == pipeline_0.u_map_table.rob_map_packet.rob_head.rob_tag && pipeline_0.u_map_table.rob_map_packet.retire_valid);
	// MT signals second section prefix 'v' (32)
	$display("ve16 4:%b",     pipeline_0.u_map_table.m_table[16].rob_tag);
	$display("ve16 1:%b",     pipeline_0.u_map_table.m_table[16].t_plus);
	$display("ve17 4:%b",     pipeline_0.u_map_table.m_table[17].rob_tag);
	$display("ve17 1:%b",     pipeline_0.u_map_table.m_table[17].t_plus);
	$display("ve18 4:%b",     pipeline_0.u_map_table.m_table[18].rob_tag);
	$display("ve18 1:%b",     pipeline_0.u_map_table.m_table[18].t_plus);
	$display("ve19 4:%b",     pipeline_0.u_map_table.m_table[19].rob_tag);
	$display("ve19 1:%b",     pipeline_0.u_map_table.m_table[19].t_plus);
	$display("ve20 4:%b",     pipeline_0.u_map_table.m_table[20].rob_tag);
	$display("ve20 1:%b",     pipeline_0.u_map_table.m_table[20].t_plus);
        $display("ve21 4:%b",     pipeline_0.u_map_table.m_table[21].rob_tag);
	$display("ve21 1:%b",     pipeline_0.u_map_table.m_table[21].t_plus);
	$display("ve22 4:%b",     pipeline_0.u_map_table.m_table[22].rob_tag);
	$display("ve22 1:%b",     pipeline_0.u_map_table.m_table[22].t_plus);
	$display("ve23 4:%b",     pipeline_0.u_map_table.m_table[23].rob_tag);
	$display("ve23 1:%b",     pipeline_0.u_map_table.m_table[23].t_plus);
	$display("ve24 4:%b",     pipeline_0.u_map_table.m_table[24].rob_tag);
	$display("ve24 1:%b",     pipeline_0.u_map_table.m_table[24].t_plus);
	$display("ve25 4:%b",     pipeline_0.u_map_table.m_table[25].rob_tag);
	$display("ve25 1:%b",     pipeline_0.u_map_table.m_table[25].t_plus);
	$display("ve26 4:%b",     pipeline_0.u_map_table.m_table[26].rob_tag);
	$display("ve26 1:%b",     pipeline_0.u_map_table.m_table[26].t_plus);
	$display("ve27 4:%b",     pipeline_0.u_map_table.m_table[27].rob_tag);
	$display("ve27 1:%b",     pipeline_0.u_map_table.m_table[27].t_plus);
	$display("ve28 4:%b",     pipeline_0.u_map_table.m_table[28].rob_tag);
	$display("ve28 1:%b",     pipeline_0.u_map_table.m_table[28].t_plus);
	$display("ve29 4:%b",     pipeline_0.u_map_table.m_table[29].rob_tag);
	$display("ve29 1:%b",     pipeline_0.u_map_table.m_table[29].t_plus);
	$display("ve30 4:%b",     pipeline_0.u_map_table.m_table[30].rob_tag);
	$display("ve30 1:%b",     pipeline_0.u_map_table.m_table[30].t_plus);
	$display("ve31 4:%b",     pipeline_0.u_map_table.m_table[31].rob_tag);
	$display("ve31 1:%b",     pipeline_0.u_map_table.m_table[31].t_plus); 
        $display("vs1_e5 4:%b", pipeline_0.u_map_table.m_table_heap[1][5].rob_tag);
        $display("vs1_e5 1:%b", pipeline_0.u_map_table.m_table_heap[1][5].t_plus);
        $display("vs2_e5 4:%b", pipeline_0.u_map_table.m_table_heap[2][5].rob_tag);
        $display("vs2_e5 1:%b", pipeline_0.u_map_table.m_table_heap[2][5].t_plus);
        $display("vs3_e5 4:%b", pipeline_0.u_map_table.m_table_heap[3][5].rob_tag);
        $display("vs3_e5 1:%b", pipeline_0.u_map_table.m_table_heap[3][5].t_plus);
        $display("vs4_e5 4:%b", pipeline_0.u_map_table.m_table_heap[4][5].rob_tag);
        $display("vs4_e5 1:%b", pipeline_0.u_map_table.m_table_heap[4][5].t_plus);
        $display("vsq1 1:%b",   pipeline_0.u_map_table.squash_heap[1]);
        $display("vsq1 2:%b",   pipeline_0.u_map_table.squash_heap[2]);
        $display("vsq1 3:%b",   pipeline_0.u_map_table.squash_heap[3]);
        $display("vsq1 4:%b",   pipeline_0.u_map_table.squash_heap[4]);
        // ROB signals (49) - prefix 'i'
	$display("irob_head_h 4: %h", pipeline_0.u_rob.head);
	$display("irob_tail_h 4: %h", pipeline_0.u_rob.tail);
	$display("irob_full 1: %b",  pipeline_0.u_rob.full);
	$display("irob_empty 1: %b", pipeline_0.u_rob.empty);
        $display("irob_retire_valid 1: %b", pipeline_0.u_rob.rob_map_packet.retire_valid);

	$display("ie0_r_h 3:%h",      pipeline_0.u_rob.rob_memory[0].r);
	$display("ie0_V_h 8:%h",      pipeline_0.u_rob.rob_memory[0].V);
	$display("ie0_rob_tag_h 3:%h",pipeline_0.u_rob.rob_memory[0].rob_tag);
	$display("ie0_done 1:%b",      pipeline_0.u_rob.rob_memory[0].complete);
	$display("ie0_NPC_h 8:%h",      pipeline_0.u_rob.rob_memory[0].dp_packet.NPC);
	
	$display("ie1_r_h 3:%h",      pipeline_0.u_rob.rob_memory[1].r);
	$display("ie1_V_h 8:%h",      pipeline_0.u_rob.rob_memory[1].V);
	$display("ie1_rob_tag_h 3:%h",pipeline_0.u_rob.rob_memory[1].rob_tag);
	$display("ie1_done_h 1:%b",      pipeline_0.u_rob.rob_memory[1].complete);
	$display("ie1_NPC_h 8:%h",      pipeline_0.u_rob.rob_memory[1].dp_packet.NPC);

	$display("ie2_r_h 3:%h",      pipeline_0.u_rob.rob_memory[2].r);
	$display("ie2_V_h 8:%h",      pipeline_0.u_rob.rob_memory[2].V);
	$display("ie2_rob_tag_h 3:%h",pipeline_0.u_rob.rob_memory[2].rob_tag);
	$display("ie2_done 1:%b",      pipeline_0.u_rob.rob_memory[2].complete);
	$display("ie2_NPC_h 8:%h",      pipeline_0.u_rob.rob_memory[2].dp_packet.NPC);

	$display("ie3_r_h 3:%h",      pipeline_0.u_rob.rob_memory[3].r);
	$display("ie3_V_h 8:%h",      pipeline_0.u_rob.rob_memory[3].V);
	$display("ie3_rob_tag_h 3:%h",pipeline_0.u_rob.rob_memory[3].rob_tag);
	$display("ie3_done 1:%b",      pipeline_0.u_rob.rob_memory[3].complete);
	$display("ie3_NPC_h 8:%h",      pipeline_0.u_rob.rob_memory[3].dp_packet.NPC);

	$display("ie4_r_h 3:%h",      pipeline_0.u_rob.rob_memory[4].r);
	$display("ie4_V_h 8:%h",      pipeline_0.u_rob.rob_memory[4].V);
	$display("ie4_rob_tag_h 3:%h",pipeline_0.u_rob.rob_memory[4].rob_tag);
	$display("ie4_done 1:%b",      pipeline_0.u_rob.rob_memory[4].complete);
	$display("ie4_NPC_h 8:%h",      pipeline_0.u_rob.rob_memory[4].dp_packet.NPC);

	$display("ie5_r_h 3:%h",      pipeline_0.u_rob.rob_memory[5].r);
	$display("ie5_V_h 8:%h",      pipeline_0.u_rob.rob_memory[5].V);
	$display("ie5_rob_tag_h 3:%h",pipeline_0.u_rob.rob_memory[5].rob_tag);
	$display("ie5_done 1:%b",      pipeline_0.u_rob.rob_memory[5].complete);
	$display("ie5_NPC_h 8:%h",      pipeline_0.u_rob.rob_memory[5].dp_packet.NPC);

	$display("ie6_r_h 3:%h",      pipeline_0.u_rob.rob_memory[6].r);
	$display("ie6_V_h 8:%h",      pipeline_0.u_rob.rob_memory[6].V);
	$display("ie6_rob_tag_h 3:%h",pipeline_0.u_rob.rob_memory[6].rob_tag);
	$display("ie6_done 1:%b",      pipeline_0.u_rob.rob_memory[6].complete);
	$display("ie6_NPC_h 8:%h",      pipeline_0.u_rob.rob_memory[6].dp_packet.NPC);

	$display("ie7_r_h 3:%h",      pipeline_0.u_rob.rob_memory[7].r);
	$display("ie7_V_h 8:%h",      pipeline_0.u_rob.rob_memory[7].V);
	$display("ie7_rob_tag_h 3:%h",pipeline_0.u_rob.rob_memory[7].rob_tag);
	$display("ie7_done 1:%b",      pipeline_0.u_rob.rob_memory[7].complete);
	$display("ie7_NPC_h 8:%h",      pipeline_0.u_rob.rob_memory[7].dp_packet.NPC);

	$display("ie8_r_h 3:%h",      pipeline_0.u_rob.rob_memory[8].r);
	$display("ie8_V_h 8:%h",      pipeline_0.u_rob.rob_memory[8].V);
	$display("ie8_rob_tag_h 3:%h",pipeline_0.u_rob.rob_memory[8].rob_tag);
	$display("ie8_done 1:%b",      pipeline_0.u_rob.rob_memory[8].complete);
	$display("ie8_NPC_h 8:%h",      pipeline_0.u_rob.rob_memory[8].dp_packet.NPC);

	$display("irt_r_NPC_h 8:%h",    pipeline_0.u_rob.rob_rt_packet.data_retired.dp_packet.NPC);
	$display("irt_r_idx_h 8:%h",    pipeline_0.u_rob.rob_rt_packet.data_retired.r);
	$display("irt_v 8:%h",    pipeline_0.u_rob.rob_rt_packet.data_retired.V);
	//4:%b   0100

        // EX signals (18) - prefix 'm'
        $display("malu1_done_h 1:%h",   	pipeline_0.u_ex.fu_1.fu_out_packet.done);
        $display("malu1_v_h 8:%h",  	        pipeline_0.u_ex.fu_1.fu_out_packet.v);
	$display("malu1_robtag_h 3:%h",  	pipeline_0.u_ex.fu_1.fu_out_packet.rob_tag);
 	$display("malu1_take_h 1:%h",   	pipeline_0.u_ex.fu_1.fu_out_packet.take_branch);
 	$display("malu1_pred_take_h 1:%h",   	pipeline_0.u_ex.fu_1.fu_in_packet.dp_packet.predicted_branch);
	$display("malu2_done_h 1:%h",   	pipeline_0.u_ex.fu_2.fu_out_packet.done);
        $display("malu2_v_h 8:%h",  	        pipeline_0.u_ex.fu_2.fu_out_packet.v);
	$display("malu2_robtag_h 3:%h",  	pipeline_0.u_ex.fu_2.fu_out_packet.rob_tag);
 	$display("malu2_take_h 1:%h",   	pipeline_0.u_ex.fu_2.fu_out_packet.take_branch);
	$display("mload_done_h 1:%h",   	pipeline_0.u_ex.fu_3.fu_out_packet.done);
        $display("mload_v_h 8:%h",  	        pipeline_0.u_ex.fu_3.fu_out_packet.v);
	$display("mload_robtag_h 3:%h",  	pipeline_0.u_ex.fu_3.fu_out_packet.rob_tag);
        $display("mload_valid 1:%h",  	        pipeline_0.u_ex.fu_3.fu_in_packet.issue_valid);
        $display("mload_mem_ack 1:%h",  	pipeline_0.u_ex.fu_3.mem_ack);
	$display("mstore_done_h 1:%h",   	pipeline_0.u_ex.fu_4.fu_out_packet.done);
        $display("mstore_v_h 8:%h",  	        pipeline_0.u_ex.fu_4.fu_out_packet.v);
	$display("mstore_robtag_h 3:%h",        pipeline_0.u_ex.fu_4.fu_out_packet.rob_tag);
	$display("mmult1_done_h 1:%h",   	pipeline_0.u_ex.fu_5.fu_out_packet.done);
        $display("mmult1_v_h 8:%h",  	        pipeline_0.u_ex.fu_5.fu_out_packet.v);
	$display("mmult1_robtag_h 3:%h",        pipeline_0.u_ex.fu_5.fu_out_packet.rob_tag);
	$display("mmult2_done_h 1:%h",   	pipeline_0.u_ex.fu_6.fu_out_packet.done);
        $display("mmult2_v_h 8:%h",  	        pipeline_0.u_ex.fu_6.fu_out_packet.v);
	$display("mmult2_robtag_h 3:%h",        pipeline_0.u_ex.fu_6.fu_out_packet.rob_tag);
        $display("mclear_fu_1 1:%b",            pipeline_0.u_ex.clear_fu[1]);
        $display("mclear_fu_2 1:%b",            pipeline_0.u_ex.clear_fu[2]);
        $display("mclear_fu_3 1:%b",            pipeline_0.u_ex.clear_fu[3]);       
        $display("mblock_reg_1 1:%b",           pipeline_0.u_ex.block_reg[1]);
        $display("mblock_reg_2 1:%b",           pipeline_0.u_ex.block_reg[2]);
        $display("mfree_rs3 1:%b",              pipeline_0.u_rs.free_tag[3]);
	$display("mbp_taken 1:%b",   	        pipeline_0.u_bpsimple.bp_taken);
	$display("mdp_predicted_taken 1:%b",    pipeline_0.dp_packet.predicted_branch);
	$display("mfu_in_mispredicted 1:%b",    pipeline_0.u_ex.fu_1.fu_in_packet.dp_packet.predicted_branch);
	


	
      

        // CDB signals (2) - prefix 'j'
        $display("jrob_tag_h 3:%h",      pipeline_0.cdb_packet.rob_tag);
        $display("jv_h 8:%h",            pipeline_0.cdb_packet.v);
	$display("jpred_bp_taken 1:%h",	 pipeline_0.u_bpsimple.bp_taken);
        $display("jpred_bp_pc 8:%h",     pipeline_0.u_bpsimple.bp_pc);
	$display("jpred_bp_npc 8:%h",    pipeline_0.u_bpsimple.bp_npc);
	$display("jpred_branch_loc_h 8:%h",    pipeline_0.u_bpsimple.branch_loc);
	$display("jpred_imm 7:%b",    pipeline_0.u_bpsimple.pre_decode_0.branch_imm1);
	$display("jbranch_packet_valid 1:%h",     pipeline_0.u_ex.branch_packet.branch_valid);
	$display("jbranch_packet_mispredicted 1:%h",    pipeline_0.u_ex.branch_packet.mispredicted);
	$display("jbp_pc 8:%h", 			pipeline_0.bp_pc);
	$display("jbp_taken 1:%h", 			pipeline_0.bp_taken);
	$display("jfull_imm 11:%b", 			pipeline_0.u_bpsimple.full_imm);
	$display("jbranch_loc 8:%h", 			pipeline_0.u_bpsimple.branch_loc);
	$display("jbranch_packet_tgpc 8:%h",		pipeline_0.branch_packet.target_PC);
        

        // GLOBAL signals (3) - prefix 'w'
        $display("wdispatch_valid_h 1:%h",     pipeline_0.dispatch_valid);
        $display("wsquash_h 1:%h",      pipeline_0.squash);
        $display("wreset_h 1:%h",       pipeline_0.reset); 
        $display("wproc2mem_addr_h 8:%h", pipeline_0.proc2mem_addr);
        $display("wproc2mem_cmd_h 2:%h", pipeline_0.proc2mem_command);
	$display("wproc2Dmem_size_b 2:%b",	         pipeline_0.u_ex.fu_mem_packet_ld.proc2Dmem_size);
        $display("wmem2proc_data_h 16:%h", pipeline_0.mem2proc_data);
	$display("wmem2proc_response_h 4:%h", pipeline_0.mem2proc_response);
	$display("waddrproc2Dmem_h 8:%h", pipeline_0.u_ex.fu_3.fu_mem_packet.proc2Dmem_addr);
        $display("wsnapshot_taken 1: %h", pipeline_0.u_map_table.take_snapshot);
        $display("wbp_npc_h 8: %h", pipeline_0.bp_npc);
        $display("wbp_pred_taken 1: %b", pipeline_0.pred_bp_taken);


        // Misc signals(2) - prefix 'v'
        

        // must come last
        $display("break");

        // This is a blocking call to allow the debugger to control when we
        // advance the simulation
        waitforresponse();
    end

endmodule // module testbench1
