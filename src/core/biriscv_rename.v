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

module biriscv_rename
(
    // Inputs
     input           clk_i
    ,input           rst_i

    // Decoded instructions (2-wide)
    ,input           fetch0_valid_i
    ,input           fetch1_valid_i
    ,input  [ 31:0]  opcode0_i
    ,input  [ 31:0]  opcode1_i
    ,input  [ 31:0]  opcode0_pc_i
    ,input  [ 31:0]  opcode1_pc_i
    ,input  [  4:0]  opcode0_ra_idx_i
    ,input  [  4:0]  opcode0_rb_idx_i
    ,input  [  4:0]  opcode0_rd_idx_i
    ,input  [  4:0]  opcode1_ra_idx_i
    ,input  [  4:0]  opcode1_rb_idx_i
    ,input  [  4:0]  opcode1_rd_idx_i
    ,input           opcode0_rd_valid_i
    ,input           opcode1_rd_valid_i
    ,input           opcode0_exception_i
    ,input           opcode1_exception_i
    ,input           opcode0_branch_mispredict_i
    ,input           opcode1_branch_mispredict_i

    // RAT restore from checkpoint logic (ROB/branch recovery)
    // Connected from branch/ROB recovery path; applied when ROB requests flush.
    // Why: recover exact architectural->physical map after pipeline redirect.
    ,input  [191:0]  restore_rat_state_i

    // CDB completion buses into ROB
    // Connected from global CDB buses.
    // Why: ROB marks entries ready when their destination PR tags complete.
    ,input           cdb_valid0_i
    ,input           cdb_valid1_i
    ,input  [  5:0]  cdb_pr0_i
    ,input  [  5:0]  cdb_pr1_i

    // Outputs
    // rename_stall_o:
    //   Connected to upstream flow control.
    //   Asserts when ROB is full or required physical allocations unavailable.
    ,output          rename_stall_o
    // flush_pipeline_o:
    //   Connected to frontend/pipeline flush control.
    //   Driven by ROB exception/mispredict commit outcome.
    ,output          flush_pipeline_o

    // Renamed instructions to Reservation Station / issue queue
    ,output          rename0_valid_o
    ,output          rename1_valid_o
    ,output [ 31:0]  rename0_opcode_o
    ,output [ 31:0]  rename1_opcode_o
    // rename*_pr_ra/rb/rd_o + rename*_rob_tag_o:
    //   Connected to issue queue dispatch inputs.
    //   Carry fully renamed source/destination identities and ROB ownership.
    ,output [  5:0]  rename0_pr_ra_o
    ,output [  5:0]  rename0_pr_rb_o
    ,output [  5:0]  rename0_pr_rd_o
    ,output [  5:0]  rename1_pr_ra_o
    ,output [  5:0]  rename1_pr_rb_o
    ,output [  5:0]  rename1_pr_rd_o
    ,output [  4:0]  rename0_rob_tag_o
    ,output [  4:0]  rename1_rob_tag_o
);

