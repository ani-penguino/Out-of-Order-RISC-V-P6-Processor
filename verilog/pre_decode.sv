module pre_decode(
    input INST inst,
    input valid,
    output logic cond_branch, uncond_branch,
    output logic [6:0] branch_imm1,
    output logic [4:0] branch_imm2,
    output logic jump, link    
);

    
    always_comb begin
        cond_branch   = `FALSE;
        uncond_branch = `FALSE;
        jump    = `FALSE;
        link    = `FALSE;
        branch_imm1 = '0;
        branch_imm2 = '0;
        if (valid) begin
            branch_imm1 = {inst.b.of,inst.b.s};
	    branch_imm2 = {inst.b.et,inst.b.f};
            casez (inst)
            `RV32_JAL: begin
                uncond_branch = `TRUE;
                jump    = `TRUE;
            end
            `RV32_JALR: begin
                uncond_branch = `TRUE;
                link   = `TRUE;
            end
            `RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE,
            `RV32_BLTU, `RV32_BGEU: begin
                cond_branch = `TRUE;
            end
            endcase
        end
    end
    
endmodule
