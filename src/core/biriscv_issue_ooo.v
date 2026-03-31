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

module biriscv_issue_ooo
(
    // Inputs
     input           clk_i
    ,input           rst_i

    // Dispatch from rename (up to 2 per cycle)
    // rename*_valid_i/op_type/pr_*/rob_tag_i:
    //   Connected from rename stage outputs.
    //   Carry renamed operation identity and source/destination tags.
    //   Why: enqueue work in reservation-station form for out-of-order issue.
    ,input           rename0_valid_i
    ,input  [  3:0]  rename0_op_type_i
    ,input  [  5:0]  rename0_pr_rd_i
    ,input  [  5:0]  rename0_pr_ra_i
    ,input           rename0_ra_ready_i
    ,input  [ 31:0]  rename0_ra_val_i
    ,input  [  5:0]  rename0_pr_rb_i
    ,input           rename0_rb_ready_i
    ,input  [ 31:0]  rename0_rb_val_i
    ,input  [  4:0]  rename0_rob_tag_i
    ,input           rename1_valid_i
    ,input  [  3:0]  rename1_op_type_i
    ,input  [  5:0]  rename1_pr_rd_i
    ,input  [  5:0]  rename1_pr_ra_i
    ,input           rename1_ra_ready_i
    ,input  [ 31:0]  rename1_ra_val_i
    ,input  [  5:0]  rename1_pr_rb_i
    ,input           rename1_rb_ready_i
    ,input  [ 31:0]  rename1_rb_val_i
    ,input  [  4:0]  rename1_rob_tag_i

    // Common data bus snoop (2x)
    // cdb_val*_i/cdb_tag*_i:
    //   Connected from global CDB buses.
    //   Used to wake not-ready source operands and capture forwarded values.
    //   Why: enable issue when dependencies resolve asynchronously.
    ,input  [ 31:0]  cdb_val0_i
    ,input  [  5:0]  cdb_tag0_i
    ,input  [ 31:0]  cdb_val1_i
    ,input  [  5:0]  cdb_tag1_i

    // Outputs
    ,output          issueq_full_o
    ,output          dispatch_accept0_o
    ,output          dispatch_accept1_o

    // Issue to execution (single issue each cycle)
    ,output          exec0_opcode_valid_o
    ,output [  3:0]  exec0_op_type_o
    ,output [  5:0]  exec0_pr_rd_o
    ,output [ 31:0]  exec0_ra_val_o
    ,output [ 31:0]  exec0_rb_val_o
    // exec0_rob_tag_o:
    //   Connected to execution-unit metadata input path.
    //   Preserves ROB ownership identity from queue entry to completion.
    ,output [  4:0]  exec0_rob_tag_o
);

localparam IQ_DEPTH = 8;

reg        valid_q[0:IQ_DEPTH-1];
reg [3:0]  op_type_q[0:IQ_DEPTH-1];
reg [5:0]  pr_rd_q[0:IQ_DEPTH-1];
reg [5:0]  pr_ra_q[0:IQ_DEPTH-1];
reg        ra_ready_q[0:IQ_DEPTH-1];
reg [31:0] ra_val_q[0:IQ_DEPTH-1];
reg [5:0]  pr_rb_q[0:IQ_DEPTH-1];
reg        rb_ready_q[0:IQ_DEPTH-1];
reg [31:0] rb_val_q[0:IQ_DEPTH-1];
// rob_tag_q is carried to execution/CDB so completion can identify ROB slot.
reg [4:0]  rob_tag_q[0:IQ_DEPTH-1];
// age_q provides oldest-ready selection policy.
reg [7:0]  age_q[0:IQ_DEPTH-1];

reg [7:0]  age_counter_q;

reg [2:0] free_idx0_r;
reg [2:0] free_idx1_r;
reg       free_found0_r;
reg       free_found1_r;
integer   f;

always @ *
begin
    free_idx0_r   = 3'b0;
    free_idx1_r   = 3'b0;
    free_found0_r = 1'b0;
    free_found1_r = 1'b0;

    for (f = 0; f < IQ_DEPTH; f = f + 1)
    begin
        if (!free_found0_r && !valid_q[f])
        begin
            free_found0_r = 1'b1;
            free_idx0_r   = f[2:0];
        end
        else if (free_found0_r && !free_found1_r && !valid_q[f] && (f[2:0] != free_idx0_r))
        begin
            free_found1_r = 1'b1;
            free_idx1_r   = f[2:0];
        end
    end
end

wire push0_w = rename0_valid_i && free_found0_r;
wire push1_w = rename1_valid_i && ((push0_w && free_found1_r) || (!push0_w && free_found0_r));
wire [2:0] push1_idx_w = push0_w ? free_idx1_r : free_idx0_r;

wire queue_full_w = !free_found0_r;

reg        issue_found_r;
reg [2:0]  issue_idx_r;
reg [7:0]  issue_age_r;
integer    s;

