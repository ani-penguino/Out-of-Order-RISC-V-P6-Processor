/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.svh                                        //
//   Version: 1.0.4                                                    //
//  Description :  This file has the macro-defines for macros used in  //
//                 the pipeline design.                                //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __SYS_DEFS_SVH__
`define __SYS_DEFS_SVH__

// all files should `include "sys_defs.svh" to at least define the timescale
`timescale 1ns/100ps

///////////////////////////////////
// ---- Starting Parameters ---- //
///////////////////////////////////

// some starting parameters that you should set
// this is *your* processor, you decide these values (try analyzing which is best!)

// superscalar width
`define N 1

// sizes
`define ROB_SZ 8
`define IBUFFER_SZ 16
`define RS_SZ xx
`define PHYS_REG_SZ (32 + `ROB_SZ)

// worry about these later
`define BRANCH_PRED_SZ xx
`define LSQ_SZ xx

// functional units (you should decide if you want more or fewer types of FUs)
`define NUM_FU_ALU xx
`define NUM_FU_MULT xx
`define NUM_FU_LOAD xx
`define NUM_FU_STORE xx

// number of mult stages (2, 4, or 8)
`define MULT_STAGES 4

///////////////////////////////
// ---- Basic Constants ---- //
///////////////////////////////

// NOTE: the global CLOCK_PERIOD is defined in the Makefile

// useful boolean single-bit definitions
`define FALSE 1'h0
`define TRUE  1'h1

// data length
`define XLEN 32

// the zero register
// In RISC-V, any read of this register returns zero and any writes are thrown away
`define ZERO_REG '0

// Basic NOP instruction. Allows pipline registers to clearly be reset with
// an instruction that does nothing instead of Zero which is really an ADDI x0, x0, 0
`define NOP 32'h00000013

//////////////////////////////////
// ---- Memory Definitions ---- //
//////////////////////////////////

// Cache mode removes the byte-level interface from memory, so it always returns
// a double word. The original processor won't work with this defined. Your new
// processor will have to account for this effect on mem.
// Notably, you can no longer write data without first reading.
//`define CACHE_MODE

// you are not allowed to change this definition for your final processor
// the project 3 processor has a massive boost in performance just from having no mem latency
// see if you can beat it's CPI in project 4 even with a 100ns latency!
`define MEM_LATENCY_IN_CYCLES  0
//`define MEM_LATENCY_IN_CYCLES (100.0/`CLOCK_PERIOD+0.49999)
// the 0.49999 is to force ceiling(100/period). The default behavior for
// float to integer conversion is rounding to nearest

// How many memory requests can be waiting at once
`define NUM_MEM_TAGS 15

`define MEM_SIZE_IN_BYTES (64*1024)
`define MEM_64BIT_LINES   (`MEM_SIZE_IN_BYTES/8)

typedef union packed {
    logic [7:0][7:0]  byte_level;
    logic [3:0][15:0] half_level;
    logic [1:0][31:0] word_level;
} EXAMPLE_CACHE_BLOCK;

typedef enum logic [1:0] {
    BYTE   = 2'h0,
    HALF   = 2'h1,
    WORD   = 2'h2,
    DOUBLE = 2'h3
} MEM_SIZE;

// Memory bus commands
typedef enum logic [1:0] {
    BUS_NONE   = 2'h0,
    BUS_LOAD   = 2'h1,
    BUS_STORE  = 2'h2
} BUS_COMMAND;

///////////////////////////////
// ---- Exception Codes ---- //
///////////////////////////////

/**
 * Exception codes for when something goes wrong in the processor.
 * Note that we use HALTED_ON_WFI to signify the end of computation.
 * It's original meaning is to 'Wait For an Interrupt', but we generally
 * ignore interrupts in 470
 *
 * This mostly follows the RISC-V Privileged spec
 * except a few add-ons for our infrastructure
 * The majority of them won't be used, but it's good to know what they are
 */

typedef enum logic [3:0] {
    INST_ADDR_MISALIGN  = 4'h0,
    INST_ACCESS_FAULT   = 4'h1,
    ILLEGAL_INST        = 4'h2,
    BREAKPOINT          = 4'h3,
    LOAD_ADDR_MISALIGN  = 4'h4,
    LOAD_ACCESS_FAULT   = 4'h5,
    STORE_ADDR_MISALIGN = 4'h6,
    STORE_ACCESS_FAULT  = 4'h7,
    ECALL_U_MODE        = 4'h8,
    ECALL_S_MODE        = 4'h9,
    NO_ERROR            = 4'ha, // a reserved code that we use to signal no errors
    ECALL_M_MODE        = 4'hb,
    INST_PAGE_FAULT     = 4'hc,
    LOAD_PAGE_FAULT     = 4'hd,
    HALTED_ON_WFI       = 4'he, // 'Wait For Interrupt'. In 470, signifies the end of computation
    STORE_PAGE_FAULT    = 4'hf
} EXCEPTION_CODE;

///////////////////////////////////
// ---- Instruction Typedef ---- //
///////////////////////////////////

// from the RISC-V ISA spec
typedef union packed {
    logic [31:0] inst;
    struct packed {
        logic [6:0] funct7;
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1
        logic [2:0] funct3;
        logic [4:0] rd; // destination register
        logic [6:0] opcode;
    } r; // register-to-register instructions
    struct packed {
        logic [11:0] imm; // immediate value for calculating address
        logic [4:0]  rs1; // source register 1 (used as address base)
        logic [2:0]  funct3;
        logic [4:0]  rd;  // destination register
        logic [6:0]  opcode;
    } i; // immediate or load instructions
    struct packed {
        logic [6:0] off; // offset[11:5] for calculating address
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1 (used as address base)
        logic [2:0] funct3;
        logic [4:0] set; // offset[4:0] for calculating address
        logic [6:0] opcode;
    } s; // store instructions
    struct packed {
        logic       of;  // offset[12]
        logic [5:0] s;   // offset[10:5]
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1
        logic [2:0] funct3;
        logic [3:0] et;  // offset[4:1]
        logic       f;   // offset[11]
        logic [6:0] opcode;
    } b; // branch instructions
    struct packed {
        logic [19:0] imm; // immediate value
        logic [4:0]  rd; // destination register
        logic [6:0]  opcode;
    } u; // upper-immediate instructions
    struct packed {
        logic       of; // offset[20]
        logic [9:0] et; // offset[10:1]
        logic       s;  // offset[11]
        logic [7:0] f;  // offset[19:12]
        logic [4:0] rd; // destination register
        logic [6:0] opcode;
    } j;  // jump instructions

// extensions for other instruction types
`ifdef ATOMIC_EXT
    struct packed {
        logic [4:0] funct5;
        logic       aq;
        logic       rl;
        logic [4:0] rs2;
        logic [4:0] rs1;
        logic [2:0] funct3;
        logic [4:0] rd;
        logic [6:0] opcode;
    } a; // atomic instructions
`endif
`ifdef SYSTEM_EXT
    struct packed {
        logic [11:0] csr;
        logic [4:0]  rs1;
        logic [2:0]  funct3;
        logic [4:0]  rd;
        logic [6:0]  opcode;
    } sys; // system call instructions
`endif

} INST; // instruction typedef, this should cover all types of instructions

////////////////////////////////////////
// ---- Datapath Control Signals ---- //
////////////////////////////////////////

// ALU opA input mux selects
typedef enum logic [1:0] {
    OPA_IS_RS1  = 2'h0,
    OPA_IS_NPC  = 2'h1,
    OPA_IS_PC   = 2'h2,
    OPA_IS_ZERO = 2'h3
} ALU_OPA_SELECT;

// ALU opB input mux selects
typedef enum logic [3:0] {
    OPB_IS_RS2    = 4'h0,
    OPB_IS_I_IMM  = 4'h1,
    OPB_IS_S_IMM  = 4'h2,
    OPB_IS_B_IMM  = 4'h3,
    OPB_IS_U_IMM  = 4'h4,
    OPB_IS_J_IMM  = 4'h5
} ALU_OPB_SELECT;

// ALU function code input
// probably want to leave these alone
typedef enum logic [4:0] {
    ALU_ADD     = 5'h00,
    ALU_SUB     = 5'h01,
    ALU_SLT     = 5'h02,
    ALU_SLTU    = 5'h03,
    ALU_AND     = 5'h04,
    ALU_OR      = 5'h05,
    ALU_XOR     = 5'h06,
    ALU_SLL     = 5'h07,
    ALU_SRL     = 5'h08,
    ALU_SRA     = 5'h09,
    ALU_MUL     = 5'h0a, // Mult FU
    ALU_MULH    = 5'h0b, // Mult FU
    ALU_MULHSU  = 5'h0c, // Mult FU
    ALU_MULHU   = 5'h0d, // Mult FU
    ALU_DIV     = 5'h0e, // unused
    ALU_DIVU    = 5'h0f, // unused
    ALU_REM     = 5'h10, // unused
    ALU_REMU    = 5'h11  // unused
} ALU_FUNC;
/* The type of functional unit corresponding to an instruction. To be used in
* issue stage to match an instruction to a functioanl unit
* */
typedef enum logic [2:0] {
    ALU = 1,
    LOAD = 2,
    STORE = 3,
    MULT = 4
} FU_TYPE;


////////////////////////////////
// ---- Datapath Packets ---- //
////////////////////////////////

/**
 * Packets are used to move many variables between modules with
 * just one datatype, but can be cumbersome in some circumstances.
 *
 * Define new ones in project 4 at your own discretion
 */

/**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
 * IF_ID Packet:
 * Data exchanged from the IF to the ID stage
 */
typedef struct packed {
    INST              inst;
    logic [`XLEN-1:0] PC;
    logic [`XLEN-1:0] NPC; // PC + 4
    logic             valid;
    logic 	      pred_bp_taken;
} IF_IB_PACKET;

typedef struct packed {
    INST              inst;
    logic [`XLEN-1:0] PC;
    logic [`XLEN-1:0] NPC; // PC + 4
    logic             valid;
    logic 	      pred_bp_taken;
} IB_DP_PACKET;

/**
 * ID_RS Packet:
 * Data exchanged from the ID to the EX stage
 */
typedef struct packed {
    INST              inst;
    logic [`XLEN-1:0] PC;
    logic [`XLEN-1:0] NPC; // PC + 4

    logic [`XLEN-1:0] rs1_value; // reg A value
    logic [`XLEN-1:0] rs2_value; // reg B value

    logic [4:0] rs1_idx; // reg A index
    logic [4:0] rs2_idx; // reg B index

    logic rs1_valid; // reg A used
    logic rs2_valid; // reg B used

    ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
    ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)

    logic [4:0] dest_reg_idx;  // destination (writeback) register index
    logic rd_valid;            // destination register is used

    ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
    logic       rd_mem;        // Does inst read memory?
    logic       wr_mem;        // Does inst write memory?
    logic       cond_branch;   // Is inst a conditional branch?
    logic       uncond_branch; // Is inst an unconditional branch?
    logic       halt;          // Is this a halt?
    logic       illegal;       // Is this instruction illegal?
    logic       csr_op;        // Is this a CSR operation? (we use this to get return code)

    logic       valid;
} ID_RS_PACKET;

/**
 * DP Packet:
 * Data exchanged from the DP to the ROB, RS, LSQ stage
 */
typedef struct packed {

    FU_TYPE     fu_sel;	       // The type of functional unit

    // DO NOT ADD BELOW THIS LINE
    INST              inst;
    logic [`XLEN-1:0] PC;
    logic [`XLEN-1:0] NPC; // PC + 4

    logic [`XLEN-1:0] rs1_value; // reg A value
    logic [`XLEN-1:0] rs2_value; // reg B value

    logic [4:0] rs1_idx; // reg A index
    logic [4:0] rs2_idx; // reg B index

    logic rs1_valid; // reg A used
    logic rs2_valid; // reg B used

    ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
    ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)

    logic [4:0] dest_reg_idx;  // destination (writeback) register index
    logic has_dest;            // destination register is used

    ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
    logic       rd_mem;        // Does inst read memory?
    logic       wr_mem;        // Does inst write memory?
    logic       cond_branch;   // Is inst a conditional branch?
    logic       uncond_branch; // Is inst an unconditional branch?
    logic       halt;          // Is this a halt?
    logic       illegal;       // Is this instruction illegal?
    logic       csr_op;        // Is this a CSR operation? (we use this to get return code)
    logic       valid;
    logic       predicted_branch;
} DP_PACKET;

/**
 * EX_MEM Packet:
 * Data exchanged from the EX to the MEM stage
 */
typedef struct packed {
    logic [`XLEN-1:0] alu_result;
    logic [`XLEN-1:0] NPC;

    logic             take_branch; // Is this a taken branch?
    // Pass-through from decode stage
    logic [`XLEN-1:0] rs2_value;
    logic             rd_mem;
    logic             wr_mem;
    logic [4:0]       dest_reg_idx;
    logic             halt;
    logic             illegal;
    logic             csr_op;
    logic             rd_unsigned; // Whether proc2Dmem_data is signed or unsigned
    MEM_SIZE          mem_size;
    logic             valid;
} EX_MEM_PACKET;



/**
 * MEM_WB Packet:
 * Data exchanged from the MEM to the WB stage
 *
 * Does not include data sent from the MEM stage to memory
 */
typedef struct packed {
    logic [`XLEN-1:0] result;
    logic [`XLEN-1:0] NPC;
    logic [4:0]       dest_reg_idx; // writeback destination (ZERO_REG if no writeback)
    logic             take_branch;
    logic             halt;    // not used by wb stage
    logic             illegal; // not used by wb stage
    logic             valid;
} MEM_WB_PACKET;

`define NUM_FU 6
`define NUM_RS 6

// TODO: add a macro for number of ROB entries
`define ROB_TAG_WIDTH $clog2(`ROB_SZ) // entry[0] is reserved
typedef logic [`ROB_TAG_WIDTH :0] ROB_TAG;

typedef struct packed {
    ROB_TAG t1;
    ROB_TAG t2;
    logic [`XLEN-1:0] v1;
    logic [`XLEN-1:0] v2;
    logic v1_valid, v2_valid;
    FU_TYPE fu;
    ROB_TAG r; // TODO: width of this register needs to be changed according to number of ROB entries
    logic [6:0] opcode;
    logic valid;
    logic busy;
    logic issued;
    DP_PACKET dp_packet;
} RS_ENTRY;

`define RS_TAG_WIDTH $clog2(5)
typedef logic [`RS_TAG_WIDTH - 1:0] RS_TAG;
// Double check the above for syntax

typedef struct packed {
    logic complete;
    logic [$clog2(`XLEN) -1:0] r; //logic [4:0] r
    logic [`XLEN-1:0] V;
    logic branch_mispredicted;
    logic [`XLEN-1:0] branch_loc;
    ROB_TAG rob_tag;
    DP_PACKET dp_packet;
} ROB_ENTRY;