wire need_prd0_w = fetch0_valid_i && opcode0_rd_valid_i && (opcode0_rd_idx_i != 5'd0);
wire need_prd1_w = fetch1_valid_i && opcode1_rd_valid_i && (opcode1_rd_idx_i != 5'd0);

wire rob_empty_w;
wire rob_full_w;
wire rob_flush_w;
wire rob_commit_valid0_w;
wire rob_commit_valid1_w;
wire [31:0] rob_commit_pc0_w;
wire [31:0] rob_commit_pc1_w;
wire [4:0]  rob_commit_arch_rd0_w;
wire [4:0]  rob_commit_arch_rd1_w;
wire [5:0]  rob_commit_phys_new0_w;
wire [5:0]  rob_commit_phys_new1_w;
wire [5:0] rob_commit_phys_old0_w;
wire [5:0] rob_commit_phys_old1_w;
wire [4:0] rob_dispatch_tag0_w;
wire [4:0] rob_dispatch_tag1_w;
wire       rob_dispatch_tag0_valid_w;
wire       rob_dispatch_tag1_valid_w;

wire [5:0] rat_pr_ra0_w;
wire [5:0] rat_pr_rb0_w;
wire [5:0] rat_pr_ra1_w;
wire [5:0] rat_pr_rb1_w;
wire [5:0] rat_pr_rd0_old_w;
wire [5:0] rat_pr_rd1_old_w;

wire [5:0] fl_pop_idx0_w;
wire [5:0] fl_pop_idx1_w;
wire       fl_pop_valid0_w;
wire       fl_pop_valid1_w;
wire       fl_empty_w;

wire rename_stall_w = rob_full_w || (fl_empty_w && (need_prd0_w || need_prd1_w));

wire rename_fire0_w = fetch0_valid_i && !rename_stall_w;
wire rename_fire1_w = fetch1_valid_i && !rename_stall_w;

wire alloc_prd0_w = rename_fire0_w && need_prd0_w;
wire alloc_prd1_w = rename_fire1_w && need_prd1_w;

wire rat_we0_w = alloc_prd0_w && fl_pop_valid0_w;
wire rat_we1_w = alloc_prd1_w && fl_pop_valid1_w;

wire [5:0] pr_rd0_w = need_prd0_w ? fl_pop_idx0_w : 6'd0;
wire [5:0] pr_rd1_w = need_prd1_w ? fl_pop_idx1_w : 6'd0;

wire rename0_accept_w = rename_fire0_w && (!need_prd0_w || fl_pop_valid0_w);
wire rename1_accept_w = rename_fire1_w && (!need_prd1_w || fl_pop_valid1_w);

assign rename_stall_o    = rename_stall_w;
assign flush_pipeline_o  = rob_flush_w;

assign rename0_valid_o   = rename0_accept_w && rob_dispatch_tag0_valid_w;
assign rename1_valid_o   = rename1_accept_w && rob_dispatch_tag1_valid_w;
assign rename0_opcode_o  = opcode0_i;
assign rename1_opcode_o  = opcode1_i;
assign rename0_pr_ra_o   = rat_pr_ra0_w;
assign rename0_pr_rb_o   = rat_pr_rb0_w;
assign rename0_pr_rd_o   = pr_rd0_w;
assign rename1_pr_ra_o   = rat_pr_ra1_w;
assign rename1_pr_rb_o   = rat_pr_rb1_w;
assign rename1_pr_rd_o   = pr_rd1_w;
assign rename0_rob_tag_o = rob_dispatch_tag0_w;
assign rename1_rob_tag_o = rob_dispatch_tag1_w;

// Connectivity summary:
// - RAT provides source physical tags + old destination mappings.
// - FreeList provides newly allocated destination physical tags.
// - ROB provides dispatch tags and flush decision, and receives CDB completion.
// - Rename outputs package this identity for downstream issue queue.

biriscv_rat
u_rat
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.flush_i(rob_flush_w)
    ,.restore_rat_state_i(restore_rat_state_i)
    ,.ar_ra0_i(opcode0_ra_idx_i)
    ,.ar_rb0_i(opcode0_rb_idx_i)
    ,.ar_ra1_i(opcode1_ra_idx_i)
    ,.ar_rb1_i(opcode1_rb_idx_i)
    ,.ar_rd0_i(opcode0_rd_idx_i)
    ,.ar_rd1_i(opcode1_rd_idx_i)
    ,.pr_rd0_i(pr_rd0_w)
    ,.pr_rd1_i(pr_rd1_w)
    ,.we0_i(rat_we0_w)
    ,.we1_i(rat_we1_w)

    // Outputs
    ,.pr_ra0_o(rat_pr_ra0_w)
    ,.pr_rb0_o(rat_pr_rb0_w)
    ,.pr_ra1_o(rat_pr_ra1_w)
    ,.pr_rb1_o(rat_pr_rb1_w)
    ,.pr_rd0_old_o(rat_pr_rd0_old_w)
    ,.pr_rd1_old_o(rat_pr_rd1_old_w)
);

biriscv_freelist
u_freelist
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.pop_req_0_i(alloc_prd0_w)
    ,.pop_req_1_i(alloc_prd1_w)
    ,.push_req_0_i(rob_commit_valid0_w)
    ,.push_req_1_i(rob_commit_valid1_w)
    ,.push_idx_0_i(rob_commit_phys_old0_w)
    ,.push_idx_1_i(rob_commit_phys_old1_w)

    // Outputs
    ,.pop_idx_0_o(fl_pop_idx0_w)
    ,.pop_idx_1_o(fl_pop_idx1_w)
    ,.pop_valid_0_o(fl_pop_valid0_w)
    ,.pop_valid_1_o(fl_pop_valid1_w)
    ,.empty_o(fl_empty_w)
);

biriscv_rob
u_rob
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)

    // Dispatch (connected from accepted rename slots)
    ,.push0_i(rename0_accept_w)
    ,.push1_i(rename1_accept_w)
    ,.exception0_i(opcode0_exception_i)
    ,.exception1_i(opcode1_exception_i)
    ,.branch_mispredict0_i(opcode0_branch_mispredict_i)
    ,.branch_mispredict1_i(opcode1_branch_mispredict_i)
    ,.pc0_i(opcode0_pc_i)
    ,.pc1_i(opcode1_pc_i)
    ,.arch_rd0_i(opcode0_rd_idx_i)
    ,.arch_rd1_i(opcode1_rd_idx_i)
    ,.phys_rd_new0_i(pr_rd0_w)
    ,.phys_rd_new1_i(pr_rd1_w)
    ,.phys_rd_old0_i(rat_pr_rd0_old_w)
    ,.phys_rd_old1_i(rat_pr_rd1_old_w)

    // Complete (connected from global CDB)
    ,.cdb_valid0_i(cdb_valid0_i)
    ,.cdb_valid1_i(cdb_valid1_i)
    ,.cdb_pr0_i(cdb_pr0_i)
    ,.cdb_pr1_i(cdb_pr1_i)

    // Outputs
    ,.commit_valid0_o(rob_commit_valid0_w)
    ,.commit_valid1_o(rob_commit_valid1_w)
    ,.commit_pc0_o(rob_commit_pc0_w)
    ,.commit_pc1_o(rob_commit_pc1_w)
    ,.commit_arch_rd0_o(rob_commit_arch_rd0_w)
    ,.commit_arch_rd1_o(rob_commit_arch_rd1_w)
    ,.commit_phys_rd_new0_o(rob_commit_phys_new0_w)
    ,.commit_phys_rd_new1_o(rob_commit_phys_new1_w)
    ,.commit_phys_rd_old0_o(rob_commit_phys_old0_w)
    ,.commit_phys_rd_old1_o(rob_commit_phys_old1_w)
    ,.dispatch_tag0_o(rob_dispatch_tag0_w)
    ,.dispatch_tag1_o(rob_dispatch_tag1_w)
    ,.dispatch_tag0_valid_o(rob_dispatch_tag0_valid_w)
    ,.dispatch_tag1_valid_o(rob_dispatch_tag1_valid_w)
    ,.flush_pipeline_o(rob_flush_w)
    ,.empty_o(rob_empty_w)
    ,.full_o(rob_full_w)
);

endmodule
