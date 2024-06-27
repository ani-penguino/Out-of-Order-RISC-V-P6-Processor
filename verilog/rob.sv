///////////////////////////////
//---Completed Version 1.1---//
///////////////////////////////
`timescale 1ns/100ps
`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

//`ifdef TESTBENCH
//    `include "verilog/sys_defs.svh"
//    `define INTERFACE_PORT rob_interface.producer rob_memory_intf
//`else
//    `include "verilog/sys_defs.svh"
//   `define INTERFACE_PORT
//`endif

///////////////////////////////
// ---- ROB Module --------- //
///////////////////////////////
module rob(
    // Basic Signal Input:
    input logic clock,
    input logic reset,
    // Signal for rob:
    // Input packages from Map_Table:
    input MAP_ROB_PACKET map_rob_packet,
    // Input packages from Instructions_Buffer:
    input DP_PACKET instructions_buffer_rob_packet,
    // dispatch available
    // Input packages to ROB
    input CDB_ROB_PACKET cdb_rob_packet,
    //input logic [1:0] dp_rob_available,
    input logic dp_rob_available,
    // misprediction packet from ALU
    input BRANCH_PACKET branch_packet,
    
    // ROB empty, used during squash to retire everything
    output logic rob_empty, 
    // Output packages to Map_Table:
    output ROB_MAP_PACKET rob_map_packet,
    // Output packages to Map_Table:
    output ROB_RS_PACKET rob_rs_packet,
    //output logic [10:0] rob_dp_available, 
    output logic rob_dp_available, 
    // output retire inst to dispatch_module:
    output ROB_RT_PACKET  rob_rt_packet,
    output ROB_EX_PACKET rob_ex_packet

    // Rob_interface, just for rob_test
    //`INTERFACE_PORT
    );

    ///////////////////////////////
    // ----- FIFO internal ----- //
    ///////////////////////////////
    ROB_ENTRY rob_memory [`ROB_SZ :0]; // ROB_SZ default to 8; An empty unit is used to detect full
    
    ROB_TAG head; // head and tail pointer for FIFO
    ROB_TAG tail;

    ROB_ENTRY data_in, new_tail; // Data input to fifo.

    logic full; // FIFO full flag.
    logic empty; // FIFO empty flag.

    assign rob_empty = empty;
    ///////////////////////////////
    //   ROB Operational logic   //
    ///////////////////////////////
    always_comb begin
        // default to 0s
        rob_map_packet = '0;
        new_tail = '0;
        rob_rs_packet ='0;
        rob_rt_packet.data_retired = '0;
        // prepare new tail entry
        new_tail.dp_packet = instructions_buffer_rob_packet;
        new_tail.rob_tag = tail;
        if (instructions_buffer_rob_packet.has_dest)
            new_tail.r = instructions_buffer_rob_packet.dest_reg_idx;
        // fill in map packet
        rob_map_packet.rob_head = rob_memory[head];
        rob_map_packet.rob_new_tail = new_tail;
        rob_map_packet.retire_valid = rob_memory[head].complete && rob_memory[head].dp_packet.valid;
        rob_map_packet.tail = tail;
	    rob_ex_packet.tail = tail;
        // Sending packets to rs:
        rob_rs_packet.rob_tail = new_tail;
	rob_rs_packet.rob_head = rob_memory[head];
        if (map_rob_packet.map_packet_a.rob_tag !== `ZERO_REG)
            rob_rs_packet.rob_dep_a = rob_memory[map_rob_packet.map_packet_a.rob_tag];
        else
            rob_rs_packet.rob_dep_a = `ZERO_REG;

        if (map_rob_packet.map_packet_b.rob_tag !== `ZERO_REG)
            rob_rs_packet.rob_dep_b = rob_memory[map_rob_packet.map_packet_b.rob_tag];
        else
            rob_rs_packet.rob_dep_b = `ZERO_REG;

        // prepare retire packet
        rob_rt_packet.data_retired = rob_memory[head];
        
    end

    ///////////////////////////////
    // -FIFO Operational logic-- //
    ///////////////////////////////
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            for (int i = 0; i <= `ROB_SZ; i++) begin
                rob_memory[i] <= '0;
            end
            // initialize FIFO signals
            head            <= 1;
            tail            <= 1;
        end else begin
            // Retire Logic
            if (!empty && rob_memory[head].complete) begin
                rob_memory[head]           <= '0;
                head <= (head >= `ROB_SZ) ? 1 : (head + 1); // Increment read pointer with wrap-around.
            end
            // Dispatch Logic
            if (!full && dp_rob_available) begin // Accept data available signal from dispatch
                rob_memory[tail] <= new_tail;
                tail <= (tail >= `ROB_SZ) ? 1 : (tail + 1); // Increment write pointer with wrap-around.
            end
            // Check CDB, and update the broadcast value in fifo
            if (cdb_rob_packet.rob_tag !== 0) begin
                for (int index = 1; index <= `ROB_SZ; index++) begin
                    if (rob_memory[index].rob_tag == cdb_rob_packet.rob_tag) begin
                        rob_memory[index].V <= cdb_rob_packet.v;
                        rob_memory[index].complete <= 1'b1;
                        rob_memory[index].branch_mispredicted <= cdb_rob_packet.branch_mispredicted;
                        rob_memory[index].branch_loc <= cdb_rob_packet.branch_loc;
                    end
                end    
            end
            // Squash logic
            if (branch_packet.mispredicted) begin
                // Back in time:
                for (int i = 0; i <= `ROB_SZ; i++) begin
                    if (branch_packet.rob_tag <= tail) begin
                        if (i > branch_packet.rob_tag && i <= tail) begin
                            rob_memory[i] <= '0;
                        end
                    end else begin
                        if (i > branch_packet.rob_tag || i <= tail) begin
                            rob_memory[i] <= '0;
                        end
                    end
                end
                tail <= (branch_packet.rob_tag == `ROB_SZ) ? 1 : (branch_packet.rob_tag + 1) ;
            end     
        end                      
    end

    assign full  = (tail == head)  && rob_memory[head].dp_packet.valid == 1 || (instructions_buffer_rob_packet.fu_sel == STORE && ~empty); // What is empty for?

    // empty if head=tail and the entry is empty 
    assign empty = (head == tail) && rob_memory[head].dp_packet.valid == 0;
    assign rob_dp_available = !full && !branch_packet.mispredicted;

//    always_comb begin
//        `ifdef TESTBENCH
//            foreach (rob_memory_intf.rob_memory[i]) begin
//                rob_memory_intf.rob_memory[i] = rob_memory[i];
//            end
//            rob_memory_intf.full = full;
//            rob_memory_intf.empty = empty;
//            rob_memory_intf.head = head;
//            rob_memory_intf.tail = tail;
//        `endif
//    end
endmodule

///////////////////////////////
// --Interface for rob_test- //
///////////////////////////////
//interface rob_interface;
//    ROB_ENTRY rob_memory[`ROB_SZ :0];
//    logic full;
//    logic empty;
//    ROB_TAG head;
//    ROB_TAG tail;

//    modport producer (
//        output rob_memory,
//        output full,       
//        output empty,
//        output head,
//        output tail  
//    );

//    modport consumer (
//        input rob_memory, 
//        input empty,
//        input full,
//        input head,
//        input tail
//    );
//endinterface