// ROB_RT_PACKET

typedef struct packed {
    ROB_ENTRY data_retired;
} ROB_RT_PACKET;

// typedef struct packed {
//     ROB_ENTRY data_retired;
//     logic valid;
// } RT_DP_PACKET;

// Map Table Packet
typedef struct packed {
    ROB_TAG rob_tag;    // ROB#
    logic t_plus;   // tag that indicates value should be found in ROB table
} MAP_PACKET;

// Map Table to RS Packet
typedef struct packed {
    MAP_PACKET map_packet_a;
    MAP_PACKET map_packet_b;
} MAP_RS_PACKET;

// Map Table to ROB Packet
typedef struct packed {
    MAP_PACKET map_packet_a;
    MAP_PACKET map_packet_b;
} MAP_ROB_PACKET;

// ROB to RS Packet
typedef struct packed {
    ROB_ENTRY rob_tail, rob_head;     // current instr that is being dispatched
    ROB_ENTRY rob_dep_a;    // entries corresponding to dependencies as seen in map table
    ROB_ENTRY rob_dep_b;    // entries corresponding to dependencies as seen in map table
} ROB_RS_PACKET;

typedef struct packed {
    ROB_TAG tail;
} ROB_EX_PACKET;

// ROB to RS Packet
typedef struct packed {
    ROB_ENTRY rob_head, rob_new_tail;     // current instr that is being retired
    ROB_TAG tail;
    logic retire_valid;      // are we clearing the head from the ROB and map table?
} ROB_MAP_PACKET;

