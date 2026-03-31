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

module riscv_core
//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
     parameter SUPPORT_BRANCH_PREDICTION = 1
    ,parameter SUPPORT_MULDIV   = 1
    ,parameter SUPPORT_SUPER    = 0
    ,parameter SUPPORT_MMU      = 0
    ,parameter SUPPORT_DUAL_ISSUE = 1
    ,parameter SUPPORT_LOAD_BYPASS = 1
    ,parameter SUPPORT_MUL_BYPASS = 1
    ,parameter SUPPORT_REGFILE_XILINX = 0
    ,parameter EXTRA_DECODE_STAGE = 0
    ,parameter MEM_CACHE_ADDR_MIN = 32'h80000000
    ,parameter MEM_CACHE_ADDR_MAX = 32'h8fffffff
    ,parameter NUM_BTB_ENTRIES  = 32
    ,parameter NUM_BTB_ENTRIES_W = 5
    ,parameter NUM_BHT_ENTRIES  = 512
    ,parameter NUM_BHT_ENTRIES_W = 9
    ,parameter RAS_ENABLE       = 1
    ,parameter GSHARE_ENABLE    = 0
    ,parameter BHT_ENABLE       = 1
    ,parameter NUM_RAS_ENTRIES  = 8
    ,parameter NUM_RAS_ENTRIES_W = 3
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // Inputs
     input           clk_i
    ,input           rst_i
    ,input  [ 31:0]  mem_d_data_rd_i
    ,input           mem_d_accept_i
    ,input           mem_d_ack_i
    ,input           mem_d_error_i
    ,input  [ 10:0]  mem_d_resp_tag_i
    ,input           mem_i_accept_i
    ,input           mem_i_valid_i
    ,input           mem_i_error_i
    ,input  [ 63:0]  mem_i_inst_i
    ,input           intr_i
    ,input  [ 31:0]  reset_vector_i
    ,input  [ 31:0]  cpu_id_i

    // Outputs
    ,output [ 31:0]  mem_d_addr_o
    ,output [ 31:0]  mem_d_data_wr_o
    ,output          mem_d_rd_o
    ,output [  3:0]  mem_d_wr_o
    ,output          mem_d_cacheable_o
    ,output [ 10:0]  mem_d_req_tag_o
    ,output          mem_d_invalidate_o
    ,output          mem_d_writeback_o
    ,output          mem_d_flush_o
    ,output          mem_i_rd_o
    ,output          mem_i_flush_o
    ,output          mem_i_invalidate_o
    ,output [ 31:0]  mem_i_pc_o
);

wire           mmu_lsu_writeback_w;
wire  [  4:0]  csr_opcode_rd_idx_w;
wire  [  4:0]  mul_opcode_rd_idx_w;
wire           fetch1_instr_csr_w;
wire           branch_d_exec1_request_w;
wire           mmu_flush_w;
wire  [ 31:0]  lsu_opcode_pc_w;
wire  [ 31:0]  branch_exec0_source_w;
wire  [  1:0]  fetch_in_priv_w;
wire  [ 31:0]  csr_opcode_rb_operand_w;
wire  [ 31:0]  writeback_mem_value_w;
wire  [ 31:0]  writeback_div_value_w;
wire           csr_opcode_valid_w;
wire           branch_csr_request_w;
wire  [ 63:0]  mmu_ifetch_inst_w;
wire           mmu_lsu_error_w;
wire  [ 31:0]  fetch0_pc_w;
wire           branch_exec0_is_call_w;
wire           mul_opcode_valid_w;
wire           branch_exec0_request_w;
wire           mmu_mxr_w;
wire  [ 31:0]  branch_exec0_pc_w;
wire  [ 31:0]  opcode0_pc_w;
wire  [ 31:0]  opcode0_ra_operand_w;
wire           mmu_ifetch_valid_w;
wire           csr_opcode_invalid_w;
wire  [  5:0]  csr_writeback_exception_w;
wire           branch_exec1_is_call_w;
wire           branch_exec1_is_not_taken_w;
wire  [  1:0]  branch_d_exec0_priv_w;
wire           branch_exec1_is_taken_w;
wire  [  4:0]  opcode1_rd_idx_w;
wire  [ 31:0]  opcode0_rb_operand_w;
wire  [ 31:0]  fetch1_instr_w;
wire  [ 31:0]  csr_writeback_exception_addr_w;
wire           fetch1_instr_invalid_w;
wire  [  3:0]  mmu_lsu_wr_w;
wire           fetch_in_fault_w;
wire           fetch0_instr_rd_valid_w;
wire           branch_request_w;
wire  [ 31:0]  csr_opcode_pc_w;
wire           mmu_lsu_ack_w;
wire           writeback_mem_valid_w;
wire  [  5:0]  csr_result_e1_exception_w;
wire           fetch0_instr_div_w;
wire           fetch0_fault_fetch_w;
wire  [ 31:0]  branch_info_pc_w;
wire           fetch1_fault_page_w;
wire  [ 31:0]  mmu_lsu_data_wr_w;
wire  [ 10:0]  mmu_lsu_resp_tag_w;
wire  [ 10:0]  mmu_lsu_req_tag_w;
wire           fetch1_instr_div_w;
wire  [ 31:0]  branch_exec1_source_w;
wire  [ 31:0]  mul_opcode_opcode_w;
wire  [ 31:0]  branch_d_exec0_pc_w;
wire  [ 31:0]  branch_pc_w;
wire  [  4:0]  mul_opcode_ra_idx_w;
wire  [  4:0]  csr_opcode_rb_idx_w;
wire           lsu_stall_w;
wire  [ 31:0]  opcode1_pc_w;
wire           branch_info_is_not_taken_w;
wire  [ 31:0]  branch_csr_pc_w;
wire  [  4:0]  opcode0_ra_idx_w;
wire           branch_info_is_taken_w;
wire  [ 31:0]  mul_opcode_pc_w;
wire  [ 31:0]  mul_opcode_rb_operand_w;
wire           branch_info_is_ret_w;
wire           branch_exec0_is_taken_w;
wire  [ 31:0]  mul_opcode_ra_operand_w;
wire           fetch1_instr_exec_w;
wire           fetch0_instr_exec_w;
wire           exec1_hold_w;
wire           exec0_opcode_valid_w;
wire  [ 31:0]  writeback_exec1_value_w;
wire           branch_info_is_jmp_w;
wire  [ 31:0]  opcode1_rb_operand_w;
wire           fetch1_instr_lsu_w;
wire           branch_exec1_request_w;
wire           lsu_opcode_invalid_w;
wire  [ 31:0]  mmu_lsu_addr_w;
wire           mul_hold_w;
wire           mmu_ifetch_accept_w;
wire           branch_exec1_is_jmp_w;
wire           mmu_ifetch_invalidate_w;
wire  [  1:0]  branch_csr_priv_w;
wire  [ 31:0]  lsu_opcode_ra_operand_w;
wire           mmu_lsu_rd_w;
wire           fetch0_instr_mul_w;
wire           fetch0_accept_w;
wire  [  1:0]  branch_priv_w;
wire           div_opcode_valid_w;
wire           fetch0_instr_lsu_w;
wire           interrupt_inhibit_w;
wire           mmu_ifetch_error_w;
wire  [ 31:0]  branch_exec1_pc_w;
wire           fetch0_instr_csr_w;
wire  [  5:0]  writeback_mem_exception_w;
wire           fetch1_instr_branch_w;
wire           fetch0_valid_w;
wire           csr_result_e1_write_w;
wire  [ 31:0]  csr_opcode_ra_operand_w;
wire  [ 31:0]  opcode0_opcode_w;
wire  [  1:0]  branch_d_exec1_priv_w;
wire           branch_exec0_is_not_taken_w;
wire           branch_exec1_is_ret_w;
wire           writeback_div_valid_w;
wire  [ 31:0]  opcode1_ra_operand_w;
wire  [  4:0]  mul_opcode_rb_idx_w;
wire  [ 31:0]  mmu_ifetch_pc_w;
wire           mmu_ifetch_rd_w;
wire           fetch0_fault_page_w;
wire           mmu_ifetch_flush_w;
wire  [ 31:0]  opcode1_opcode_w;
wire  [  4:0]  lsu_opcode_rd_idx_w;
wire  [ 31:0]  lsu_opcode_opcode_w;
wire           mmu_load_fault_w;
wire  [ 31:0]  mmu_satp_w;
wire  [ 31:0]  csr_result_e1_wdata_w;
wire  [  4:0]  opcode1_ra_idx_w;
wire           mmu_lsu_invalidate_w;
wire  [ 31:0]  writeback_exec0_value_w;
wire  [  4:0]  csr_opcode_ra_idx_w;
wire           ifence_w;
wire           exec1_opcode_valid_w;
wire           branch_exec0_is_jmp_w;
wire  [ 31:0]  fetch1_pc_w;
wire  [ 31:0]  csr_writeback_wdata_w;
wire           fetch1_accept_w;
wire           csr_writeback_write_w;
wire           take_interrupt_w;
wire  [ 31:0]  csr_result_e1_value_w;
wire  [  4:0]  opcode1_rb_idx_w;
wire           fetch0_instr_invalid_w;
wire  [ 11:0]  csr_writeback_waddr_w;
wire           fetch1_fault_fetch_w;
wire           fetch1_valid_w;
wire  [ 31:0]  fetch0_instr_w;
wire           mmu_lsu_cacheable_w;
wire           branch_d_exec0_request_w;
wire           opcode1_invalid_w;
wire           exec0_hold_w;
wire  [  4:0]  opcode0_rb_idx_w;
wire           opcode0_invalid_w;
wire           lsu_opcode_valid_w;
wire           branch_info_request_w;
wire  [  1:0]  mmu_priv_d_w;
wire  [ 31:0]  csr_opcode_opcode_w;
wire           fetch0_instr_branch_w;
wire           mul_opcode_invalid_w;
wire           branch_exec0_is_ret_w;
wire  [ 31:0]  mmu_lsu_data_rd_w;
wire  [ 31:0]  writeback_mul_value_w;
wire           mmu_lsu_flush_w;
wire  [  4:0]  lsu_opcode_rb_idx_w;
wire           mmu_lsu_accept_w;
wire           fetch1_instr_rd_valid_w;
wire  [ 31:0]  lsu_opcode_rb_operand_w;
wire           mmu_sum_w;
wire  [ 31:0]  branch_info_source_w;
wire           branch_info_is_call_w;
wire  [  4:0]  opcode0_rd_idx_w;
wire  [ 31:0]  branch_d_exec1_pc_w;
wire  [  4:0]  lsu_opcode_ra_idx_w;
wire  [ 31:0]  csr_writeback_exception_pc_w;
wire           fetch1_instr_mul_w;
wire           mmu_store_fault_w;

