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

module biriscv_rob
#(
    parameter XILINX_RAM_STYLE = "distributed"
)
(
    // Inputs
     input           clk_i
    ,input           rst_i

    // Dispatch (up to 2 entries per cycle)
    // push* + exception* + branch_mispredict* + pc* + arch_rd* + phys_rd_*:
    //   Connected from rename/issue integration path.
    //   Insert in-flight instructions and ownership metadata into ROB.
    //   Why: preserve in-order retirement state and physical-register lifecycle.
    ,input           push0_i
    ,input           push1_i
    ,input           exception0_i
    ,input           exception1_i
    ,input           branch_mispredict0_i
    ,input           branch_mispredict1_i
    ,input  [ 31:0]  pc0_i
    ,input  [ 31:0]  pc1_i
    ,input  [  4:0]  arch_rd0_i
    ,input  [  4:0]  arch_rd1_i
    ,input  [  5:0]  phys_rd_new0_i
    ,input  [  5:0]  phys_rd_new1_i
    ,input  [  5:0]  phys_rd_old0_i
    ,input  [  5:0]  phys_rd_old1_i

    // Complete (2x CDB)
    // cdb_valid* + cdb_pr*:
    //   Connected from global CDB completion buses.
    //   Why: mark ROB entries ready when destination physical register completes.
    ,input           cdb_valid0_i
    ,input           cdb_valid1_i
    ,input  [  5:0]  cdb_pr0_i
    ,input  [  5:0]  cdb_pr1_i

    // Outputs
    // commit_* outputs:
    //   Connected to architectural commit, free-list recycle, and trace paths.
    //   Export retiring instruction metadata in program order.
    ,output          commit_valid0_o
    ,output          commit_valid1_o
    ,output [ 31:0]  commit_pc0_o
    ,output [ 31:0]  commit_pc1_o
    ,output [  4:0]  commit_arch_rd0_o
    ,output [  4:0]  commit_arch_rd1_o
    ,output [  5:0]  commit_phys_rd_new0_o
    ,output [  5:0]  commit_phys_rd_new1_o
    ,output [  5:0]  commit_phys_rd_old0_o
    ,output [  5:0]  commit_phys_rd_old1_o
    // dispatch_tag*_o:
    //   Connected back to rename/issue pipeline.
    //   Identifies ROB slot assigned to newly dispatched instructions.
    ,output [  4:0]  dispatch_tag0_o
    ,output [  4:0]  dispatch_tag1_o
    ,output          dispatch_tag0_valid_o
    ,output          dispatch_tag1_valid_o
    // flush_pipeline_o:
    //   Connected to frontend/pipeline flush control.
    //   Asserts when head commit detects exception or branch mispredict.
    ,output          flush_pipeline_o
    ,output          empty_o
    ,output          full_o
);

localparam ROB_DEPTH = 32;

(* ram_style = XILINX_RAM_STYLE, ram_extract = "yes" *) reg        valid_q[0:ROB_DEPTH-1];
(* ram_style = XILINX_RAM_STYLE, ram_extract = "yes" *) reg        ready_q[0:ROB_DEPTH-1];
(* ram_style = XILINX_RAM_STYLE, ram_extract = "yes" *) reg        exception_q[0:ROB_DEPTH-1];
(* ram_style = XILINX_RAM_STYLE, ram_extract = "yes" *) reg        branch_mispredict_q[0:ROB_DEPTH-1];
(* ram_style = XILINX_RAM_STYLE, ram_extract = "yes" *) reg [4:0]  arch_rd_q[0:ROB_DEPTH-1];
(* ram_style = "block", ram_extract = "yes" *)        reg [31:0] pc_q[0:ROB_DEPTH-1];
(* ram_style = XILINX_RAM_STYLE, ram_extract = "yes" *) reg [5:0]  phys_rd_new_q[0:ROB_DEPTH-1];
(* ram_style = XILINX_RAM_STYLE, ram_extract = "yes" *) reg [5:0]  phys_rd_old_q[0:ROB_DEPTH-1];

reg [4:0]  head_q;
reg [4:0]  tail_q;
// count_q tracks in-flight ROB entries for full/empty and grant logic.
reg [5:0]  count_q;

wire [4:0] head_p1_w = head_q + 5'd1;

wire head_valid_w       = valid_q[head_q];
wire head_ready_w       = ready_q[head_q];
wire head_exception_w   = exception_q[head_q];
wire head_mispredict_w  = branch_mispredict_q[head_q];

wire flush_w = head_valid_w && (head_exception_w || head_mispredict_w);

wire head1_valid_w      = valid_q[head_p1_w];
wire head1_ready_w      = ready_q[head_p1_w];
wire head1_exception_w  = exception_q[head_p1_w];
wire head1_mispredict_w = branch_mispredict_q[head_p1_w];

wire can_commit0_w = head_valid_w && head_ready_w && !head_exception_w && !head_mispredict_w;
wire can_commit1_w = can_commit0_w && head1_valid_w && head1_ready_w && !head1_exception_w && !head1_mispredict_w;
wire [1:0] commit_cnt_w = {1'b0, can_commit0_w} + {1'b0, can_commit1_w};