// Individual packet taken by FU (grouped in RS_FU_PACKET)
typedef struct packed {

    ROB_TAG rob_tag;
    logic issue_valid;      // goes high when RS issues instr
    logic [`RS_TAG_WIDTH-1:0] fu_id; // index of the fu unit in fu-related packets (same as rs index of fu)

    // DO NOT ADD BELOW THIS LINE
    INST              inst;
    logic [`XLEN-1:0] PC;
    logic [`XLEN-1:0] NPC; // PC + 4

    logic [`XLEN-1:0] rs1_value; // reg A value
    logic [`XLEN-1:0] rs2_value; // reg B value

    logic [4:0] rs1_idx; // reg A index
    logic [4:0] rs2_idx; // reg B index

    logic rs1_valid; // reg A used
    logic rs2_valid; // reg B used

    ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
    ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)

    logic [4:0] dest_reg_idx;  // destination (writeback) register index
    logic has_dest;            // destination register is used

    ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
    logic       rd_mem;        // Does inst read memory?
    logic       wr_mem;        // Does inst write memory?
    logic       cond_branch;   // Is inst a conditional branch?
    logic       uncond_branch; // Is inst an unconditional branch?
    logic       halt;          // Is this a halt?
    logic       illegal;       // Is this instruction illegal?
    logic       csr_op;        // Is this a CSR operation? (we use this to get return code)

    logic       valid;
    DP_PACKET   dp_packet;

} FU_IN_PACKET;

typedef struct packed {
    logic [1:0]       proc2Dmem_command;
    MEM_SIZE          proc2Dmem_size;
    logic [`XLEN-1:0] proc2Dmem_addr;   
    logic [`XLEN-1:0] proc2Dmem_data;
    ROB_TAG           rob_tag;
    logic             valid;
} FU_MEM_PACKET;

typedef struct packed {
    logic [`XLEN-1:0]   Dmem2proc_data;
} MEM_FU_PACKET;

