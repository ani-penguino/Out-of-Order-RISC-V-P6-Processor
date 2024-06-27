`include "/verilog/sys_defs.svh"

module testbench;

    FU_CDB_PACKET fu_cdb_packet;
    CDB_FU_PACKET cdb_fu_packet;
    CDB_PACKET cdb_packet;

    logic clock, reset, clear;

    cdb u_cdb (
    .clock            (clock),
    .reset            (reset),
    .clear            (clear),
    .fu_cdb_packet    (fu_cdb_packet),
    .cdb_fu_packet    (cdb_fu_packet),
    .cdb_packet       (cdb_packet)
);

    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task exit_on_error;
        begin
            $finish;
        end
    endtask

    initial begin

        $monitor("Time: %4.f, dones: %b, ack: %b, tag: %d, v: %d v_in: %d", $time, fu_cdb_packet.dones, cdb_fu_packet.ack, cdb_packet.rob_tag, cdb_packet.v, fu_cdb_packet.v[3]);
        clear = 0;
        clock = 0;
        reset = 1;
        #`CLOCK_PERIOD
        assert(cdb_packet == 0);

        reset = 0;
        #`CLOCK_PERIOD
        fu_cdb_packet.dones = 5'b01100;
        fu_cdb_packet.v = {32'd50, 32'd40, 32'd30, 32'd20, 32'd10};
        fu_cdb_packet.rob_tags = {3'd5, 3'd4, 3'd3, 3'd2, 3'd1};
        #`CLOCK_PERIOD
        #`CLOCK_PERIOD
        assert(cdb_packet.rob_tag == 4);
        assert(cdb_packet.v == 40);
        assert(cdb_fu_packet.ack == 5'b01000);

        $display("@@@ Passed");
        $finish;
    end

endmodule