// OoO integration wires
// Group purpose:
// - rename*  : decoded instruction metadata after architectural->physical rename.
// - prf_*    : physical register file read values and commit readbacks.
// - issueq_* : reservation-station / issue-queue dispatch payload.
// - cdb_*    : per-unit completion channels and 2 global arbitrated CDB buses.
// - rat/fl/rob_top_* : top-level visibility/control for RAT, FreeList, and ROB.
wire           ooo_flush_w;
wire           rename_stall_w;
wire           rename0_valid_w;
wire           rename1_valid_w;
wire  [ 31:0]  rename0_opcode_w;
wire  [ 31:0]  rename1_opcode_w;
wire  [  5:0]  rename0_pr_ra_w;
wire  [  5:0]  rename0_pr_rb_w;
wire  [  5:0]  rename0_pr_rd_w;
wire  [  5:0]  rename1_pr_ra_w;
wire  [  5:0]  rename1_pr_rb_w;
wire  [  5:0]  rename1_pr_rd_w;
wire  [  4:0]  rename0_rob_tag_w;
wire  [  4:0]  rename1_rob_tag_w;

wire  [ 31:0]  prf_ra0_value_w;
wire  [ 31:0]  prf_rb0_value_w;
wire  [ 31:0]  prf_ra1_value_w;
wire  [ 31:0]  prf_rb1_value_w;

wire           issueq_full_w;
wire           issueq_accept0_w;
wire           issueq_accept1_w;
wire           issueq_exec_valid_w;
wire  [  3:0]  issueq_exec_op_type_w;
wire  [  5:0]  issueq_exec_pr_rd_w;
wire  [ 31:0]  issueq_exec_ra_val_w;
wire  [ 31:0]  issueq_exec_rb_val_w;
wire  [  4:0]  issueq_exec_rob_tag_w;

wire  [ 31:0]  cdb_exec0_val_w;
wire  [  5:0]  cdb_exec0_pr_w;
wire  [  4:0]  cdb_exec0_rob_w;
wire           cdb_exec0_valid_w;
wire  [ 31:0]  cdb_exec1_val_w;
wire  [  5:0]  cdb_exec1_pr_w;
wire  [  4:0]  cdb_exec1_rob_w;
wire           cdb_exec1_valid_w;
wire  [ 31:0]  cdb_lsu_val_w;
wire  [  5:0]  cdb_lsu_pr_w;
wire  [  4:0]  cdb_lsu_rob_w;
wire           cdb_lsu_valid_w;
wire  [ 31:0]  cdb_mul_val_w;
wire  [  5:0]  cdb_mul_pr_w;
wire  [  4:0]  cdb_mul_rob_w;
wire           cdb_mul_valid_w;
wire  [ 31:0]  cdb_div_val_w;
wire  [  5:0]  cdb_div_pr_w;
wire  [  4:0]  cdb_div_rob_w;
wire           cdb_div_valid_w;

wire  [ 31:0]  cdb0_val_w;
wire  [  5:0]  cdb0_pr_w;
wire  [  4:0]  cdb0_rob_w;
wire           cdb0_valid_w;
wire  [ 31:0]  cdb1_val_w;
wire  [  5:0]  cdb1_pr_w;
wire  [  4:0]  cdb1_rob_w;
wire           cdb1_valid_w;

wire  [  5:0]  rat_top_pr_ra0_w;
wire  [  5:0]  rat_top_pr_rb0_w;
wire  [  5:0]  rat_top_pr_ra1_w;
wire  [  5:0]  rat_top_pr_rb1_w;
wire  [  5:0]  rat_top_pr_rd0_old_w;
wire  [  5:0]  rat_top_pr_rd1_old_w;
wire  [  5:0]  fl_top_pop_idx0_w;
wire  [  5:0]  fl_top_pop_idx1_w;
wire           fl_top_pop_valid0_w;
wire           fl_top_pop_valid1_w;
wire           fl_top_empty_w;

wire           rob_top_commit_valid0_w;
wire           rob_top_commit_valid1_w;
wire  [  5:0]  rob_top_commit_old0_w;
wire  [  5:0]  rob_top_commit_old1_w;
wire  [  4:0]  rob_top_dispatch_tag0_w;
wire  [  4:0]  rob_top_dispatch_tag1_w;
wire           rob_top_dispatch_tag0_valid_w;
wire           rob_top_dispatch_tag1_valid_w;
wire           rob_top_empty_w;
wire           rob_top_full_w;
wire  [ 31:0]  rob_top_commit_pc0_w;
wire  [ 31:0]  rob_top_commit_pc1_w;
wire  [  4:0]  rob_top_commit_arch_rd0_w;
wire  [  4:0]  rob_top_commit_arch_rd1_w;
wire  [  5:0]  rob_top_commit_phys_new0_w;
wire  [  5:0]  rob_top_commit_phys_new1_w;
wire  [ 31:0]  rob_top_commit_rd_val0_w;
wire  [ 31:0]  rob_top_commit_rd_val1_w;