// RS to all FU Packet
typedef struct packed {
    FU_IN_PACKET [`NUM_FU : 0] fu_in_packets;
} RS_EX_PACKET;

// Packet from FU to CDB (individual)
typedef struct packed {
   logic  done;  // Done signals from FU
   ROB_TAG rob_tag;
   logic [`XLEN-1:0] v;
   logic take_branch;
   logic [`XLEN-1:0] branch_loc;
   logic mispredicted;
   logic [`XLEN-1:0] origin_PC;
   logic  cond_br_en;
   logic  br_en;
} FU_OUT_PACKET;

typedef logic [`NUM_FU : 0] FU_DONE_PACKET;

typedef struct packed {
   logic  branch_valid;
   logic  cond_br_en;
   logic  br_en;
   ROB_TAG rob_tag;
   logic [`XLEN-1:0] origin_PC, target_PC;
   logic mispredicted;
} BRANCH_PACKET;

// FU_CDB Packet
typedef struct packed {
    FU_OUT_PACKET [`NUM_FU: 0] fu_out_packets;
} EX_CDB_PACKET;

typedef struct packed {
   logic  [`NUM_FU:0] ack;  // ack signals from cdb
} CDB_EX_PACKET;

typedef struct packed {
    ROB_TAG rob_tag;
    logic [`XLEN-1:0] v;
    logic branch_mispredicted;
    logic [`XLEN-1:0] branch_loc;
} CDB_PACKET;

typedef struct packed {
    ROB_TAG rob_tag;
    logic [`XLEN-1:0] v;
    logic branch_mispredicted;
    logic [`XLEN-1:0] branch_loc;
} CDB_ROB_PACKET;

typedef struct packed {
    FU_TYPE fu;
    logic available;
} AVAIL_VEC;

typedef struct packed {
	logic con_br_en;    
	logic br_en;
	logic con_br_taken;    // condition branch taken
	logic [`XLEN-1:0] PC;    // current PC
    logic [`XLEN-1:0] target_pc;    // target PC
} EX_BP_PACKET;

typedef struct packed {
	logic		  wb_regfile_halt;
	logic 		  wb_regfile_en;
	logic [4:0]       wb_regfile_idx;
	logic [`XLEN-1:0] wb_regfile_data;
} RT_DP_PACKET;

typedef enum logic [1:0]{
	NT_STRONG = 2'h0,
	NT_WEAK   = 2'h1,
	T_WEAK    = 2'h2,
	T_STRONG  = 2'h3
} PHT_STATE;
typedef AVAIL_VEC [`NUM_RS:0] RS_DP_PACKET;
/**
 * No WB output packet as it would be more cumbersome than useful
 */

`endif // __SYS_DEFS_SVH__
