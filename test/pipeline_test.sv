/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  pipeline_test.sv                                    //
//                                                                     //
//  Description :  Testbench module for the verisimple pipeline;       //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "verilog/sys_defs.svh"
// P4 TODO: Add your own debugging framework. Basic printing of data structures
//          is an absolute necessity for the project. You can use C functions
//          like in test/pipeline_print.c or just do everything in verilog.
//          Be careful about running out of space on CAEN printing lots of state
//          for longer programs (alexnet, outer_product, etc.)


// these link to the pipeline_print.c file in this directory, and are used below to print
// detailed output to the pipeline_output_file, initialized by open_pipeline_output_file()
// import "DPI-C" function void open_pipeline_output_file(string file_name);
// import "DPI-C" function void print_header(string str);
// import "DPI-C" function void print_cycles();
// import "DPI-C" function void print_stage(string div, int inst, int npc, int valid_inst);
// import "DPI-C" function void print_reg(int wb_reg_wr_data_out_hi, int wb_reg_wr_data_out_lo,
//                                        int wb_reg_wr_idx_out, int wb_reg_wr_en_out);
// import "DPI-C" function void print_membus(int proc2mem_command, int mem2proc_response,
//                                           int proc2mem_addr_hi, int proc2mem_addr_lo,
//                                           int proc2mem_data_hi, int proc2mem_data_lo);
// import "DPI-C" function void print_close();