always @ *
begin
    issue_found_r = 1'b0;
    issue_idx_r   = 3'b0;
    issue_age_r   = 8'hff;

    for (s = 0; s < IQ_DEPTH; s = s + 1)
    begin
        if (valid_q[s] && ra_ready_q[s] && rb_ready_q[s])
        begin
            if (!issue_found_r || (age_q[s] < issue_age_r))
            begin
                issue_found_r = 1'b1;
                issue_idx_r   = s[2:0];
                issue_age_r   = age_q[s];
            end
        end
    end
end

assign issueq_full_o       = queue_full_w;
assign dispatch_accept0_o  = push0_w;
assign dispatch_accept1_o  = push1_w;

assign exec0_opcode_valid_o = issue_found_r;
assign exec0_op_type_o      = op_type_q[issue_idx_r];
assign exec0_pr_rd_o        = pr_rd_q[issue_idx_r];
assign exec0_ra_val_o       = ra_val_q[issue_idx_r];
assign exec0_rb_val_o       = rb_val_q[issue_idx_r];
// ROB identity follows issued instruction for completion attribution.
assign exec0_rob_tag_o      = rob_tag_q[issue_idx_r];

integer i;
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    for (i = 0; i < IQ_DEPTH; i = i + 1)
    begin
        valid_q[i]    <= 1'b0;
        op_type_q[i]  <= 4'b0;
        pr_rd_q[i]    <= 6'b0;
        pr_ra_q[i]    <= 6'b0;
        ra_ready_q[i] <= 1'b0;
        ra_val_q[i]   <= 32'b0;
        pr_rb_q[i]    <= 6'b0;
        rb_ready_q[i] <= 1'b0;
        rb_val_q[i]   <= 32'b0;
        rob_tag_q[i]  <= 5'b0;
        age_q[i]      <= 8'b0;
    end

    age_counter_q <= 8'b0;
end
else
begin
    // CDB snooping updates source operand readiness and values.
    // Connectivity:
    // - Tags from global CDB buses are compared against queued pr_ra/pr_rb.
    // - Matching operands become ready and latch forwarded values.
    for (i = 0; i < IQ_DEPTH; i = i + 1)
    begin
        if (valid_q[i] && !ra_ready_q[i])
        begin
            if (pr_ra_q[i] == cdb_tag0_i)
            begin
                ra_ready_q[i] <= 1'b1;
                ra_val_q[i]   <= cdb_val0_i;
            end
            else if (pr_ra_q[i] == cdb_tag1_i)
            begin
                ra_ready_q[i] <= 1'b1;
                ra_val_q[i]   <= cdb_val1_i;
            end
        end

        if (valid_q[i] && !rb_ready_q[i])
        begin
            if (pr_rb_q[i] == cdb_tag0_i)
            begin
                rb_ready_q[i] <= 1'b1;
                rb_val_q[i]   <= cdb_val0_i;
            end
            else if (pr_rb_q[i] == cdb_tag1_i)
            begin
                rb_ready_q[i] <= 1'b1;
                rb_val_q[i]   <= cdb_val1_i;
            end
        end
    end

    // Issue the oldest ready instruction.
    if (issue_found_r)
        valid_q[issue_idx_r] <= 1'b0;

    // Insert up to 2 renamed instructions.
    // Connectivity:
    // - rename* payload is written into selected free entries.
    // - rob_tag is stored so the same identity exits on issue.
    if (push0_w)
    begin
        valid_q[free_idx0_r]    <= 1'b1;
        op_type_q[free_idx0_r]  <= rename0_op_type_i;
        pr_rd_q[free_idx0_r]    <= rename0_pr_rd_i;
        pr_ra_q[free_idx0_r]    <= rename0_pr_ra_i;
        ra_ready_q[free_idx0_r] <= rename0_ra_ready_i;
        ra_val_q[free_idx0_r]   <= rename0_ra_val_i;
        pr_rb_q[free_idx0_r]    <= rename0_pr_rb_i;
        rb_ready_q[free_idx0_r] <= rename0_rb_ready_i;
        rb_val_q[free_idx0_r]   <= rename0_rb_val_i;
        rob_tag_q[free_idx0_r]  <= rename0_rob_tag_i;
        age_q[free_idx0_r]      <= age_counter_q;
    end

    if (push1_w)
    begin
        valid_q[push1_idx_w]    <= 1'b1;
        op_type_q[push1_idx_w]  <= rename1_op_type_i;
        pr_rd_q[push1_idx_w]    <= rename1_pr_rd_i;
        pr_ra_q[push1_idx_w]    <= rename1_pr_ra_i;
        ra_ready_q[push1_idx_w] <= rename1_ra_ready_i;
        ra_val_q[push1_idx_w]   <= rename1_ra_val_i;
        pr_rb_q[push1_idx_w]    <= rename1_pr_rb_i;
        rb_ready_q[push1_idx_w] <= rename1_rb_ready_i;
        rb_val_q[push1_idx_w]   <= rename1_rb_val_i;
        rob_tag_q[push1_idx_w]  <= rename1_rob_tag_i;
        age_q[push1_idx_w]      <= age_counter_q + {7'd0, push0_w};
    end

    age_counter_q <= age_counter_q + {6'd0, push0_w, push1_w};
end

endmodule
