module BHT (
    input  clock, 
    input  reset, 
    input  wr_en,                  
    input  [`XLEN-1:0] ex_pc,  
    input  take_branch,          
    input  [`XLEN-1:0] if_pc, 
    output [2:0] bht_if_out, 
    output [2:0] bht_ex_out   
);
    logic [2:0] bht [255:0];
    logic [7:0] tail;  
    logic [7:0] head; 

    always_comb begin
        tail = ex_pc[2 +: 8];
        head = if_pc[2 +: 8];
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i = 0; i < 256; i++) begin
                bht[i] <= 0;
            end
        end else if (wr_en) begin
            bht[tail] <= {bht[tail][1:0], take_branch};
        end
    end

    assign bht_if_out = bht[head];
    assign bht_ex_out = bht[tail];

endmodule
