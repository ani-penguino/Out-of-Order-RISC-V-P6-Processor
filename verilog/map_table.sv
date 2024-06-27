// Version 2.0
`include "verilog/sys_defs.svh"

`define TESTBENCH

module map_table(
    // global signals
    input logic clock,
    input logic reset,
    input logic dispatch_valid,

    // input packets
    input CDB_PACKET cdb_packet,
    input ROB_MAP_PACKET rob_map_packet,
    input DP_PACKET dp_packet,
    input BRANCH_PACKET branch_packet,

    // output packets
    output MAP_RS_PACKET map_rs_packet,
    output MAP_ROB_PACKET map_rob_packet,

    // debug
    output MAP_PACKET [31:0] m_table_dbg,
    output logic stall_branch_inst
);

    // map table memory
    MAP_PACKET [31:0] m_table;
    MAP_PACKET [4:0][31:0] m_table_heap;
    logic [4:0] m_table_heap_busy; // reserve 0 for invalid
    logic [4:0][`ROB_TAG_WIDTH:0] snapshot_rob_tag;
    logic [2:0] restore_idx; // Used to find the snapshot to restore to map_table
    // update the map table field when RS says the dispatch is valid and the inst has a destination reg
    wire write_field = dispatch_valid && dp_packet.has_dest && dp_packet.dest_reg_idx != `ZERO_REG;
    // packets for current instr to be dispatched
    MAP_PACKET map_packet_a, map_packet_b;
    
    assign stall_branch_inst = (dp_packet.cond_branch || dp_packet.uncond_branch) && (& m_table_heap_busy);
    // Regular map table
    always_ff @(posedge clock) begin
        if (reset) begin
            for(int i = 0; i < 32; i++) begin
                m_table[i] <= '0;
            end
        end else begin
            // set t_plus tag where cdb tag matches m_table entry (data should now be found in ROB)
            for (int i = 0; i < 32; i++) begin
                // rob_tag = 0 means default.
                if (cdb_packet.rob_tag !== 0) begin
                    m_table[i].t_plus <= (m_table[i].rob_tag == cdb_packet.rob_tag && m_table[i].rob_tag != `ZERO_REG) ? 1 : m_table[i].t_plus;
                end
            end
            // Squash logic
            if (branch_packet.mispredicted) begin
                // Back in time:
                for (int i = 0; i <= `ROB_SZ; i++) begin
                    if (branch_packet.rob_tag <= rob_map_packet.tail) begin
                        if (i > branch_packet.rob_tag && i <= rob_map_packet.tail) begin
                            for (int j = 0; j < 32; j++) begin
                                if (m_table[j].rob_tag == i) begin
                                    m_table[j].t_plus  <= 0;
                                    m_table[j].rob_tag <= 0;
                                end
                            end
                        end
                    end else begin
                        if (i > branch_packet.rob_tag || i <= rob_map_packet.tail) begin
                            for (int j = 0; j < 32; j++) begin
                                if (m_table[j].rob_tag == i) begin
                                    m_table[j].t_plus  <= 0;
                                    m_table[j].rob_tag <= 0;
                                end
                            end
                        end
                    end
                end
		        // Restore to the corresponding snapshot
		        m_table <= m_table_heap[restore_idx];
                if (rob_map_packet.retire_valid) begin
                    for (int i = 0; i < 32; i++) begin
                        if (m_table_heap[restore_idx][i].rob_tag == rob_map_packet.rob_head.rob_tag) begin
                            m_table[i].t_plus  <= 0;
                            m_table[i].rob_tag <= 0;
                        end
                    end
                end
            end
                        // clear table entry when ROB retires an instruction
            if (rob_map_packet.retire_valid) begin
                for (int i = 0; i < 32; i++) begin
                    if (m_table[i].rob_tag == rob_map_packet.rob_head.rob_tag) begin
                        m_table[i].t_plus  <= 0;
                        m_table[i].rob_tag <= 0;
                    end
                end
            end
            // set ROB tag when new instruction dispatched
            // this has priority over clears and t_plus
            if (write_field) begin
                m_table[dp_packet.dest_reg_idx].rob_tag <= rob_map_packet.rob_new_tail.rob_tag;
                m_table[dp_packet.dest_reg_idx].t_plus <= 0;
            end
        end
    end

    logic take_snapshot;
    logic [2:0] heap_idx;
    always_comb begin
        take_snapshot = 0;
        heap_idx = 0;	
        if ((dp_packet.cond_branch || dp_packet.uncond_branch) && (~(& m_table_heap_busy))) begin
            take_snapshot = 1;
            for (int i = 4; i >= 1; i--) begin
                if (~m_table_heap_busy[i]) begin
                    heap_idx = i;
                end
            end
        end
    end

    logic retire_snapshot;
    logic [2:0] retire_idx;
    always_comb begin
        retire_snapshot = 0;
        retire_idx = '0;
        if (rob_map_packet.retire_valid) begin
            // Find snapshots to squash
            for (int i = 1; i <= 4; i++) begin
                if (snapshot_rob_tag[i] == rob_map_packet.rob_head.rob_tag) begin
                    retire_snapshot = 1;
                    retire_idx = i;
                end
            end
        end
    end

    logic [4:0] squash_heap;
    always_comb begin
        squash_heap = '0;
        if (branch_packet.mispredicted) begin
            // Find snapshots to squash
            for (int i = 1; i <= 4; i++) begin
                if (branch_packet.rob_tag <= rob_map_packet.tail) begin
                    if (snapshot_rob_tag[i] >= branch_packet.rob_tag && (snapshot_rob_tag[i] <= rob_map_packet.tail && snapshot_rob_tag[i] != 0)) begin
                        squash_heap[i] = 1;
                    end
                end else begin
                    if (snapshot_rob_tag[i] >= branch_packet.rob_tag || (snapshot_rob_tag[i] <= rob_map_packet.tail && snapshot_rob_tag[i] != 0)) begin
                        squash_heap[i] = 1;
                    end
                end
            end
            // Find particular snapshot used to restore to m_table
            for (int i = 1; i <=4; i++) begin
                if (branch_packet.rob_tag == snapshot_rob_tag[i]) begin
                    restore_idx = i;
                end
            end
        end
    end

    // Map_table_heap: storing snapshots of map table each time a branch is
    // dispatched
    // On every clock cycle, only retire entries in the snapshots, never
    // overwrite it (because an overwrite is a later instruction)
    // Squash should take precedence over new stores (because a new store by
    // definition comes after all the snapshots and must be squashed, or
    // ignored)
    always_ff@(posedge clock) begin
        if (reset) begin
                m_table_heap <= '0;
                m_table_heap_busy <= '0;
                snapshot_rob_tag <= '0;
        end else begin
            // Take snapshot when branch is dispatched
            if (take_snapshot) begin
                m_table_heap[heap_idx] <= m_table;
                snapshot_rob_tag[heap_idx] <= rob_map_packet.tail;
                m_table_heap_busy[heap_idx] <= 1;
                for (int i = 0; i < 32; i++) begin
                    if (m_table[i].rob_tag == rob_map_packet.rob_head.rob_tag && rob_map_packet.retire_valid) begin
                        m_table_heap[heap_idx][i].rob_tag <= '0;
                        m_table_heap[heap_idx][i].t_plus <= 0;                    
                    end
                end
            end
            // Update t_plus for a map_table entry in all snapshots that have
            // it
            for (int i = 0; i <32; i++) begin
                for (int j = 1; j<= 4; j++) begin
                    if (cdb_packet.rob_tag !== 0) begin
                            m_table_heap[j][i].t_plus <= (m_table_heap[j][i].rob_tag == cdb_packet.rob_tag && m_table_heap[j][i].rob_tag != `ZERO_REG) ? 
                                                        1 : m_table_heap[j][i].t_plus;
                    end
                end
            end
            // Clear map_table entries in all snapshots that have it
            if (rob_map_packet.retire_valid) begin
                for (int i = 0; i < 32; i++) begin
                    for (int j = 0; j<= 4; j++) begin
                        if (m_table_heap[j][i].rob_tag == rob_map_packet.rob_head.rob_tag) begin
                            m_table_heap[j][i].t_plus  <= 0;
                            m_table_heap[j][i].rob_tag <= '0;
                        end
                    end
                end
            end
            if (retire_snapshot) begin
                m_table_heap[retire_idx] <= '0;
                snapshot_rob_tag[retire_idx] <= '0;
                m_table_heap_busy[retire_idx] <= 0;
            end
            // Squash snapshot
            if (branch_packet.mispredicted) begin
                for (int i = 1; i <= 4; i++) begin
                    if (squash_heap[i]) begin
                        m_table_heap[i] <= '0;
                        snapshot_rob_tag[i] <= '0;
                        m_table_heap_busy[i] <= 0;
                    end	
                end
            end
        end
    end

    // index map table for rs1 and rs2
    assign map_packet_a =   dp_packet.rs1_valid ? 
                            m_table[dp_packet.rs1_idx] : `ZERO_REG;
    assign map_packet_b =   dp_packet.rs2_valid ? 
                            m_table[dp_packet.rs2_idx] : `ZERO_REG;

    // form output packets
    assign map_rs_packet.map_packet_a = map_packet_a;
    assign map_rs_packet.map_packet_b = map_packet_b;
    assign map_rob_packet = map_rs_packet;

    assign map_table_dbg = m_table;

endmodule
