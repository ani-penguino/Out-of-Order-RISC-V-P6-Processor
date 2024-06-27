module BTB (
    input  clock, 
    input  reset,
    input  wr_en,    
    input  [`XLEN-1:0] ex_pc,  
    input  [`XLEN-1:0] ex_tg_pc,
    input  [`XLEN-1:0] if_pc,    

    output logic hit,
    output logic [`XLEN-1:0] predict_pc_out
);
    logic [21:0] mem [255:0];
    logic [255:0] valid;

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i=0; i<256; i++) begin
                mem[i] <= 0;
            end
            valid <= 0;
        end else if (wr_en) begin
            mem[ex_pc[2 +: 8]] <= {ex_pc[10 +: 10], ex_tg_pc[2 +: 12]};
            valid[ex_pc[2 +: 8]] <= 1'b1;
        end
    end

    // Predict the target PC based on the current instruction fetch PC
    assign predict_pc_out = {if_pc[`XLEN-1:14], mem[if_pc[9 -: 8]][11:0],{2{1'b0}}};

    // Check if the instruction fetch PC hits in the BTB
    assign hit = (if_pc[10 +: 10] == mem[if_pc[9-:8]][12 +: 10]) & valid[if_pc[9-:8]];

endmodule
