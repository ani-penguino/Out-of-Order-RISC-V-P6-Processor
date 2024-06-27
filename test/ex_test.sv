
`include "/verilog/sys_defs.svh"
`include "/verilog/ISA.svh"

module testbench;

    logic clock, reset, squash;
    RS_EX_PACKET rs_ex_packet;
    EX_CDB_PACKET ex_cdb_packet;
    CDB_EX_PACKET cdb_ex_packet;
    CDB_PACKET cdb_packet;

    ex u_ex (
        // global signals
        .clock            (clock),
        .reset            (reset),
        .squash           (squash),
        // input packets
        .cdb_packet       (cdb_packet),
        .cdb_ex_packet    (cdb_ex_packet),
        .rs_ex_packet     (rs_ex_packet),
        // output packets
        .ex_cdb_packet    (ex_cdb_packet)
    );

    logic [`NUM_FU:0] dones_dbg, ack_dbg;
    cdb u_cdb (
        // global signals
        .clock            (clock),
        .reset            (reset),
        // input packets
        .ex_cdb_packet    (ex_cdb_packet),
        // output packets
        .cdb_ex_packet    (cdb_ex_packet),
        .cdb_packet       (cdb_packet),
        // debug
        .dones_dbg        (dones_dbg),
        .ack_dbg          (ack_dbg)
    );


    // CLOCK_PERIOD is defined on the commandline by the makefile 30ns
    initial begin
        clock =0;
        forever begin
            #(`CLOCK_PERIOD/2.0);
            clock = ~clock;
        end
    end

    
    // task check_correct;
    //     if (!correct) begin
    //         $display("@@@ Incorrect at time %4.0f", $time);
    //         $display("@@@ done:%b a:%h b:%h result:%h", done, a, b, result);
    //         $display("@@@ Expected result:%h", cres);
    //         $finish;
    //     end
    // endtask


    // Some students have had problems just using "@(posedge done)" because their
    // "done" signals glitch (even though they are the output of a register). This
    // prevents that by making sure "done" is high at the clock edge.
    // task wait_until_done;
    //     forever begin : wait_loop
    //         @(negedge clock);
    //         if (done == 1) begin
    //             if (cdb_packet.rob_tag == tag_in) begin
    //                 disable wait_until_done;
    //             end
    //         end
    //     end
    // endtask


    IF_DP_PACKET [1:0] if_dp_packet;
    DP_PACKET [1:0] dp_packet;
    stage_dp u_stage_dp (
        .clock            (clock),
        .reset            (reset),
        .rt_dp_packet        ('0),
        .if_dp_packet     (if_dp_packet),
        .rob_spaces       ('1),
        .rs_spaces        ('1),
        .lsq_spaces       ('1),
        .dp_packet        (dp_packet),
        .dp_packet_req    ()
    );

    task display_dp_packet (input DP_PACKET dp_pak, input integer i);
        $display("\tBEGIN DP PACKET %3d -->\n\tinst:%32b, PC:%5d, NPC%5d, rs1_value:%5d, rs2_value:%5d\n\
        rs1_valid:%b, rs2_valid:%b, rs1_idx:%2d, rs2_idx:%2d, opa_select:%3d, opb_select:%3d\n\
        dest_idx:%2d, has_dest:%1b, valid:%1b\n\
        END DP PACKET\n",
        i, dp_pak.inst, dp_pak.PC, dp_pak.NPC, dp_pak.rs1_value, dp_pak.rs2_value,
        dp_pak.rs1_valid, dp_pak.rs2_valid, dp_pak.rs1_idx, dp_pak.rs2_idx,
        dp_pak.opa_select, dp_pak.opb_select, dp_pak.dest_reg_idx, dp_pak.has_dest, dp_pak.valid);
    endtask

    task display_fu_in_packet (input FU_IN_PACKET fu_pak, input integer i);
        $display("\tBEGIN FU_IN PACKET %3d -->\n\tinst:%32b, PC:%5d, NPC%5d, rs1_value:%5d, rs2_value:%5d\n\
        rs1_valid:%b, rs2_valid:%b, rs1_idx:%2d, rs2_idx:%2d, opa_select:%3d, opb_select:%3d\n\
        dest_idx:%2d, has_dest:%1b, valid:%1b\n\
        END FU_IN PACKET\n",
        i, fu_pak.inst, fu_pak.PC, fu_pak.NPC, fu_pak.rs1_value, fu_pak.rs2_value,
        fu_pak.rs1_valid, fu_pak.rs2_valid, fu_pak.rs1_idx, fu_pak.rs2_idx,
        fu_pak.opa_select, fu_pak.opb_select, fu_pak.dest_reg_idx, fu_pak.has_dest, fu_pak.valid);
    endtask

    // 32'b0000000_00011_00010_000_00101_0110011 add 2 3 -> 5
    // 32'b000000001000_00100_000_01001_0010011 addi 4 (8) -> 9
    // 32'b0000001_00011_00010_000_00101_0110011 mul 2 3 -> 5
    DP_PACKET dp_pak;
    task test_alu;
        // set up packets
        @(negedge clock);
        reset = 1;
        if_dp_packet[0] = {32'b000000001000_00100_000_01001_0010011, `XLEN'd8, `XLEN'd12, 1'b1}; #2;
        display_dp_packet(dp_packet[0], 1);
        if_dp_packet[0] = {32'b0000000_00011_00010_000_00101_0110011, `XLEN'd4, `XLEN'd8, 1'b1}; #2;
        display_dp_packet(dp_packet[0], 2);
        dp_pak = dp_packet[0];
        dp_pak.rs1_value = 2;
        dp_pak.rs2_value = 3;
        display_dp_packet(dp_pak, 3);
        @(negedge clock);
        reset = 0;
        rs_ex_packet = '0;
        rs_ex_packet.fu_in_packets[1] = dp_pak;
        rs_ex_packet.fu_in_packets[1].rob_tag = 3;
        rs_ex_packet.fu_in_packets[1].issue_valid = 1;
        #2; display_fu_in_packet(rs_ex_packet.fu_in_packets[1], 1);
        $display(ex_cdb_packet.fu_out_packets[1].done);
        @(negedge clock);
        $display(ex_cdb_packet.fu_out_packets[1].done);
        @(negedge clock);
        $display(ex_cdb_packet.fu_out_packets[1].done);
        @(negedge clock);
        $display(ex_cdb_packet.fu_out_packets[1].done);
        @(negedge clock);
        $display(ex_cdb_packet.fu_out_packets[1].done);
        @(negedge clock);
        $display(ex_cdb_packet.fu_out_packets[1].done);
        @(negedge clock);
        $display(ex_cdb_packet.fu_out_packets[1].done);
        $display(ex_cdb_packet.fu_out_packets[1].v);
        
    endtask


    initial begin
        $display("Begin\n");
        // NOTE: monitor starts using 5-digit decimal values for printing
        // $monitor("Time:%4.0f done:%b a:%5d b:%5d result:%5d correct:%5d cdb_tag:%3d cdb_v:%5d dones:%5b ack:%5b",
        //          $time, done, a, b, result, cres, cdb_packet.rob_tag, cdb_packet.v, dones, cdb_ex_packet.ack);
        test_alu();

        $display("@@@ Passed\n");
        $finish;
    end

endmodule
