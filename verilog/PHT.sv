module PHT (
    input  clock, 
    input  reset,
    input  wr_en,
    input  [`XLEN-1:0] ex_pc, 
    input  take_branch,  
    input  [`XLEN-1:0] if_pc,   
    input  [3:0] bht_if_in,  
    input  [3:0] bht_ex_in,  
    output logic predict_taken 
);
    PHT_STATE  state   [255:0][7:0];
    PHT_STATE  n_state [255:0][7:0];

    logic [7:0] tail;    
    logic [7:0] head;   

    always_comb begin
        tail = ex_pc[2 +: 8];
        head = if_pc[2 +: 8];
    end

    always_comb begin
        n_state = state;
        case (state[tail][bht_ex_in])
            NT_STRONG: n_state[tail][bht_ex_in] = take_branch ? NT_WEAK : NT_STRONG;
            NT_WEAK:   n_state[tail][bht_ex_in] = take_branch ? T_STRONG : NT_STRONG;
            T_WEAK:    n_state[tail][bht_ex_in] = take_branch ? T_STRONG : NT_WEAK;
            T_STRONG:  n_state[tail][bht_ex_in] = take_branch ? T_STRONG : T_WEAK;
        endcase
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i = 0; i < 256; i++) begin
                for (int j = 0; j < 8; j++) begin
                    state[i][j] <= NT_WEAK;
                end
            end
        end else if (wr_en) begin
            state[tail][bht_ex_in] <= n_state[tail][bht_ex_in];
        end
    end

    always_comb begin
        predict_taken = (state[head][bht_if_in] == T_WEAK || state[head][bht_if_in] == T_STRONG);
    end

endmodule