module testbench;
    // used to parameterize which files are used for memory and writeback/pipeline outputs
    // "./simv" uses program.mem, writeback.out, and pipeline.out
    // but now "./simv +MEMORY=<my_program>.mem" loads <my_program>.mem instead
    // use +WRITEBACK=<my_program>.wb and +PIPELINE=<my_program>.ppln for those outputs as well
    string program_memory_file;
    string writeback_output_file;
    // string pipeline_output_file;

    // variables used in the testbench
    logic        clock;
    logic        reset;
    logic [31:0] clock_count;
    logic [31:0] instr_count;
    int          wb_fileno;
    logic [63:0] debug_counter; // counter used for infinite loops, forces termination

    logic [1:0]       proc2mem_command;
    logic [`XLEN-1:0] proc2mem_addr;
    logic [63:0]      proc2mem_data;
    logic [3:0]       mem2proc_response;
    logic [63:0]      mem2proc_data;
    logic [3:0]       mem2proc_tag;
`ifndef CACHE_MODE
    MEM_SIZE          proc2mem_size;
`endif

    logic [3:0]         pipeline_completed_insts;
    EXCEPTION_CODE      pipeline_error_status;
    logic [4:0]         pipeline_commit_wr_idx;
    logic [`XLEN-1:0]   pipeline_commit_wr_data;
    logic               pipeline_commit_wr_en;
    logic [`XLEN-1:0]   pipeline_commit_NPC;
  
    logic [`XLEN-1:0]    if_NPC_dbg;
    logic [31:0]         if_inst_dbg;
    logic                if_valid_dbg;
    logic [`XLEN-1:0]    ex_mem_NPC_dbg;
    logic [31:0]         ex_mem_inst_dbg;
    logic                ex_mem_valid_dbg;
    logic [`XLEN-1:0]    mem_wb_NPC_dbg;
    logic [31:0]         mem_wb_inst_dbg;
    logic                mem_wb_valid_dbg;
    MAP_PACKET [31:0]    m_table_dbg;
    logic [`NUM_FU:0]    dones_dbg;
    logic [`NUM_FU:0]    ack_dbg;
    CDB_PACKET           cdb_packet_dbg;
    CDB_EX_PACKET        cdb_ex_packet_dbg;
    MAP_RS_PACKET        map_rs_packet_dbg;
    MAP_ROB_PACKET       map_rob_packet_dbg;
    EX_CDB_PACKET        ex_cdb_packet_dbg;
    DP_PACKET            dp_packet_dbg;
    logic                dp_packet_req_dbg;
    RS_DP_PACKET         avail_vec_dbg;
    RS_EX_PACKET         rs_ex_packet_dbg;
    ROB_RS_PACKET        rob_rs_packet_dbg;
    ROB_MAP_PACKET       rob_map_packet_dbg;
    logic                rob_dp_available_dbg;
    ROB_RT_PACKET        rob_rt_packet_dbg;
    logic                dispatch_valid_dbg;
    logic [`XLEN-1:0]    id_ex_inst_dbg;
    RT_DP_PACKET         rt_dp_packet_dbg;
    IB_DP_PACKET         ib_dp_packet_dbg;
    IF_IB_PACKET         if_ib_packet_dbg;
    logic                ib_full_dbg;
    logic                ib_empty_dbg;
    logic                squash_dbg;
    logic                rs_dispatch_valid_dbg;


    // Instantiate the Pipeline
pipeline u_pipeline (
        .clock                       (clock),
        // System clock
        .reset                       (reset),
        // System reset
        .mem2proc_response           (mem2proc_response),
        // Tag from memory about current request
        .mem2proc_data               (mem2proc_data),
        // Data coming back from memory
        .mem2proc_tag                (mem2proc_tag),
        // Tag from memory about current reply

        .proc2mem_command            (proc2mem_command),
        // Command sent to memory
        .proc2mem_addr               (proc2mem_addr),
        // Address sent to memory
        .proc2mem_data               (proc2mem_data),
        // Data sent to memory

        .proc2mem_size               (proc2mem_size),


        // Note: these are assigned at the very bottom of the module
        .pipeline_completed_insts    (pipeline_completed_insts),
        .pipeline_error_status       (pipeline_error_status),
        .pipeline_commit_wr_idx      (pipeline_commit_wr_idx),
        .pipeline_commit_wr_data     (pipeline_commit_wr_data),
        .pipeline_commit_wr_en       (pipeline_commit_wr_en),
        .pipeline_commit_NPC         (pipeline_commit_NPC),
        // Debug outputs: these signals are solely used for debugging in testbenches
        // Do not change for project 3
        // You should definitely change these for project 4
        .if_NPC_dbg                  (if_NPC_dbg),
        .if_inst_dbg                 (if_inst_dbg),
        .if_valid_dbg                (if_valid_dbg),
        .ex_mem_NPC_dbg              (ex_mem_NPC_dbg),
        .ex_mem_inst_dbg             (ex_mem_inst_dbg),
        .ex_mem_valid_dbg            (ex_mem_valid_dbg),
        .mem_wb_NPC_dbg              (mem_wb_NPC_dbg),
        .mem_wb_inst_dbg             (mem_wb_inst_dbg),
        .mem_wb_valid_dbg            (mem_wb_valid_dbg),
        .m_table_dbg                 (m_table_dbg),
        .dones_dbg                   (dones_dbg),
        .ack_dbg                     (ack_dbg),
        .cdb_packet_dbg              (cdb_packet_dbg),
        .cdb_ex_packet_dbg           (cdb_ex_packet_dbg),
        .map_rs_packet_dbg           (map_rs_packet_dbg),
        .map_rob_packet_dbg          (map_rob_packet_dbg),
        .ex_cdb_packet_dbg           (ex_cdb_packet_dbg),
        .dp_packet_dbg               (dp_packet_dbg),
        .dp_packet_req_dbg           (dp_packet_req_dbg),
        .avail_vec_dbg               (avail_vec_dbg),
        .rs_ex_packet_dbg            (rs_ex_packet_dbg),
        .rob_rs_packet_dbg           (rob_rs_packet_dbg),
        .rob_map_packet_dbg          (rob_map_packet_dbg),
        .rob_dp_available_dbg        (rob_dp_available_dbg),
        .rob_rt_packet_dbg           (rob_rt_packet_dbg),
        .dispatch_valid_dbg          (dispatch_valid_dbg),
        .id_ex_inst_dbg              (id_ex_inst_dbg),
        .rt_dp_packet_dbg            (rt_dp_packet_dbg),
        .ib_dp_packet_dbg            (ib_dp_packet_dbg),
        .if_ib_packet_dbg            (if_ib_packet_dbg),
        .ib_full_dbg                 (ib_full_dbg),
        .ib_empty_dbg                (ib_empty_dbg),
        .squash_dbg                  (squash_dbg),
        .rs_dispatch_valid_dbg       (rs_dispatch_valid_dbg)
    );
    // Instantiate the Data Memory
    mem memory (
        // Inputs
    // .if_NPC_dbg       (if_NPC_dbg),
        // .if_inst_dbg      (if_inst_dbg),
        // .if_valid_dbg     (if_valid_dbg),
        // .if_id_NPC_dbg    (if_id_NPC_dbg),
        // .if_id_inst_dbg   (if_id_inst_dbg),
        // .if_id_valid_dbg  (if_id_valid_dbg),
        // .id_ex_NPC_dbg    (id_ex_NPC_dbg),
        // .id_ex_inst_dbg   (id_ex_inst_dbg),
        // .id_ex_valid_dbg  (id_ex_valid_dbg),
        // .ex_mem_NPC_dbg   (ex_mem_NPC_dbg),
        // .ex_mem_inst_dbg  (ex_mem_inst_dbg),
        // .ex_mem_valid_dbg (ex_mem_valid_dbg),
        // .mem_wb_NPC_dbg   (mem_wb_NPC_dbg),
        // .mem_wb_inst_dbg  (mem_wb_inst_dbg),
        // .mem_wb_valid_dbg (mem_wb_valid_dbg)
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

    // PRINT IF STAGE OUTPUTS
    task print_if_ib();
        $display("IF_IB_PACKET");
        $display("inst: %32b, PC: %4h, NPC: %4h, valid: %b",
        if_ib_packet_dbg.inst, if_ib_packet_dbg.PC, if_ib_packet_dbg.NPC, if_ib_packet_dbg.valid);
        $display("addr:%8h, cmmd:%8h, PC:%4h, inst:%32b", proc2mem_addr, proc2mem_command, if_ib_packet_dbg.PC,
        if_ib_packet_dbg.inst);
    endtask

    // PRINT IB STAGE OUTPUTS
    task print_ib_out();
        $display("IB_DP_PACKET");
        $display("buf_empty:%1b, buf_full:%1b, inst: %32b, PC: %4h, NPC: %4h, valid: %b",
        ib_empty_dbg, ib_full_dbg, ib_dp_packet_dbg.inst, ib_dp_packet_dbg.PC, ib_dp_packet_dbg.NPC, ib_dp_packet_dbg.valid);
    endtask

    // PRINT DP PACKET
    task display_dp_packet (input DP_PACKET dp_pak, input integer i);
        $display("\tBEGIN DP PACKET %3d -->\n\t\tinst:%32b, PC:%4d, NPC:%d, rs1_value:%5d, rs2_value:%5d\n\
        rs1_valid:%b, rs2_valid:%b, rs1_idx:%2d, rs2_idx:%2d, opa_select:%3d, opb_select:%3d\n\
        dest_idx:%2d, has_dest:%1b, valid:%1b, fu_sel:%0d\n\
        END DP PACKET",
        i, dp_pak.inst, dp_pak.PC, dp_pak.NPC, dp_pak.rs1_value, dp_pak.rs2_value,
        dp_pak.rs1_valid, dp_pak.rs2_valid, dp_pak.rs1_idx, dp_pak.rs2_idx,
        dp_pak.opa_select, dp_pak.opb_select, dp_pak.dest_reg_idx, dp_pak.has_dest, dp_pak.valid, dp_pak.fu_sel);
    endtask

    // PRINT RS PACKETS
    task display_fu_in_packet(input FU_IN_PACKET fu_pak, input integer FU_NUM);
        $display("\tBEGIN FU_IN_PACKET (FU = %3d) -->", FU_NUM);
        $display("\t\trob_tag          = %0d", fu_pak.rob_tag);
        $display("\t\tissue_valid      = %0b", fu_pak.issue_valid);
        $display("\t\tfu_id            = %0d", fu_pak.fu_id);
        $display("\t\tinst             = %32b", fu_pak.inst);
        $display("\t\tPC               = %0d", fu_pak.PC);
        $display("\t\tNPC              = %0d", fu_pak.NPC);
        $display("\t\trs1_value        = %0d", fu_pak.rs1_value);
        $display("\t\trs2_value        = %0d", fu_pak.rs2_value);
        $display("\t\trs1_idx          = %0d", fu_pak.rs1_idx);
        $display("\t\trs2_idx          = %0d", fu_pak.rs2_idx);
        $display("\t\trs1_valid        = %0b", fu_pak.rs1_valid);
        $display("\t\trs2_valid        = %0b", fu_pak.rs2_valid);
        $display("\t\topa_select       = %0d", fu_pak.opa_select);
        $display("\t\topb_select       = %0d", fu_pak.opb_select);
        $display("\t\tdest_reg_idx     = %0h", fu_pak.dest_reg_idx);
        $display("\t\thas_dest         = %0d", fu_pak.has_dest);
        $display("\t\talu_func         = %0d", fu_pak.alu_func);
        $display("\t\trd_mem           = %0d", fu_pak.rd_mem);
        $display("\t\twr_mem           = %0d", fu_pak.wr_mem);
        $display("\t\tcond_branch      = %0d", fu_pak.cond_branch);
        $display("\t\tuncond_branch    = %0d", fu_pak.uncond_branch);
        $display("\t\thalt             = %0d", fu_pak.halt);
        $display("\t\tillegal          = %0d", fu_pak.illegal);
        $display("\t\tcsr_op           = %0d", fu_pak.csr_op);
        $display("\t\tvalid            = %0d", fu_pak.valid);
        $display("\tEND FU_IN_PACKET\n");
    endtask

    task display_rs_dbg();
        $display("RS_allocate? %1b", rs_dispatch_valid_dbg);
    endtask

    task display_cdb_dbg();
        $display("CDB STATE:   rob_tag:%2d, v:%5d, dones:%6b, ack:%6b", 
        cdb_packet_dbg.rob_tag, cdb_packet_dbg.v, dones_dbg, ack_dbg);
    endtask

    always begin
        @(negedge clock);
        if(clock_count > 0) begin
            // $display("AFTER CLOCK CYCLE %4d", clock_count);
        //     $display("---------------------------------------------------------------------------------");
        //     $display("dispatch valid:%1b, squash:%1b", dispatch_valid_dbg, squash_dbg);
        //     print_if_ib();
        //     print_ib_out();
        //     display_rs_dbg();
        //     display_dp_packet(dp_packet_dbg, clock_count);
        //     // $display("Full rs_ex_packet:%0b", rs_ex_packet_dbg);
        //     display_fu_in_packet(rs_ex_packet_dbg.fu_in_packets[2], 2);
        //     display_fu_in_packet(rs_ex_packet_dbg.fu_in_packets[3], 3);
	    // $display("rs_ex_packet[4] busy: %d\n", rs_ex_packet_dbg.fu_in_packets[4].issue_valid);
	    // $display("rs_ex_packet[5] busy: %d\n", rs_ex_packet_dbg.fu_in_packets[5].issue_valid);
	    // $display("rs_ex_packet[6] busy: %d\n", rs_ex_packet_dbg.fu_in_packets[6].issue_valid);
        //     display_cdb_dbg();
        //     $display("END CYCLE\n\n\n");
        end
    end


    // Task to display # of elapsed clock edges
    task show_clk_count;
        real cpi;
        begin
            cpi = (clock_count + 1.0) / instr_count;
            $display("@@  %0d cycles / %0d instrs = %f CPI\n@@",
                      clock_count+1, instr_count, cpi);
            $display("@@  %4.2f ns total time to execute\n@@\n",
                      clock_count * `CLOCK_PERIOD);
        end
    endtask // task show_clk_count


    // Show contents of a range of Unified Memory, in both hex and decimal
    task show_mem_with_decimal;
        input [31:0] start_addr;
        input [31:0] end_addr;
        int showing_data;
        begin
            $display("@@@");
            showing_data=0;
            for(int k=start_addr;k<=end_addr; k=k+1)
                if (memory.unified_memory[k] != 0) begin
                    $display("@@@ mem[%5d] = %x : %0d", k*8, memory.unified_memory[k],
                                                             memory.unified_memory[k]);
                    showing_data=1;
                end else if(showing_data!=0) begin
                    $display("@@@");
                    showing_data=0;
                end
            $display("@@@");
        end
    endtask // task show_mem_with_decimal


    initial begin
        //$dumpvars;

        // P4 NOTE: You must keep memory loading here the same for the autograder
        //          Other things can be tampered with somewhat
        //          Definitely feel free to add new output files

        // set paramterized strings, see comment at start of module
        if ($value$plusargs("MEMORY=%s", program_memory_file)) begin
            $display("Loading memory file: %s", program_memory_file);
        end else begin
            $display("Loading default memory file: program.mem");
            program_memory_file = "program.mem";
        end
        if ($value$plusargs("WRITEBACK=%s", writeback_output_file)) begin
            $display("Using writeback output file: %s", writeback_output_file);
        end else begin
            $display("Using default writeback output file: writeback.out");
            writeback_output_file = "writeback.out";
        end
        // if ($value$plusargs("PIPELINE=%s", pipeline_output_file)) begin
        //     $display("Using pipeline output file: %s", pipeline_output_file);
        // end else begin
        //     $display("Using default pipeline output file: pipeline.out");
        //     pipeline_output_file = "pipeline.out";
        // end

        clock = 1'b0;
        reset = 1'b0;

        // Pulse the reset signal
        $display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);
        reset = 1'b1;
        @(posedge clock);
        @(posedge clock);

        // store the compiled program's hex data into memory
        $readmemh(program_memory_file, memory.unified_memory);

        @(posedge clock);
        @(posedge clock);
        #1;
        // This reset is at an odd time to avoid the pos & neg clock edges

        reset = 1'b0;
        $display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime);

        wb_fileno = $fopen(writeback_output_file);

        // Open the pipeline output file after throwing reset
        // open_pipeline_output_file(pipeline_output_file);
        // print_header("removed for line length");
    end


    // Count the number of posedges and number of instructions completed
    // till simulation ends
    always @(posedge clock) begin
        if(reset) begin
            clock_count <= 0;
            instr_count <= 0;
        end else begin
            clock_count <= (clock_count + 1);
            instr_count <= (instr_count + pipeline_completed_insts);
        end
    end


    always @(negedge clock) begin
        if(reset) begin
            $display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
                     $realtime);
            debug_counter <= 0;
        end else begin
            #2;

            // print the pipeline debug outputs via c code to the pipeline output file
            // print_cycles();
            // print_stage(" ", if_inst_dbg,     if_NPC_dbg    [31:0], {31'b0,if_valid_dbg});
            // print_stage("|", if_id_inst_dbg,  if_id_NPC_dbg [31:0], {31'b0,if_id_valid_dbg});
            // print_stage("|", id_ex_inst_dbg,  id_ex_NPC_dbg [31:0], {31'b0,id_ex_valid_dbg});
            // print_stage("|", ex_mem_inst_dbg, ex_mem_NPC_dbg[31:0], {31'b0,ex_mem_valid_dbg});
            // print_stage("|", mem_wb_inst_dbg, mem_wb_NPC_dbg[31:0], {31'b0,mem_wb_valid_dbg});
            // print_reg(32'b0, pipeline_commit_wr_data[31:0],
            //     {27'b0,pipeline_commit_wr_idx}, {31'b0,pipeline_commit_wr_en});
            // print_membus({30'b0,proc2mem_command}, {28'b0,mem2proc_response},
            //     32'b0, proc2mem_addr[31:0],
            //     proc2mem_data[63:32], proc2mem_data[31:0]);

            // print register write information to the writeback output file
            if (pipeline_completed_insts > 0) begin
                if(pipeline_commit_wr_en) begin
                        $fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
                                pipeline_commit_NPC - 4,
                                pipeline_commit_wr_idx,
                                pipeline_commit_wr_data);
                end else begin
                    $fdisplay(wb_fileno, "PC=%x, ---", pipeline_commit_NPC - 4);
                end
                if (instr_count + 1 == 13598) begin
                    $display("clock cycle = %d", clock_count + 1);
                end
            end

            // deal with any halting conditions
            if(pipeline_error_status != NO_ERROR || debug_counter > 50000000) begin // instr_count > 14103 ) begin  //
                $display("@@@ Unified Memory contents hex on left, decimal on right: ");
                show_mem_with_decimal(0,`MEM_64BIT_LINES - 1);
                // 8Bytes per line, 16kB total

                $display("@@  %t : System halted\n@@", $realtime);

                case(pipeline_error_status)
                    LOAD_ACCESS_FAULT:
                        $display("@@@ System halted on memory error");
                    HALTED_ON_WFI:
                        $display("@@@ System halted on WFI instruction");
                    ILLEGAL_INST:
                        $display("@@@ System halted on illegal instruction");
                    default:
                        $display("@@@ System halted on unknown error code %x",
                            pipeline_error_status);
                endcase
                $display("@@@\n@@");
                show_clk_count;
                // print_close(); // close the pipe_print output file
                $fclose(wb_fileno);
                #100 $finish;
            end
            debug_counter <= debug_counter + 1;
        end // if(reset)
    end

endmodule // testbench
