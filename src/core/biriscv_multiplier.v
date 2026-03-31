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

module biriscv_multiplier
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
    //   Connected from issue/dispatch destination metadata in core top-level.
    //   Carries the allocated physical destination register for MUL/MULH*.
    //   Required so CDB/PRF update targets renamed destination.
    ,input  [  5:0]  pr_rd_i
    // rob_tag_i:
    //   Connected from ROB dispatch tag path in core integration.
    //   Identifies the ROB entry that owns this multiply op.
    //   Required so completion marks the correct ROB slot ready.
    ,input  [  4:0]  rob_tag_i
    ,input           hold_i

    // Outputs
    ,output [ 31:0]  writeback_value_o
    // cdb_val_o / cdb_pr_rd_o / cdb_rob_tag_o / cdb_valid_o:
    //   Connected to global CDB arbitration in riscv_core.
    //   Provide value + physical destination + ROB identity + valid pulse so
    //   PRF writeback and ROB completion attribution stay aligned.
    ,output [ 31:0]  cdb_val_o
    ,output [  5:0]  cdb_pr_rd_o
    ,output [  4:0]  cdb_rob_tag_o
    ,output          cdb_valid_o
);



//-----------------------------------------------------------------
// Includes
//-----------------------------------------------------------------
`include "biriscv_defs.v"

localparam MULT_STAGES = 2; // 2 or 3

//-------------------------------------------------------------
// Registers / Wires
//-------------------------------------------------------------
reg  [31:0]  result_e2_q;
reg  [31:0]  result_e3_q;
reg          valid_e2_q;
reg          valid_e3_q;
// Destination metadata is pipelined with result data so identity remains
// aligned across selectable 2-stage or 3-stage multiplier latency.
reg  [ 5:0]  pr_rd_e2_q;
reg  [ 5:0]  pr_rd_e3_q;
reg  [ 4:0]  rob_tag_e2_q;
reg  [ 4:0]  rob_tag_e3_q;

reg [32:0]   operand_a_e1_q;
reg [32:0]   operand_b_e1_q;
reg          mulhi_sel_e1_q;

//-------------------------------------------------------------
// Multiplier
//-------------------------------------------------------------
wire [64:0]  mult_result_w;
reg  [32:0]  operand_b_r;
reg  [32:0]  operand_a_r;
reg  [31:0]  result_r;

wire mult_inst_w    = ((opcode_opcode_i & `INST_MUL_MASK) == `INST_MUL)        || 
                      ((opcode_opcode_i & `INST_MULH_MASK) == `INST_MULH)      ||
                      ((opcode_opcode_i & `INST_MULHSU_MASK) == `INST_MULHSU)  ||
                      ((opcode_opcode_i & `INST_MULHU_MASK) == `INST_MULHU);


always @ *
begin
    if ((opcode_opcode_i & `INST_MULHSU_MASK) == `INST_MULHSU)
        operand_a_r = {opcode_ra_operand_i[31], opcode_ra_operand_i[31:0]};
    else if ((opcode_opcode_i & `INST_MULH_MASK) == `INST_MULH)
        operand_a_r = {opcode_ra_operand_i[31], opcode_ra_operand_i[31:0]};
    else // MULHU || MUL
        operand_a_r = {1'b0, opcode_ra_operand_i[31:0]};
end

always @ *
begin
    if ((opcode_opcode_i & `INST_MULHSU_MASK) == `INST_MULHSU)
        operand_b_r = {1'b0, opcode_rb_operand_i[31:0]};
    else if ((opcode_opcode_i & `INST_MULH_MASK) == `INST_MULH)
        operand_b_r = {opcode_rb_operand_i[31], opcode_rb_operand_i[31:0]};
    else // MULHU || MUL
        operand_b_r = {1'b0, opcode_rb_operand_i[31:0]};
end


// Pipeline flops for multiplier
always @(posedge clk_i or posedge rst_i)
if (rst_i)
begin
    operand_a_e1_q <= 33'b0;
    operand_b_e1_q <= 33'b0;
    mulhi_sel_e1_q <= 1'b0;
end
else if (hold_i)
    ;
else if (opcode_valid_i && mult_inst_w)
begin
    operand_a_e1_q <= operand_a_r;
    operand_b_e1_q <= operand_b_r;
    mulhi_sel_e1_q <= ~((opcode_opcode_i & `INST_MUL_MASK) == `INST_MUL);
end
else
begin
    operand_a_e1_q <= 33'b0;
    operand_b_e1_q <= 33'b0;
    mulhi_sel_e1_q <= 1'b0;
end

assign mult_result_w = {{ 32 {operand_a_e1_q[32]}}, operand_a_e1_q}*{{ 32 {operand_b_e1_q[32]}}, operand_b_e1_q};

always @ *
begin
    result_r = mulhi_sel_e1_q ? mult_result_w[63:32] : mult_result_w[31:0];
end

always @(posedge clk_i or posedge rst_i)
if (rst_i)
begin
    result_e2_q <= 32'b0;
    valid_e2_q  <= 1'b0;
    pr_rd_e2_q  <= 6'b0;
    rob_tag_e2_q<= 5'b0;
end
else if (~hold_i)
begin
    result_e2_q <= result_r;
    valid_e2_q  <= opcode_valid_i && mult_inst_w && ~opcode_invalid_i;
    // Capture OoO destination identity at execute accept.
    pr_rd_e2_q  <= pr_rd_i;
    rob_tag_e2_q<= rob_tag_i;
end

always @(posedge clk_i or posedge rst_i)
if (rst_i)
begin
    result_e3_q <= 32'b0;
    valid_e3_q  <= 1'b0;
    pr_rd_e3_q  <= 6'b0;
    rob_tag_e3_q<= 5'b0;
end
else if (~hold_i)
begin
    result_e3_q <= result_e2_q;
    valid_e3_q  <= valid_e2_q;
    // Propagate destination identity with data through optional stage 3.
    pr_rd_e3_q  <= pr_rd_e2_q;
    rob_tag_e3_q<= rob_tag_e2_q;
end

assign writeback_value_o  = (MULT_STAGES == 3) ? result_e3_q : result_e2_q;
// CDB connectivity map:
//   writeback_value_o -> cdb_val_o
//   pr_rd_e*_q        -> cdb_pr_rd_o
//   rob_tag_e*_q      -> cdb_rob_tag_o
//   valid_e*_q        -> cdb_valid_o
assign cdb_val_o          = writeback_value_o;
assign cdb_pr_rd_o        = (MULT_STAGES == 3) ? pr_rd_e3_q : pr_rd_e2_q;
assign cdb_rob_tag_o      = (MULT_STAGES == 3) ? rob_tag_e3_q : rob_tag_e2_q;
assign cdb_valid_o        = (MULT_STAGES == 3) ? valid_e3_q : valid_e2_q;


endmodule