// CDB arbitration (2 global buses)
// Connection intent:
// - Sources: exec0/exec1/lsu/mul/div unit-local completion outputs.
// - Sinks  : PRF write ports, rename/issue wakeup inputs, and ROB completion.
// Why:
// - Provides shared completion fabric while preserving value+pr+rob identity.
assign cdb0_valid_w = cdb_exec0_valid_w | cdb_lsu_valid_w | cdb_mul_valid_w | cdb_div_valid_w | cdb_exec1_valid_w;
assign cdb0_val_w   = cdb_exec0_valid_w ? cdb_exec0_val_w :
                      cdb_lsu_valid_w   ? cdb_lsu_val_w   :
                      cdb_mul_valid_w   ? cdb_mul_val_w   :
                      cdb_div_valid_w   ? cdb_div_val_w   :
                                          cdb_exec1_val_w;
assign cdb0_pr_w    = cdb_exec0_valid_w ? cdb_exec0_pr_w :
                      cdb_lsu_valid_w   ? cdb_lsu_pr_w   :
                      cdb_mul_valid_w   ? cdb_mul_pr_w   :
                      cdb_div_valid_w   ? cdb_div_pr_w   :
                                          cdb_exec1_pr_w;
assign cdb0_rob_w   = cdb_exec0_valid_w ? cdb_exec0_rob_w :
                      cdb_lsu_valid_w   ? cdb_lsu_rob_w   :
                      cdb_mul_valid_w   ? cdb_mul_rob_w   :
                      cdb_div_valid_w   ? cdb_div_rob_w   :
                                          cdb_exec1_rob_w;

assign cdb1_valid_w = cdb_exec1_valid_w | cdb_mul_valid_w | cdb_div_valid_w | cdb_lsu_valid_w | cdb_exec0_valid_w;
assign cdb1_val_w   = cdb_exec1_valid_w ? cdb_exec1_val_w :
                      cdb_mul_valid_w   ? cdb_mul_val_w   :
                      cdb_div_valid_w   ? cdb_div_val_w   :
                      cdb_lsu_valid_w   ? cdb_lsu_val_w   :
                                          cdb_exec0_val_w;
assign cdb1_pr_w    = cdb_exec1_valid_w ? cdb_exec1_pr_w :
                      cdb_mul_valid_w   ? cdb_mul_pr_w   :
                      cdb_div_valid_w   ? cdb_div_pr_w   :
                      cdb_lsu_valid_w   ? cdb_lsu_pr_w   :
                                          cdb_exec0_pr_w;
assign cdb1_rob_w   = cdb_exec1_valid_w ? cdb_exec1_rob_w :
                      cdb_mul_valid_w   ? cdb_mul_rob_w   :
                      cdb_div_valid_w   ? cdb_div_rob_w   :
                      cdb_lsu_valid_w   ? cdb_lsu_rob_w   :
                                          cdb_exec0_rob_w;

