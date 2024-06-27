
`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

// Decode an instruction: generate useful datapath control signals by matching the RISC-V ISA
// This module is purely combinational
module decoder (
    input IB_DP_PACKET if_packet,

    output ALU_OPA_SELECT opa_select,
    output ALU_OPB_SELECT opb_select,
    output logic          has_dest, //high if dest_reg exist, low if doesn't
    output ALU_FUNC       alu_func,
    output logic          rd_mem, wr_mem, cond_branch, uncond_branch,
    output logic          csr_op, // used for CSR operations, we only use this as a cheap way to get the return code out
    output logic          halt,   // non-zero on a halt
    output logic          illegal, // non-zero on an illegal instruction
    output logic          valid_inst_out,
    output FU_TYPE        fu_sel,
    output logic          has_rs1,
    output logic          has_rs2
);

    assign valid_inst_out = if_packet.valid & ~illegal;

    // Note: I recommend using an IDE's code folding feature on this block
    always_comb begin
        // Default control values (looks like a NOP)
        // See sys_defs.svh for the constants used here
        opa_select    = OPA_IS_RS1;
        opb_select    = OPB_IS_RS2;
        alu_func      = ALU_ADD;
        has_dest      = `FALSE;
        csr_op        = `FALSE;
        rd_mem        = `FALSE;
        wr_mem        = `FALSE;
        cond_branch   = `FALSE;
        uncond_branch = `FALSE;
        halt          = `FALSE;
        illegal       = `FALSE;
        has_rs1       = `FALSE;
        has_rs2       = `FALSE;
        fu_sel        = '0;

        if (if_packet.valid) begin
            casez (if_packet.inst)
                `RV32_LUI: begin
                    has_dest   = `TRUE;
                    opa_select = OPA_IS_ZERO;
                    opb_select = OPB_IS_U_IMM;
                    fu_sel = ALU;
                end
                `RV32_AUIPC: begin
                    has_dest   = `TRUE;
                    opa_select = OPA_IS_PC;
                    opb_select = OPB_IS_U_IMM;
                    fu_sel = ALU;
                end
                `RV32_JAL: begin
                    has_dest      = `TRUE;
                    opa_select    = OPA_IS_PC;
                    opb_select    = OPB_IS_J_IMM;
                    uncond_branch = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_JALR: begin
                    has_dest      = `TRUE;
                    opa_select    = OPA_IS_RS1;
                    opb_select    = OPB_IS_I_IMM;
                    uncond_branch = `TRUE;
                    has_rs1       = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE,
                `RV32_BLTU, `RV32_BGEU: begin
                    opa_select  = OPA_IS_PC;
                    opb_select  = OPB_IS_B_IMM;
                    cond_branch = `TRUE;
                    has_rs1     = `TRUE;
                    has_rs2     = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_LB, `RV32_LH, `RV32_LW,
                `RV32_LBU, `RV32_LHU: begin
                    has_dest   = `TRUE;
                    opb_select = OPB_IS_I_IMM;
                    rd_mem     = `TRUE;
                    has_rs1    = `TRUE;
                    fu_sel     = LOAD;
                end
                `RV32_SB, `RV32_SH, `RV32_SW: begin
                    opb_select = OPB_IS_S_IMM;
                    wr_mem     = `TRUE;
                    has_rs1    = `TRUE;
                    has_rs2    = `TRUE;
                    fu_sel     = STORE;
                end
                `RV32_ADDI: begin
                    has_dest   = `TRUE;
                    opb_select = OPB_IS_I_IMM;
                    has_rs1    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_SLTI: begin
                    has_dest   = `TRUE;
                    opb_select = OPB_IS_I_IMM;
                    alu_func   = ALU_SLT;
                    has_rs1    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_SLTIU: begin
                    has_dest   = `TRUE;
                    opb_select = OPB_IS_I_IMM;
                    alu_func   = ALU_SLTU;
                    has_rs1    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_ANDI: begin
                    has_dest   = `TRUE;
                    opb_select = OPB_IS_I_IMM;
                    alu_func   = ALU_AND;
                    has_rs1    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_ORI: begin
                    has_dest   = `TRUE;
                    opb_select = OPB_IS_I_IMM;
                    alu_func   = ALU_OR;
                    has_rs1    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_XORI: begin
                    has_dest   = `TRUE;
                    opb_select = OPB_IS_I_IMM;
                    alu_func   = ALU_XOR;
                    has_rs1    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_SLLI: begin
                    has_dest   = `TRUE;
                    opb_select = OPB_IS_I_IMM;
                    alu_func   = ALU_SLL;
                    has_rs1    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_SRLI: begin
                    has_dest   = `TRUE;
                    opb_select = OPB_IS_I_IMM;
                    alu_func   = ALU_SRL;
                    has_rs1    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_SRAI: begin
                    has_dest   = `TRUE;
                    opb_select = OPB_IS_I_IMM;
                    alu_func   = ALU_SRA;
                    has_rs1    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_ADD: begin
                    has_dest   = `TRUE;
                    has_rs1    = `TRUE;
                    has_rs2    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_SUB: begin
                    has_dest   = `TRUE;
                    alu_func   = ALU_SUB;
                    has_rs1    = `TRUE;
                    has_rs2    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_SLT: begin
                    has_dest   = `TRUE;
                    alu_func   = ALU_SLT;
                    has_rs1    = `TRUE;
                    has_rs2    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_SLTU: begin
                    has_dest   = `TRUE;
                    alu_func   = ALU_SLTU;
                    has_rs1    = `TRUE;
                    has_rs2    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_AND: begin
                    has_dest   = `TRUE;
                    alu_func   = ALU_AND;
                    has_rs1    = `TRUE;
                    has_rs2    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_OR: begin
                    has_dest   = `TRUE;
                    alu_func   = ALU_OR;
                    has_rs1    = `TRUE;
                    has_rs2    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_XOR: begin
                    has_dest   = `TRUE;
                    alu_func   = ALU_XOR;
                    has_rs1    = `TRUE;
                    has_rs2    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_SLL: begin
                    has_dest   = `TRUE;
                    alu_func   = ALU_SLL;
                    has_rs1    = `TRUE;
                    has_rs2    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_SRL: begin
                    has_dest   = `TRUE;
                    alu_func   = ALU_SRL;
                    has_rs1    = `TRUE;
                    has_rs2    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_SRA: begin
                    has_dest   = `TRUE;
                    alu_func   = ALU_SRA;
                    has_rs1    = `TRUE;
                    has_rs2    = `TRUE;
                    fu_sel = ALU;
                end
                `RV32_MUL: begin
                    has_dest   = `TRUE;
                    alu_func   = ALU_MUL;
                    has_rs1    = `TRUE;
                    has_rs2    = `TRUE;
                    fu_sel     = MULT;
                end
                `RV32_MULH: begin
                    has_dest   = `TRUE;
                    alu_func   = ALU_MULH;
                    has_rs1    = `TRUE;
                    has_rs2    = `TRUE;
                    fu_sel     = MULT;
                end
                `RV32_MULHSU: begin
                    has_dest   = `TRUE;
                    alu_func   = ALU_MULHSU;
                    has_rs1    = `TRUE;
                    has_rs2    = `TRUE;
                    fu_sel     = MULT;
                end
                `RV32_MULHU: begin
                    has_dest   = `TRUE;
                    alu_func   = ALU_MULHU;
                    has_rs1    = `TRUE;
                    has_rs2    = `TRUE;
                    fu_sel     = MULT;
                end
                `RV32_CSRRW, `RV32_CSRRS, `RV32_CSRRC: begin
                    csr_op     = `TRUE;
                    has_rs1    = `TRUE;
                    fu_sel = '0;
                end
                `WFI: begin
                    halt = `TRUE;
                    fu_sel = ALU;
                end
                default: begin
                    illegal = `TRUE;
                    fu_sel = '0;
                end
        endcase // casez (inst)
        end // if (if_packet.valid)
    end // always

endmodule // decoder
