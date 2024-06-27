module RAS(
    input clock,
    input reset,
    input jal,   
    input jalr,    
    input [`XLEN-1:0] link_pc,    
    output logic [`XLEN-1:0] return_addr  
);
    logic [`XLEN-1:0] mem [7:0]; 
    logic [3:0] ptr, ptr_p1, ptr_m1 ;

    assign return_addr = mem[ptr_m1];

    always_ff @(posedge clock) begin
        if (reset) begin
            ptr <= 0;
            for (int i = 0; i < 8; i++) begin
                mem[i] <= 32'h0;
            end
        end
        else begin
            if (jal && jalr) begin
                ptr <= ptr;
            end
            else if (jal) begin
                ptr <= ptr_p1;
                mem[ptr] <= link_pc + 4;
            end
            else if (jalr) begin
                ptr <= ptr_m1;
            end
            else 
                ptr <= ptr;
        end
    end

    assign ptr_p1 = (&ptr) ? '0 : ptr + 1;
    assign ptr_m1 = (|ptr) ? ptr - 1 : 7;

endmodule