// Rename stage between decode/frontend side and OoO issue queue.
// Connectivity:
// - Input side from fetch/decode metadata and fault bits.
// - Output side provides physical source/destination + ROB tags.
// Why:
// - Establishes OoO identity before PRF/issue-queue insertion.
biriscv_rename
u_rename_ooo
(
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.fetch0_valid_i(fetch0_valid_w)
    ,.fetch1_valid_i(fetch1_valid_w)
    ,.opcode0_i(fetch0_instr_w)
    ,.opcode1_i(fetch1_instr_w)
    ,.opcode0_pc_i(fetch0_pc_w)
    ,.opcode1_pc_i(fetch1_pc_w)
    ,.opcode0_ra_idx_i(opcode0_ra_idx_w)
    ,.opcode0_rb_idx_i(opcode0_rb_idx_w)
    ,.opcode0_rd_idx_i(opcode0_rd_idx_w)
    ,.opcode1_ra_idx_i(opcode1_ra_idx_w)
    ,.opcode1_rb_idx_i(opcode1_rb_idx_w)
    ,.opcode1_rd_idx_i(opcode1_rd_idx_w)
    ,.opcode0_rd_valid_i(fetch0_instr_rd_valid_w)
    ,.opcode1_rd_valid_i(fetch1_instr_rd_valid_w)
    ,.opcode0_exception_i(fetch0_fault_fetch_w | fetch0_fault_page_w | fetch0_instr_invalid_w)
    ,.opcode1_exception_i(fetch1_fault_fetch_w | fetch1_fault_page_w | fetch1_instr_invalid_w)
    ,.opcode0_branch_mispredict_i(1'b0)
    ,.opcode1_branch_mispredict_i(1'b0)
    ,.restore_rat_state_i(192'b0)
    ,.cdb_valid0_i(cdb0_valid_w)
    ,.cdb_valid1_i(cdb1_valid_w)
    ,.cdb_pr0_i(cdb0_pr_w)
    ,.cdb_pr1_i(cdb1_pr_w)
    ,.rename_stall_o(rename_stall_w)
    ,.flush_pipeline_o()
    ,.rename0_valid_o(rename0_valid_w)
    ,.rename1_valid_o(rename1_valid_w)
    ,.rename0_opcode_o(rename0_opcode_w)
    ,.rename1_opcode_o(rename1_opcode_w)
    ,.rename0_pr_ra_o(rename0_pr_ra_w)
    ,.rename0_pr_rb_o(rename0_pr_rb_w)
    ,.rename0_pr_rd_o(rename0_pr_rd_w)
    ,.rename1_pr_ra_o(rename1_pr_ra_w)
    ,.rename1_pr_rb_o(rename1_pr_rb_w)
    ,.rename1_pr_rd_o(rename1_pr_rd_w)
    ,.rename0_rob_tag_o(rename0_rob_tag_w)
    ,.rename1_rob_tag_o(rename1_rob_tag_w)
);

biriscv_prf
u_prf_ooo
(
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    // PRF writeback comes from global CDB buses.
    ,.wr_en_0_i(cdb0_valid_w)
    ,.wr_en_1_i(cdb1_valid_w)
    ,.wr_idx_0_i(cdb0_pr_w)
    ,.wr_idx_1_i(cdb1_pr_w)
    ,.wr_data_0_i(cdb0_val_w)
    ,.wr_data_1_i(cdb1_val_w)
    ,.ra0_i(rename0_pr_ra_w)
    ,.rb0_i(rename0_pr_rb_w)
    ,.ra1_i(rename1_pr_ra_w)
    ,.rb1_i(rename1_pr_rb_w)
    // Commit read ports provide architectural-commit values for trace/debug.
    ,.commit_rd0_i(rob_top_commit_phys_new0_w)
    ,.commit_rd1_i(rob_top_commit_phys_new1_w)
    ,.ra0_value_o(prf_ra0_value_w)
    ,.rb0_value_o(prf_rb0_value_w)
    ,.ra1_value_o(prf_ra1_value_w)
    ,.rb1_value_o(prf_rb1_value_w)
    ,.commit_rd0_value_o(rob_top_commit_rd_val0_w)
    ,.commit_rd1_value_o(rob_top_commit_rd_val1_w)
);

biriscv_issue_ooo
u_issue_ooo
(
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.rename0_valid_i(rename0_valid_w)
    ,.rename0_op_type_i(4'b0)
    ,.rename0_pr_rd_i(rename0_pr_rd_w)
    ,.rename0_pr_ra_i(rename0_pr_ra_w)
    ,.rename0_ra_ready_i(1'b1)
    ,.rename0_ra_val_i(prf_ra0_value_w)
    ,.rename0_pr_rb_i(rename0_pr_rb_w)
    ,.rename0_rb_ready_i(1'b1)
    ,.rename0_rb_val_i(prf_rb0_value_w)
    ,.rename0_rob_tag_i(rename0_rob_tag_w)
    ,.rename1_valid_i(rename1_valid_w)
    ,.rename1_op_type_i(4'b0)
    ,.rename1_pr_rd_i(rename1_pr_rd_w)
    ,.rename1_pr_ra_i(rename1_pr_ra_w)
    ,.rename1_ra_ready_i(1'b1)
    ,.rename1_ra_val_i(prf_ra1_value_w)
    ,.rename1_pr_rb_i(rename1_pr_rb_w)
    ,.rename1_rb_ready_i(1'b1)
    ,.rename1_rb_val_i(prf_rb1_value_w)
    ,.rename1_rob_tag_i(rename1_rob_tag_w)
    // CDB snoop for wakeup of not-ready source operands.
    ,.cdb_val0_i(cdb0_val_w)
    ,.cdb_tag0_i(cdb0_pr_w)
    ,.cdb_val1_i(cdb1_val_w)
    ,.cdb_tag1_i(cdb1_pr_w)
    ,.issueq_full_o(issueq_full_w)
    ,.dispatch_accept0_o(issueq_accept0_w)
    ,.dispatch_accept1_o(issueq_accept1_w)
    ,.exec0_opcode_valid_o(issueq_exec_valid_w)
    ,.exec0_op_type_o(issueq_exec_op_type_w)
    ,.exec0_pr_rd_o(issueq_exec_pr_rd_w)
    ,.exec0_ra_val_o(issueq_exec_ra_val_w)
    ,.exec0_rb_val_o(issueq_exec_rb_val_w)
    ,.exec0_rob_tag_o(issueq_exec_rob_tag_w)
);

// Top-level RAT/Freelist/ROB instantiations for OoO subsystem wiring.
// These expose rename/allocation/retire bookkeeping and flush control.
biriscv_rat
u_rat_ooo
(
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.flush_i(ooo_flush_w)
    ,.restore_rat_state_i(192'b0)
    ,.ar_ra0_i(opcode0_ra_idx_w)
    ,.ar_rb0_i(opcode0_rb_idx_w)
    ,.ar_ra1_i(opcode1_ra_idx_w)
    ,.ar_rb1_i(opcode1_rb_idx_w)
    ,.ar_rd0_i(opcode0_rd_idx_w)
    ,.ar_rd1_i(opcode1_rd_idx_w)
    ,.pr_rd0_i(rename0_pr_rd_w)
    ,.pr_rd1_i(rename1_pr_rd_w)
    ,.we0_i(rename0_valid_w && fetch0_instr_rd_valid_w)
    ,.we1_i(rename1_valid_w && fetch1_instr_rd_valid_w)
    ,.pr_ra0_o(rat_top_pr_ra0_w)
    ,.pr_rb0_o(rat_top_pr_rb0_w)
    ,.pr_ra1_o(rat_top_pr_ra1_w)
    ,.pr_rb1_o(rat_top_pr_rb1_w)
    ,.pr_rd0_old_o(rat_top_pr_rd0_old_w)
    ,.pr_rd1_old_o(rat_top_pr_rd1_old_w)
);

biriscv_freelist
u_freelist_ooo
(
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.pop_req_0_i(fetch0_valid_w && fetch0_instr_rd_valid_w)
    ,.pop_req_1_i(fetch1_valid_w && fetch1_instr_rd_valid_w)
    ,.push_req_0_i(rob_top_commit_valid0_w)
    ,.push_req_1_i(rob_top_commit_valid1_w)
    ,.push_idx_0_i(rob_top_commit_old0_w)
    ,.push_idx_1_i(rob_top_commit_old1_w)
    ,.pop_idx_0_o(fl_top_pop_idx0_w)
    ,.pop_idx_1_o(fl_top_pop_idx1_w)
    ,.pop_valid_0_o(fl_top_pop_valid0_w)
    ,.pop_valid_1_o(fl_top_pop_valid1_w)
    ,.empty_o(fl_top_empty_w)
);

biriscv_rob
u_rob_ooo
(
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    // Temporary integration bridge: track instructions from active issue path.
    // Where connected:
    // - push*/pc*/arch_rd* currently come from legacy issue/execute path.
    // - completion comes from global CDB buses (cdb*_valid/pr).
    // Why:
    // - Keeps ROB progressing while full rename->issue_ooo->execute plumbing is
    //   still being unified.
    ,.push0_i(exec0_opcode_valid_w)
    ,.push1_i(exec1_opcode_valid_w)
    ,.exception0_i(opcode0_invalid_w)
    ,.exception1_i(opcode1_invalid_w)
    ,.branch_mispredict0_i(1'b0)
    ,.branch_mispredict1_i(1'b0)
    ,.pc0_i(opcode0_pc_w)
    ,.pc1_i(opcode1_pc_w)
    ,.arch_rd0_i(opcode0_rd_idx_w)
    ,.arch_rd1_i(opcode1_rd_idx_w)
    ,.phys_rd_new0_i({1'b0, opcode0_rd_idx_w})
    ,.phys_rd_new1_i({1'b0, opcode1_rd_idx_w})
    ,.phys_rd_old0_i(rat_top_pr_rd0_old_w)
    ,.phys_rd_old1_i(rat_top_pr_rd1_old_w)
    ,.cdb_valid0_i(cdb0_valid_w)
    ,.cdb_valid1_i(cdb1_valid_w)
    ,.cdb_pr0_i(cdb0_pr_w)
    ,.cdb_pr1_i(cdb1_pr_w)
    ,.commit_valid0_o(rob_top_commit_valid0_w)
    ,.commit_valid1_o(rob_top_commit_valid1_w)
    ,.commit_pc0_o(rob_top_commit_pc0_w)
    ,.commit_pc1_o(rob_top_commit_pc1_w)
    ,.commit_arch_rd0_o(rob_top_commit_arch_rd0_w)
    ,.commit_arch_rd1_o(rob_top_commit_arch_rd1_w)
    ,.commit_phys_rd_new0_o(rob_top_commit_phys_new0_w)
    ,.commit_phys_rd_new1_o(rob_top_commit_phys_new1_w)
    ,.commit_phys_rd_old0_o(rob_top_commit_old0_w)
    ,.commit_phys_rd_old1_o(rob_top_commit_old1_w)
    ,.dispatch_tag0_o(rob_top_dispatch_tag0_w)
    ,.dispatch_tag1_o(rob_top_dispatch_tag1_w)
    ,.dispatch_tag0_valid_o(rob_top_dispatch_tag0_valid_w)
    ,.dispatch_tag1_valid_o(rob_top_dispatch_tag1_valid_w)
    ,.flush_pipeline_o(ooo_flush_w)
    ,.empty_o(rob_top_empty_w)
    ,.full_o(rob_top_full_w)
);

`ifdef verilator
biriscv_trace_sim
u_trace_commit_ooo
(
    .clk_i(clk_i)
    ,.commit_valid0_i(rob_top_commit_valid0_w)
    ,.commit_valid1_i(rob_top_commit_valid1_w)
    ,.commit_pc0_i(rob_top_commit_pc0_w)
    ,.commit_pc1_i(rob_top_commit_pc1_w)
    ,.commit_instr0_i(32'b0)
    ,.commit_instr1_i(32'b0)
    ,.commit_arch_rd0_i(rob_top_commit_arch_rd0_w)
    ,.commit_arch_rd1_i(rob_top_commit_arch_rd1_w)
    ,.commit_rd_val0_i(rob_top_commit_rd_val0_w)
    ,.commit_rd_val1_i(rob_top_commit_rd_val1_w)
);
`endif


biriscv_frontend
#(
     .EXTRA_DECODE_STAGE(EXTRA_DECODE_STAGE)
    ,.NUM_BTB_ENTRIES(NUM_BTB_ENTRIES)
    ,.SUPPORT_BRANCH_PREDICTION(SUPPORT_BRANCH_PREDICTION)
    ,.GSHARE_ENABLE(GSHARE_ENABLE)
    ,.NUM_RAS_ENTRIES_W(NUM_RAS_ENTRIES_W)
    ,.NUM_BHT_ENTRIES_W(NUM_BHT_ENTRIES_W)
    ,.BHT_ENABLE(BHT_ENABLE)
    ,.SUPPORT_MULDIV(SUPPORT_MULDIV)
    ,.NUM_BTB_ENTRIES_W(NUM_BTB_ENTRIES_W)
    ,.SUPPORT_MMU(SUPPORT_MMU)
    ,.NUM_BHT_ENTRIES(NUM_BHT_ENTRIES)
    ,.RAS_ENABLE(RAS_ENABLE)
    ,.NUM_RAS_ENTRIES(NUM_RAS_ENTRIES)
)
u_frontend
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.icache_accept_i(mmu_ifetch_accept_w)
    ,.icache_valid_i(mmu_ifetch_valid_w)
    ,.icache_error_i(mmu_ifetch_error_w)
    ,.icache_inst_i(mmu_ifetch_inst_w)
    ,.icache_page_fault_i(fetch_in_fault_w)
    ,.fetch0_accept_i(fetch0_accept_w)
    ,.fetch1_accept_i(fetch1_accept_w)
    ,.fetch_invalidate_i(ifence_w)
    ,.branch_request_i(branch_request_w | ooo_flush_w)
    ,.branch_pc_i(branch_pc_w)
    ,.branch_priv_i(branch_priv_w)
    ,.branch_info_request_i(branch_info_request_w)
    ,.branch_info_is_taken_i(branch_info_is_taken_w)
    ,.branch_info_is_not_taken_i(branch_info_is_not_taken_w)
    ,.branch_info_source_i(branch_info_source_w)
    ,.branch_info_is_call_i(branch_info_is_call_w)
    ,.branch_info_is_ret_i(branch_info_is_ret_w)
    ,.branch_info_is_jmp_i(branch_info_is_jmp_w)
    ,.branch_info_pc_i(branch_info_pc_w)

    // Outputs
    ,.icache_rd_o(mmu_ifetch_rd_w)
    ,.icache_flush_o(mmu_ifetch_flush_w)
    ,.icache_invalidate_o(mmu_ifetch_invalidate_w)
    ,.icache_pc_o(mmu_ifetch_pc_w)
    ,.icache_priv_o(fetch_in_priv_w)
    ,.fetch0_valid_o(fetch0_valid_w)
    ,.fetch0_instr_o(fetch0_instr_w)
    ,.fetch0_pc_o(fetch0_pc_w)
    ,.fetch0_fault_fetch_o(fetch0_fault_fetch_w)
    ,.fetch0_fault_page_o(fetch0_fault_page_w)
    ,.fetch0_instr_exec_o(fetch0_instr_exec_w)
    ,.fetch0_instr_lsu_o(fetch0_instr_lsu_w)
    ,.fetch0_instr_branch_o(fetch0_instr_branch_w)
    ,.fetch0_instr_mul_o(fetch0_instr_mul_w)
    ,.fetch0_instr_div_o(fetch0_instr_div_w)
    ,.fetch0_instr_csr_o(fetch0_instr_csr_w)
    ,.fetch0_instr_rd_valid_o(fetch0_instr_rd_valid_w)
    ,.fetch0_instr_invalid_o(fetch0_instr_invalid_w)
    ,.fetch1_valid_o(fetch1_valid_w)
    ,.fetch1_instr_o(fetch1_instr_w)
    ,.fetch1_pc_o(fetch1_pc_w)
    ,.fetch1_fault_fetch_o(fetch1_fault_fetch_w)
    ,.fetch1_fault_page_o(fetch1_fault_page_w)
    ,.fetch1_instr_exec_o(fetch1_instr_exec_w)
    ,.fetch1_instr_lsu_o(fetch1_instr_lsu_w)
    ,.fetch1_instr_branch_o(fetch1_instr_branch_w)
    ,.fetch1_instr_mul_o(fetch1_instr_mul_w)
    ,.fetch1_instr_div_o(fetch1_instr_div_w)
    ,.fetch1_instr_csr_o(fetch1_instr_csr_w)
    ,.fetch1_instr_rd_valid_o(fetch1_instr_rd_valid_w)
    ,.fetch1_instr_invalid_o(fetch1_instr_invalid_w)
);


biriscv_mmu
#(
     .MEM_CACHE_ADDR_MAX(MEM_CACHE_ADDR_MAX)
    ,.SUPPORT_MMU(SUPPORT_MMU)
    ,.MEM_CACHE_ADDR_MIN(MEM_CACHE_ADDR_MIN)
)
u_mmu
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.priv_d_i(mmu_priv_d_w)
    ,.sum_i(mmu_sum_w)
    ,.mxr_i(mmu_mxr_w)
    ,.flush_i(mmu_flush_w | ooo_flush_w)
    ,.satp_i(mmu_satp_w)
    ,.fetch_in_rd_i(mmu_ifetch_rd_w)
    ,.fetch_in_flush_i(mmu_ifetch_flush_w)
    ,.fetch_in_invalidate_i(mmu_ifetch_invalidate_w)
    ,.fetch_in_pc_i(mmu_ifetch_pc_w)
    ,.fetch_in_priv_i(fetch_in_priv_w)
    ,.fetch_out_accept_i(mem_i_accept_i)
    ,.fetch_out_valid_i(mem_i_valid_i)
    ,.fetch_out_error_i(mem_i_error_i)
    ,.fetch_out_inst_i(mem_i_inst_i)
    ,.lsu_in_addr_i(mmu_lsu_addr_w)
    ,.lsu_in_data_wr_i(mmu_lsu_data_wr_w)
    ,.lsu_in_rd_i(mmu_lsu_rd_w)
    ,.lsu_in_wr_i(mmu_lsu_wr_w)
    ,.lsu_in_cacheable_i(mmu_lsu_cacheable_w)
    ,.lsu_in_req_tag_i(mmu_lsu_req_tag_w)
    ,.lsu_in_invalidate_i(mmu_lsu_invalidate_w)
    ,.lsu_in_writeback_i(mmu_lsu_writeback_w)
    ,.lsu_in_flush_i(mmu_lsu_flush_w)
    ,.lsu_out_data_rd_i(mem_d_data_rd_i)
    ,.lsu_out_accept_i(mem_d_accept_i)
    ,.lsu_out_ack_i(mem_d_ack_i)
    ,.lsu_out_error_i(mem_d_error_i)
    ,.lsu_out_resp_tag_i(mem_d_resp_tag_i)

    // Outputs
    ,.fetch_in_accept_o(mmu_ifetch_accept_w)
    ,.fetch_in_valid_o(mmu_ifetch_valid_w)
    ,.fetch_in_error_o(mmu_ifetch_error_w)
    ,.fetch_in_inst_o(mmu_ifetch_inst_w)
    ,.fetch_out_rd_o(mem_i_rd_o)
    ,.fetch_out_flush_o(mem_i_flush_o)
    ,.fetch_out_invalidate_o(mem_i_invalidate_o)
    ,.fetch_out_pc_o(mem_i_pc_o)
    ,.fetch_in_fault_o(fetch_in_fault_w)
    ,.lsu_in_data_rd_o(mmu_lsu_data_rd_w)
    ,.lsu_in_accept_o(mmu_lsu_accept_w)
    ,.lsu_in_ack_o(mmu_lsu_ack_w)
    ,.lsu_in_error_o(mmu_lsu_error_w)
    ,.lsu_in_resp_tag_o(mmu_lsu_resp_tag_w)
    ,.lsu_out_addr_o(mem_d_addr_o)
    ,.lsu_out_data_wr_o(mem_d_data_wr_o)
    ,.lsu_out_rd_o(mem_d_rd_o)
    ,.lsu_out_wr_o(mem_d_wr_o)
    ,.lsu_out_cacheable_o(mem_d_cacheable_o)
    ,.lsu_out_req_tag_o(mem_d_req_tag_o)
    ,.lsu_out_invalidate_o(mem_d_invalidate_o)
    ,.lsu_out_writeback_o(mem_d_writeback_o)
    ,.lsu_out_flush_o(mem_d_flush_o)
    ,.lsu_in_load_fault_o(mmu_load_fault_w)
    ,.lsu_in_store_fault_o(mmu_store_fault_w)
);


biriscv_lsu
#(
     .MEM_CACHE_ADDR_MAX(MEM_CACHE_ADDR_MAX)
    ,.MEM_CACHE_ADDR_MIN(MEM_CACHE_ADDR_MIN)
)
u_lsu
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.opcode_valid_i(lsu_opcode_valid_w)
    ,.opcode_opcode_i(lsu_opcode_opcode_w)
    ,.opcode_pc_i(lsu_opcode_pc_w)
    ,.opcode_invalid_i(lsu_opcode_invalid_w)
    ,.opcode_rd_idx_i(lsu_opcode_rd_idx_w)
    ,.opcode_ra_idx_i(lsu_opcode_ra_idx_w)
    ,.opcode_rb_idx_i(lsu_opcode_rb_idx_w)
    ,.opcode_ra_operand_i(lsu_opcode_ra_operand_w)
    ,.opcode_rb_operand_i(lsu_opcode_rb_operand_w)
    // Current bridge wiring:
    // - pr_rd uses zero-extended architectural rd index.
    // - rob_tag is temporarily hardwired while full ROB-tag plumbing is pending.
    ,.pr_rd_i({1'b0, lsu_opcode_rd_idx_w})
    ,.rob_tag_i(5'b0)
    ,.mem_data_rd_i(mmu_lsu_data_rd_w)
    ,.mem_accept_i(mmu_lsu_accept_w)
    ,.mem_ack_i(mmu_lsu_ack_w)
    ,.mem_error_i(mmu_lsu_error_w)
    ,.mem_resp_tag_i(mmu_lsu_resp_tag_w)
    ,.mem_load_fault_i(mmu_load_fault_w)
    ,.mem_store_fault_i(mmu_store_fault_w)

    // Outputs
    ,.mem_addr_o(mmu_lsu_addr_w)
    ,.mem_data_wr_o(mmu_lsu_data_wr_w)
    ,.mem_rd_o(mmu_lsu_rd_w)
    ,.mem_wr_o(mmu_lsu_wr_w)
    ,.mem_cacheable_o(mmu_lsu_cacheable_w)
    ,.mem_req_tag_o(mmu_lsu_req_tag_w)
    ,.mem_invalidate_o(mmu_lsu_invalidate_w)
    ,.mem_writeback_o(mmu_lsu_writeback_w)
    ,.mem_flush_o(mmu_lsu_flush_w)
    ,.writeback_valid_o(writeback_mem_valid_w)
    ,.writeback_value_o(writeback_mem_value_w)
    ,.writeback_exception_o(writeback_mem_exception_w)
    ,.cdb_val_o(cdb_lsu_val_w)
    ,.cdb_pr_rd_o(cdb_lsu_pr_w)
    ,.cdb_rob_tag_o(cdb_lsu_rob_w)
    ,.cdb_valid_o(cdb_lsu_valid_w)
    ,.stall_o(lsu_stall_w)
);


biriscv_csr
#(
     .SUPPORT_SUPER(SUPPORT_SUPER)
    ,.SUPPORT_MULDIV(SUPPORT_MULDIV)
)
u_csr
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.intr_i(intr_i)
    ,.opcode_valid_i(csr_opcode_valid_w)
    ,.opcode_opcode_i(csr_opcode_opcode_w)
    ,.opcode_pc_i(csr_opcode_pc_w)
    ,.opcode_invalid_i(csr_opcode_invalid_w)
    ,.opcode_rd_idx_i(csr_opcode_rd_idx_w)
    ,.opcode_ra_idx_i(csr_opcode_ra_idx_w)
    ,.opcode_rb_idx_i(csr_opcode_rb_idx_w)
    ,.opcode_ra_operand_i(csr_opcode_ra_operand_w)
    ,.opcode_rb_operand_i(csr_opcode_rb_operand_w)
    ,.csr_writeback_write_i(csr_writeback_write_w)
    ,.csr_writeback_waddr_i(csr_writeback_waddr_w)
    ,.csr_writeback_wdata_i(csr_writeback_wdata_w)
    ,.csr_writeback_exception_i(csr_writeback_exception_w)
    ,.csr_writeback_exception_pc_i(csr_writeback_exception_pc_w)
    ,.csr_writeback_exception_addr_i(csr_writeback_exception_addr_w)
    ,.cpu_id_i(cpu_id_i)
    ,.reset_vector_i(reset_vector_i)
    ,.interrupt_inhibit_i(interrupt_inhibit_w)

    // Outputs
    ,.csr_result_e1_value_o(csr_result_e1_value_w)
    ,.csr_result_e1_write_o(csr_result_e1_write_w)
    ,.csr_result_e1_wdata_o(csr_result_e1_wdata_w)
    ,.csr_result_e1_exception_o(csr_result_e1_exception_w)
    ,.branch_csr_request_o(branch_csr_request_w)
    ,.branch_csr_pc_o(branch_csr_pc_w)
    ,.branch_csr_priv_o(branch_csr_priv_w)
    ,.take_interrupt_o(take_interrupt_w)
    ,.ifence_o(ifence_w)
    ,.mmu_priv_d_o(mmu_priv_d_w)
    ,.mmu_sum_o(mmu_sum_w)
    ,.mmu_mxr_o(mmu_mxr_w)
    ,.mmu_flush_o(mmu_flush_w)
    ,.mmu_satp_o(mmu_satp_w)
);


biriscv_multiplier
u_mul
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.opcode_valid_i(mul_opcode_valid_w)
    ,.opcode_opcode_i(mul_opcode_opcode_w)
    ,.opcode_pc_i(mul_opcode_pc_w)
    ,.opcode_invalid_i(mul_opcode_invalid_w)
    ,.opcode_rd_idx_i(mul_opcode_rd_idx_w)
    ,.opcode_ra_idx_i(mul_opcode_ra_idx_w)
    ,.opcode_rb_idx_i(mul_opcode_rb_idx_w)
    ,.opcode_ra_operand_i(mul_opcode_ra_operand_w)
    ,.opcode_rb_operand_i(mul_opcode_rb_operand_w)
    // Current bridge wiring:
    // - pr_rd uses zero-extended architectural rd index.
    // - rob_tag is temporarily hardwired while full ROB-tag plumbing is pending.
    ,.pr_rd_i({1'b0, mul_opcode_rd_idx_w})
    ,.rob_tag_i(5'b0)
    ,.hold_i(mul_hold_w)

    // Outputs
    ,.writeback_value_o(writeback_mul_value_w)
    ,.cdb_val_o(cdb_mul_val_w)
    ,.cdb_pr_rd_o(cdb_mul_pr_w)
    ,.cdb_rob_tag_o(cdb_mul_rob_w)
    ,.cdb_valid_o(cdb_mul_valid_w)
);


biriscv_divider
u_div
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.opcode_valid_i(div_opcode_valid_w)
    ,.opcode_opcode_i(opcode0_opcode_w)
    ,.opcode_pc_i(opcode0_pc_w)
    ,.opcode_invalid_i(opcode0_invalid_w)
    ,.opcode_rd_idx_i(opcode0_rd_idx_w)
    ,.opcode_ra_idx_i(opcode0_ra_idx_w)
    ,.opcode_rb_idx_i(opcode0_rb_idx_w)
    ,.opcode_ra_operand_i(opcode0_ra_operand_w)
    ,.opcode_rb_operand_i(opcode0_rb_operand_w)
    // Current bridge wiring:
    // - pr_rd uses zero-extended architectural rd index.
    // - rob_tag is temporarily hardwired while full ROB-tag plumbing is pending.
    ,.pr_rd_i({1'b0, opcode0_rd_idx_w})
    ,.rob_tag_i(5'b0)

    // Outputs
    ,.writeback_valid_o(writeback_div_valid_w)
    ,.writeback_value_o(writeback_div_value_w)
    ,.cdb_val_o(cdb_div_val_w)
    ,.cdb_pr_rd_o(cdb_div_pr_w)
    ,.cdb_rob_tag_o(cdb_div_rob_w)
    ,.cdb_valid_o(cdb_div_valid_w)
);


biriscv_issue
#(
     .SUPPORT_REGFILE_XILINX(SUPPORT_REGFILE_XILINX)
    ,.SUPPORT_LOAD_BYPASS(SUPPORT_LOAD_BYPASS)
    ,.SUPPORT_MULDIV(SUPPORT_MULDIV)
    ,.SUPPORT_MUL_BYPASS(SUPPORT_MUL_BYPASS)
    ,.SUPPORT_DUAL_ISSUE(SUPPORT_DUAL_ISSUE)
)
u_issue
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.fetch0_valid_i(fetch0_valid_w)
    ,.fetch0_instr_i(fetch0_instr_w)
    ,.fetch0_pc_i(fetch0_pc_w)
    ,.fetch0_fault_fetch_i(fetch0_fault_fetch_w)
    ,.fetch0_fault_page_i(fetch0_fault_page_w)
    ,.fetch0_instr_exec_i(fetch0_instr_exec_w)
    ,.fetch0_instr_lsu_i(fetch0_instr_lsu_w)
    ,.fetch0_instr_branch_i(fetch0_instr_branch_w)
    ,.fetch0_instr_mul_i(fetch0_instr_mul_w)
    ,.fetch0_instr_div_i(fetch0_instr_div_w)
    ,.fetch0_instr_csr_i(fetch0_instr_csr_w)
    ,.fetch0_instr_rd_valid_i(fetch0_instr_rd_valid_w)
    ,.fetch0_instr_invalid_i(fetch0_instr_invalid_w)
    ,.fetch1_valid_i(fetch1_valid_w)
    ,.fetch1_instr_i(fetch1_instr_w)
    ,.fetch1_pc_i(fetch1_pc_w)
    ,.fetch1_fault_fetch_i(fetch1_fault_fetch_w)
    ,.fetch1_fault_page_i(fetch1_fault_page_w)
    ,.fetch1_instr_exec_i(fetch1_instr_exec_w)
    ,.fetch1_instr_lsu_i(fetch1_instr_lsu_w)
    ,.fetch1_instr_branch_i(fetch1_instr_branch_w)
    ,.fetch1_instr_mul_i(fetch1_instr_mul_w)
    ,.fetch1_instr_div_i(fetch1_instr_div_w)
    ,.fetch1_instr_csr_i(fetch1_instr_csr_w)
    ,.fetch1_instr_rd_valid_i(fetch1_instr_rd_valid_w)
    ,.fetch1_instr_invalid_i(fetch1_instr_invalid_w)
    ,.branch_exec0_request_i(branch_exec0_request_w)
    ,.branch_exec0_is_taken_i(branch_exec0_is_taken_w)
    ,.branch_exec0_is_not_taken_i(branch_exec0_is_not_taken_w)
    ,.branch_exec0_source_i(branch_exec0_source_w)
    ,.branch_exec0_is_call_i(branch_exec0_is_call_w)
    ,.branch_exec0_is_ret_i(branch_exec0_is_ret_w)
    ,.branch_exec0_is_jmp_i(branch_exec0_is_jmp_w)
    ,.branch_exec0_pc_i(branch_exec0_pc_w)
    ,.branch_d_exec0_request_i(branch_d_exec0_request_w)
    ,.branch_d_exec0_pc_i(branch_d_exec0_pc_w)
    ,.branch_d_exec0_priv_i(branch_d_exec0_priv_w)
    ,.branch_exec1_request_i(branch_exec1_request_w)
    ,.branch_exec1_is_taken_i(branch_exec1_is_taken_w)
    ,.branch_exec1_is_not_taken_i(branch_exec1_is_not_taken_w)
    ,.branch_exec1_source_i(branch_exec1_source_w)
    ,.branch_exec1_is_call_i(branch_exec1_is_call_w)
    ,.branch_exec1_is_ret_i(branch_exec1_is_ret_w)
    ,.branch_exec1_is_jmp_i(branch_exec1_is_jmp_w)
    ,.branch_exec1_pc_i(branch_exec1_pc_w)
    ,.branch_d_exec1_request_i(branch_d_exec1_request_w)
    ,.branch_d_exec1_pc_i(branch_d_exec1_pc_w)
    ,.branch_d_exec1_priv_i(branch_d_exec1_priv_w)
    ,.branch_csr_request_i(branch_csr_request_w)
    ,.branch_csr_pc_i(branch_csr_pc_w)
    ,.branch_csr_priv_i(branch_csr_priv_w)
    ,.writeback_exec0_value_i(writeback_exec0_value_w)
    ,.writeback_exec1_value_i(writeback_exec1_value_w)
    ,.writeback_mem_valid_i(writeback_mem_valid_w)
    ,.writeback_mem_value_i(writeback_mem_value_w)
    ,.writeback_mem_exception_i(writeback_mem_exception_w)
    ,.writeback_mul_value_i(writeback_mul_value_w)
    ,.writeback_div_valid_i(writeback_div_valid_w)
    ,.writeback_div_value_i(writeback_div_value_w)
    ,.csr_result_e1_value_i(csr_result_e1_value_w)
    ,.csr_result_e1_write_i(csr_result_e1_write_w)
    ,.csr_result_e1_wdata_i(csr_result_e1_wdata_w)
    ,.csr_result_e1_exception_i(csr_result_e1_exception_w)
    ,.lsu_stall_i(lsu_stall_w)
    ,.take_interrupt_i(take_interrupt_w)

    // Outputs
    ,.fetch0_accept_o(fetch0_accept_w)
    ,.fetch1_accept_o(fetch1_accept_w)
    ,.branch_request_o(branch_request_w)
    ,.branch_pc_o(branch_pc_w)
    ,.branch_priv_o(branch_priv_w)
    ,.branch_info_request_o(branch_info_request_w)
    ,.branch_info_is_taken_o(branch_info_is_taken_w)
    ,.branch_info_is_not_taken_o(branch_info_is_not_taken_w)
    ,.branch_info_source_o(branch_info_source_w)
    ,.branch_info_is_call_o(branch_info_is_call_w)
    ,.branch_info_is_ret_o(branch_info_is_ret_w)
    ,.branch_info_is_jmp_o(branch_info_is_jmp_w)
    ,.branch_info_pc_o(branch_info_pc_w)
    ,.exec0_opcode_valid_o(exec0_opcode_valid_w)
    ,.exec1_opcode_valid_o(exec1_opcode_valid_w)
    ,.lsu_opcode_valid_o(lsu_opcode_valid_w)
    ,.csr_opcode_valid_o(csr_opcode_valid_w)
    ,.mul_opcode_valid_o(mul_opcode_valid_w)
    ,.div_opcode_valid_o(div_opcode_valid_w)
    ,.opcode0_opcode_o(opcode0_opcode_w)
    ,.opcode0_pc_o(opcode0_pc_w)
    ,.opcode0_invalid_o(opcode0_invalid_w)
    ,.opcode0_rd_idx_o(opcode0_rd_idx_w)
    ,.opcode0_ra_idx_o(opcode0_ra_idx_w)
    ,.opcode0_rb_idx_o(opcode0_rb_idx_w)
    ,.opcode0_ra_operand_o(opcode0_ra_operand_w)
    ,.opcode0_rb_operand_o(opcode0_rb_operand_w)
    ,.opcode1_opcode_o(opcode1_opcode_w)
    ,.opcode1_pc_o(opcode1_pc_w)
    ,.opcode1_invalid_o(opcode1_invalid_w)
    ,.opcode1_rd_idx_o(opcode1_rd_idx_w)
    ,.opcode1_ra_idx_o(opcode1_ra_idx_w)
    ,.opcode1_rb_idx_o(opcode1_rb_idx_w)
    ,.opcode1_ra_operand_o(opcode1_ra_operand_w)
    ,.opcode1_rb_operand_o(opcode1_rb_operand_w)
    ,.lsu_opcode_opcode_o(lsu_opcode_opcode_w)
    ,.lsu_opcode_pc_o(lsu_opcode_pc_w)
    ,.lsu_opcode_invalid_o(lsu_opcode_invalid_w)
    ,.lsu_opcode_rd_idx_o(lsu_opcode_rd_idx_w)
    ,.lsu_opcode_ra_idx_o(lsu_opcode_ra_idx_w)
    ,.lsu_opcode_rb_idx_o(lsu_opcode_rb_idx_w)
    ,.lsu_opcode_ra_operand_o(lsu_opcode_ra_operand_w)
    ,.lsu_opcode_rb_operand_o(lsu_opcode_rb_operand_w)
    ,.mul_opcode_opcode_o(mul_opcode_opcode_w)
    ,.mul_opcode_pc_o(mul_opcode_pc_w)
    ,.mul_opcode_invalid_o(mul_opcode_invalid_w)
    ,.mul_opcode_rd_idx_o(mul_opcode_rd_idx_w)
    ,.mul_opcode_ra_idx_o(mul_opcode_ra_idx_w)
    ,.mul_opcode_rb_idx_o(mul_opcode_rb_idx_w)
    ,.mul_opcode_ra_operand_o(mul_opcode_ra_operand_w)
    ,.mul_opcode_rb_operand_o(mul_opcode_rb_operand_w)
    ,.csr_opcode_opcode_o(csr_opcode_opcode_w)
    ,.csr_opcode_pc_o(csr_opcode_pc_w)
    ,.csr_opcode_invalid_o(csr_opcode_invalid_w)
    ,.csr_opcode_rd_idx_o(csr_opcode_rd_idx_w)
    ,.csr_opcode_ra_idx_o(csr_opcode_ra_idx_w)
    ,.csr_opcode_rb_idx_o(csr_opcode_rb_idx_w)
    ,.csr_opcode_ra_operand_o(csr_opcode_ra_operand_w)
    ,.csr_opcode_rb_operand_o(csr_opcode_rb_operand_w)
    ,.csr_writeback_write_o(csr_writeback_write_w)
    ,.csr_writeback_waddr_o(csr_writeback_waddr_w)
    ,.csr_writeback_wdata_o(csr_writeback_wdata_w)
    ,.csr_writeback_exception_o(csr_writeback_exception_w)
    ,.csr_writeback_exception_pc_o(csr_writeback_exception_pc_w)
    ,.csr_writeback_exception_addr_o(csr_writeback_exception_addr_w)
    ,.exec0_hold_o(exec0_hold_w)
    ,.exec1_hold_o(exec1_hold_w)
    ,.mul_hold_o(mul_hold_w)
    ,.interrupt_inhibit_o(interrupt_inhibit_w)
);


biriscv_exec
u_exec0
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.opcode_valid_i(exec0_opcode_valid_w)
    ,.opcode_opcode_i(opcode0_opcode_w)
    ,.opcode_pc_i(opcode0_pc_w)
    ,.opcode_invalid_i(opcode0_invalid_w)
    ,.opcode_rd_idx_i(opcode0_rd_idx_w)
    ,.opcode_ra_idx_i(opcode0_ra_idx_w)
    ,.opcode_rb_idx_i(opcode0_rb_idx_w)
    ,.opcode_ra_operand_i(opcode0_ra_operand_w)
    ,.opcode_rb_operand_i(opcode0_rb_operand_w)
    // Current bridge wiring:
    // - pr_rd uses zero-extended architectural rd index.
    // - rob_tag is temporarily hardwired while full ROB-tag plumbing is pending.
    ,.pr_rd_i({1'b0, opcode0_rd_idx_w})
    ,.rob_tag_i(5'b0)
    ,.hold_i(exec0_hold_w)

    // Outputs
    ,.branch_request_o(branch_exec0_request_w)
    ,.branch_is_taken_o(branch_exec0_is_taken_w)
    ,.branch_is_not_taken_o(branch_exec0_is_not_taken_w)
    ,.branch_source_o(branch_exec0_source_w)
    ,.branch_is_call_o(branch_exec0_is_call_w)
    ,.branch_is_ret_o(branch_exec0_is_ret_w)
    ,.branch_is_jmp_o(branch_exec0_is_jmp_w)
    ,.branch_pc_o(branch_exec0_pc_w)
    ,.branch_d_request_o(branch_d_exec0_request_w)
    ,.branch_d_pc_o(branch_d_exec0_pc_w)
    ,.branch_d_priv_o(branch_d_exec0_priv_w)
    ,.writeback_value_o(writeback_exec0_value_w)
    ,.cdb_val_o(cdb_exec0_val_w)
    ,.cdb_pr_rd_o(cdb_exec0_pr_w)
    ,.cdb_rob_tag_o(cdb_exec0_rob_w)
    ,.cdb_valid_o(cdb_exec0_valid_w)
);


biriscv_exec
u_exec1
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.opcode_valid_i(exec1_opcode_valid_w)
    ,.opcode_opcode_i(opcode1_opcode_w)
    ,.opcode_pc_i(opcode1_pc_w)
    ,.opcode_invalid_i(opcode1_invalid_w)
    ,.opcode_rd_idx_i(opcode1_rd_idx_w)
    ,.opcode_ra_idx_i(opcode1_ra_idx_w)
    ,.opcode_rb_idx_i(opcode1_rb_idx_w)
    ,.opcode_ra_operand_i(opcode1_ra_operand_w)
    ,.opcode_rb_operand_i(opcode1_rb_operand_w)
    // Current bridge wiring:
    // - pr_rd uses zero-extended architectural rd index.
    // - rob_tag is temporarily hardwired while full ROB-tag plumbing is pending.
    ,.pr_rd_i({1'b0, opcode1_rd_idx_w})
    ,.rob_tag_i(5'b0)
    ,.hold_i(exec1_hold_w)

    // Outputs
    ,.branch_request_o(branch_exec1_request_w)
    ,.branch_is_taken_o(branch_exec1_is_taken_w)
    ,.branch_is_not_taken_o(branch_exec1_is_not_taken_w)
    ,.branch_source_o(branch_exec1_source_w)
    ,.branch_is_call_o(branch_exec1_is_call_w)
    ,.branch_is_ret_o(branch_exec1_is_ret_w)
    ,.branch_is_jmp_o(branch_exec1_is_jmp_w)
    ,.branch_pc_o(branch_exec1_pc_w)
    ,.branch_d_request_o(branch_d_exec1_request_w)
    ,.branch_d_pc_o(branch_d_exec1_pc_w)
    ,.branch_d_priv_o(branch_d_exec1_priv_w)
    ,.writeback_value_o(writeback_exec1_value_w)
    ,.cdb_val_o(cdb_exec1_val_w)
    ,.cdb_pr_rd_o(cdb_exec1_pr_w)
    ,.cdb_rob_tag_o(cdb_exec1_rob_w)
    ,.cdb_valid_o(cdb_exec1_valid_w)
);



endmodule
