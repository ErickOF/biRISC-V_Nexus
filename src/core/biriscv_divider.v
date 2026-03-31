//-----------------------------------------------------------------
//                         biRISC-V CPU
//                            V0.8.1
//                     Ultra-Embedded.com
//                     Copyright 2019-2020
//
//                   admin@ultra-embedded.com
//
//                     License: Apache 2.0
//-----------------------------------------------------------------
// Copyright 2020 Ultra-Embedded.com
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//-----------------------------------------------------------------

module biriscv_divider
(
    // Inputs
     input           clk_i
    ,input           rst_i
    ,input           opcode_valid_i
    ,input  [ 31:0]  opcode_opcode_i
    ,input  [ 31:0]  opcode_pc_i
    ,input           opcode_invalid_i
    ,input  [  4:0]  opcode_rd_idx_i
    ,input  [  4:0]  opcode_ra_idx_i
    ,input  [  4:0]  opcode_rb_idx_i
    ,input  [ 31:0]  opcode_ra_operand_i
    ,input  [ 31:0]  opcode_rb_operand_i
    // pr_rd_i:
    //   Connected from issue/dispatch metadata in core top-level wiring.
    //   Carries the allocated physical destination register for this divide op.
    //   Needed so writeback/CDB update the PRF entry (not only architectural rd).
    ,input  [  5:0]  pr_rd_i
    // rob_tag_i:
    //   Connected from ROB dispatch tag path in core integration.
    //   Identifies which ROB entry owns this in-flight divide instruction.
    //   Needed so completion can mark the correct ROB slot ready/complete.
    ,input  [  4:0]  rob_tag_i

    // Outputs
    ,output          writeback_valid_o
    ,output [ 31:0]  writeback_value_o
    // cdb_val_o:
    //   Connected to shared CDB value bus arbitration at core top-level.
    //   Publishes divider result payload for PRF writeback/consumer wakeup.
    ,output [ 31:0]  cdb_val_o
    // cdb_pr_rd_o:
    //   Connected to CDB physical-destination tag bus.
    //   Tells PRF and dependent instructions which physical register is produced.
    ,output [  5:0]  cdb_pr_rd_o
    // cdb_rob_tag_o:
    //   Connected to CDB ROB-tag bus consumed by ROB completion logic.
    //   Tells ROB exactly which entry completed this cycle.
    ,output [  4:0]  cdb_rob_tag_o
    // cdb_valid_o:
    //   Connected to CDB valid arbitration/selection logic.
    //   Qualifies cdb_* payload as a real completion event.
    ,output          cdb_valid_o
);