wire [5:0] free_entries_w = 6'd32 - count_q;
wire       push_grant0_w  = push0_i && (free_entries_w != 6'd0);
wire       push_grant1_w  = push1_i && (free_entries_w > {5'd0, push_grant0_w});
wire [1:0] push_cnt_w     = {1'b0, push_grant0_w} + {1'b0, push_grant1_w};

wire [4:0] tail_p1_w = tail_q + 5'd1;

assign commit_valid0_o       = can_commit0_w && !flush_w;
assign commit_valid1_o       = can_commit1_w && !flush_w;
assign commit_pc0_o          = pc_q[head_q];
assign commit_pc1_o          = pc_q[head_p1_w];
assign commit_arch_rd0_o     = arch_rd_q[head_q];
assign commit_arch_rd1_o     = arch_rd_q[head_p1_w];
assign commit_phys_rd_new0_o = phys_rd_new_q[head_q];
assign commit_phys_rd_new1_o = phys_rd_new_q[head_p1_w];
assign commit_phys_rd_old0_o = phys_rd_old_q[head_q];
assign commit_phys_rd_old1_o = phys_rd_old_q[head_p1_w];
assign dispatch_tag0_o       = tail_q;
assign dispatch_tag1_o       = tail_p1_w;
// Valid qualifiers ensure tags are consumed only when corresponding dispatch is granted.
assign dispatch_tag0_valid_o = push_grant0_w;
assign dispatch_tag1_valid_o = push_grant1_w;
assign flush_pipeline_o      = flush_w;
assign empty_o               = (count_q == 6'd0);
assign full_o                = (count_q == 6'd32);

integer i;
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    for (i = 0; i < ROB_DEPTH; i = i + 1)
    begin
        valid_q[i]             <= 1'b0;
        ready_q[i]             <= 1'b0;
        exception_q[i]         <= 1'b0;
        branch_mispredict_q[i] <= 1'b0;
        arch_rd_q[i]           <= 5'b0;
        pc_q[i]                <= 32'b0;
        phys_rd_new_q[i]       <= 6'b0;
        phys_rd_old_q[i]       <= 6'b0;
    end

    head_q  <= 5'b0;
    tail_q  <= 5'b0;
    count_q <= 6'b0;
end
else if (flush_w)
begin
    for (i = 0; i < ROB_DEPTH; i = i + 1)
    begin
        valid_q[i]             <= 1'b0;
        ready_q[i]             <= 1'b0;
        exception_q[i]         <= 1'b0;
        branch_mispredict_q[i] <= 1'b0;
    end

    head_q  <= 5'b0;
    tail_q  <= 5'b0;
    count_q <= 6'b0;
end
else
begin
    // Completion matching policy:
    // - CDB provides destination physical tags only.
    // - ROB marks matching phys_rd_new entries as ready.
    // Why: this bridge keeps ROB progress without explicit per-op ROB tag return.
    if (cdb_valid0_i)
        for (i = 0; i < ROB_DEPTH; i = i + 1)
            if (valid_q[i] && (phys_rd_new_q[i] == cdb_pr0_i))
                ready_q[i] <= 1'b1;

    if (cdb_valid1_i)
        for (i = 0; i < ROB_DEPTH; i = i + 1)
            if (valid_q[i] && (phys_rd_new_q[i] == cdb_pr1_i))
                ready_q[i] <= 1'b1;

    // Commit strictly from head in program order.
    if (can_commit0_w)
    begin
        valid_q[head_q] <= 1'b0;
        ready_q[head_q] <= 1'b0;
    end

    if (can_commit1_w)
    begin
        valid_q[head_p1_w] <= 1'b0;
        ready_q[head_p1_w] <= 1'b0;
    end

    // Dispatch writes up to two new entries at current tail positions.
    if (push_grant0_w)
    begin
        valid_q[tail_q]             <= 1'b1;
        ready_q[tail_q]             <= 1'b0;
        exception_q[tail_q]         <= exception0_i;
        branch_mispredict_q[tail_q] <= branch_mispredict0_i;
        pc_q[tail_q]                <= pc0_i;
        arch_rd_q[tail_q]           <= arch_rd0_i;
        phys_rd_new_q[tail_q]       <= phys_rd_new0_i;
        phys_rd_old_q[tail_q]       <= phys_rd_old0_i;
    end

    if (push_grant1_w)
    begin
        valid_q[tail_p1_w]             <= 1'b1;
        ready_q[tail_p1_w]             <= 1'b0;
        exception_q[tail_p1_w]         <= exception1_i;
        branch_mispredict_q[tail_p1_w] <= branch_mispredict1_i;
        pc_q[tail_p1_w]                <= pc1_i;
        arch_rd_q[tail_p1_w]           <= arch_rd1_i;
        phys_rd_new_q[tail_p1_w]       <= phys_rd_new1_i;
        phys_rd_old_q[tail_p1_w]       <= phys_rd_old1_i;
    end

    head_q  <= head_q + {3'b0, commit_cnt_w};
    tail_q  <= tail_q + {3'b0, push_cnt_w};
    count_q <= count_q + {4'b0, push_cnt_w} - {4'b0, commit_cnt_w};
end

endmodule