//-----------------------------------------------------------------
// Includes
//-----------------------------------------------------------------
`include "biriscv_defs.v"

//-------------------------------------------------------------
// Registers / Wires
//-------------------------------------------------------------
reg          valid_q;
reg  [31:0]  wb_result_q;
// wb_pr_rd_q:
//   Connected forward to cdb_pr_rd_o.
//   Registered copy of destination physical register aligned with completion.
reg  [ 5:0]  wb_pr_rd_q;
// wb_rob_tag_q:
//   Connected forward to cdb_rob_tag_o.
//   Registered copy of owning ROB tag aligned with completion.
reg  [ 4:0]  wb_rob_tag_q;

//-------------------------------------------------------------
// Divider
//-------------------------------------------------------------
wire inst_div_w         = (opcode_opcode_i & `INST_DIV_MASK) == `INST_DIV;
wire inst_divu_w        = (opcode_opcode_i & `INST_DIVU_MASK) == `INST_DIVU;
wire inst_rem_w         = (opcode_opcode_i & `INST_REM_MASK) == `INST_REM;
wire inst_remu_w        = (opcode_opcode_i & `INST_REMU_MASK) == `INST_REMU;

wire div_rem_inst_w     = ((opcode_opcode_i & `INST_DIV_MASK) == `INST_DIV)  || 
                          ((opcode_opcode_i & `INST_DIVU_MASK) == `INST_DIVU) ||
                          ((opcode_opcode_i & `INST_REM_MASK) == `INST_REM)  ||
                          ((opcode_opcode_i & `INST_REMU_MASK) == `INST_REMU);

wire signed_operation_w = ((opcode_opcode_i & `INST_DIV_MASK) == `INST_DIV) || ((opcode_opcode_i & `INST_REM_MASK) == `INST_REM);
wire div_operation_w    = ((opcode_opcode_i & `INST_DIV_MASK) == `INST_DIV) || ((opcode_opcode_i & `INST_DIVU_MASK) == `INST_DIVU);

reg [31:0] dividend_q;
reg [62:0] divisor_q;
reg [31:0] quotient_q;
reg [31:0] q_mask_q;
reg        div_inst_q;
reg        div_busy_q;
reg        invert_res_q;

reg [31:0] last_a_q;
reg [31:0] last_b_q;
reg        last_div_q;
reg        last_divu_q;
reg        last_rem_q;
reg        last_remu_q;

// active_pr_rd_q:
//   Captured from pr_rd_i at div_start_w.
//   Held across the full multi-cycle divide latency.
//   Later transferred to wb_pr_rd_q on div_complete_w.
reg [ 5:0] active_pr_rd_q;
// active_rob_tag_q:
//   Captured from rob_tag_i at div_start_w.
//   Held across the full multi-cycle divide latency.
//   Later transferred to wb_rob_tag_q on div_complete_w.
reg [ 4:0] active_rob_tag_q;

wire div_start_w    = opcode_valid_i & div_rem_inst_w;
wire div_complete_w = !(|q_mask_q) & div_busy_q;

always @(posedge clk_i or posedge rst_i)
if (rst_i)
begin
    div_busy_q     <= 1'b0;
    dividend_q     <= 32'b0;
    divisor_q      <= 63'b0;
    invert_res_q   <= 1'b0;
    quotient_q     <= 32'b0;
    q_mask_q       <= 32'b0;
    div_inst_q     <= 1'b0;
    last_a_q       <= 32'b0;
    last_b_q       <= 32'b0;
    last_div_q     <= 1'b0;
    last_divu_q    <= 1'b0;
    last_rem_q     <= 1'b0;
    last_remu_q    <= 1'b0;
    active_pr_rd_q <= 6'b0;
    active_rob_tag_q <= 5'b0;
end
else if (div_start_w)
begin
    // Capture metadata at launch so completion is associated to this op.
    active_pr_rd_q   <= pr_rd_i;
    active_rob_tag_q <= rob_tag_i;

    // Repeat same operation with same inputs...
    if (last_a_q    == opcode_ra_operand_i && 
        last_b_q    == opcode_rb_operand_i &&
        last_div_q  == inst_div_w &&
        last_divu_q == inst_divu_w &&
        last_rem_q  == inst_rem_w &&
        last_remu_q == inst_remu_w)
    begin
        div_busy_q     <= 1'b1;
    end
    else
    begin
        last_a_q       <= opcode_ra_operand_i;
        last_b_q       <= opcode_rb_operand_i;
        last_div_q     <= inst_div_w;
        last_divu_q    <= inst_divu_w;
        last_rem_q     <= inst_rem_w;
        last_remu_q    <= inst_remu_w;

        div_busy_q     <= 1'b1;
        div_inst_q     <= div_operation_w;

        if (signed_operation_w && opcode_ra_operand_i[31])
            dividend_q <= -opcode_ra_operand_i;
        else
            dividend_q <= opcode_ra_operand_i;

        if (signed_operation_w && opcode_rb_operand_i[31])
            divisor_q <= {-opcode_rb_operand_i, 31'b0};
        else
            divisor_q <= {opcode_rb_operand_i, 31'b0};

        invert_res_q  <= (((opcode_opcode_i & `INST_DIV_MASK) == `INST_DIV) && (opcode_ra_operand_i[31] != opcode_rb_operand_i[31]) && |opcode_rb_operand_i) || 
                         (((opcode_opcode_i & `INST_REM_MASK) == `INST_REM) && opcode_ra_operand_i[31]);

        quotient_q     <= 32'b0;
        q_mask_q       <= 32'h80000000;
    end
end
else if (div_complete_w)
begin
    div_busy_q <= 1'b0;
end
else if (div_busy_q)
begin
    if (divisor_q <= {31'b0, dividend_q})
    begin
        dividend_q <= dividend_q - divisor_q[31:0];
        quotient_q <= quotient_q | q_mask_q;
    end

    divisor_q <= {1'b0, divisor_q[62:1]};
    q_mask_q  <= {1'b0, q_mask_q[31:1]};
end

reg [31:0] div_result_r;
always @ *
begin
    div_result_r = 32'b0;

    if (div_inst_q)
        div_result_r = invert_res_q ? -quotient_q : quotient_q;
    else
        div_result_r = invert_res_q ? -dividend_q : dividend_q;
end

always @(posedge clk_i or posedge rst_i)
if (rst_i)
begin
    valid_q <= 1'b0;
    wb_pr_rd_q <= 6'b0;
    wb_rob_tag_q <= 5'b0;
end
else
begin
    // Completion pulse is one cycle wide; metadata is latched in same event.
    valid_q <= div_complete_w;

    if (div_complete_w)
    begin
        wb_pr_rd_q   <= active_pr_rd_q;
        wb_rob_tag_q <= active_rob_tag_q;
    end
end

always @(posedge clk_i or posedge rst_i)
if (rst_i)
    wb_result_q <= 32'b0;
else if (div_complete_w)
    // Result is registered to keep writeback/CDB outputs stable and aligned
    // with valid_q and destination tags.
    wb_result_q <= div_result_r;

assign writeback_valid_o = valid_q;
assign writeback_value_o  = wb_result_q;
// CDB connectivity mapping:
//   wb_result_q  -> cdb_val_o      (completion value)
//   wb_pr_rd_q   -> cdb_pr_rd_o    (physical destination identity)
//   wb_rob_tag_q -> cdb_rob_tag_o  (ROB completion identity)
//   valid_q      -> cdb_valid_o    (completion qualifier)
// These are consumed by core-level CDB arbitration and then by PRF/ROB logic.
assign cdb_val_o          = wb_result_q;
assign cdb_pr_rd_o        = wb_pr_rd_q;
assign cdb_rob_tag_o      = wb_rob_tag_q;
assign cdb_valid_o        = valid_q;



endmodule
