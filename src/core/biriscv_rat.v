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

module biriscv_rat
(
    // Inputs
     input           clk_i
    ,input           rst_i
    // flush_i + restore_rat_state_i:
    //   Connected from ROB/branch recovery control.
    //   On flush, RAT mapping is restored from checkpoint snapshot.
    //   Why: recover precise rename state after exception/mispredict.
    ,input           flush_i
    ,input  [191:0]  restore_rat_state_i
    // ar_* indices:
    //   Connected from decode/rename architectural register fields.
    //   Select current physical mappings for source operands and old rd mapping.
    ,input  [  4:0]  ar_ra0_i
    ,input  [  4:0]  ar_rb0_i
    ,input  [  4:0]  ar_ra1_i
    ,input  [  4:0]  ar_rb1_i
    ,input  [  4:0]  ar_rd0_i
    ,input  [  4:0]  ar_rd1_i
    // pr_rd*_i + we*_i:
    //   Connected from free-list allocation / rename write-enable decisions.
    //   Update architectural destination mapping to newly allocated physical reg.
    ,input  [  5:0]  pr_rd0_i
    ,input  [  5:0]  pr_rd1_i
    ,input           we0_i
    ,input           we1_i

    // Outputs
    // pr_ra*/pr_rb*:
    //   Connected to rename/issue operand-tag path.
    //   Provide physical source tags to read from PRF / track dependencies.
    ,output [  5:0]  pr_ra0_o
    ,output [  5:0]  pr_rb0_o
    ,output [  5:0]  pr_ra1_o
    ,output [  5:0]  pr_rb1_o
    // pr_rd*_old_o:
    //   Connected to ROB dispatch bookkeeping.
    //   Carries stale physical destination mapping to be freed at commit.
    ,output [  5:0]  pr_rd0_old_o
    ,output [  5:0]  pr_rd1_old_o
);

reg [5:0] rat_q[0:31];

wire [5:0] pr_ra0_raw_w = rat_q[ar_ra0_i];
wire [5:0] pr_rb0_raw_w = rat_q[ar_rb0_i];
wire [5:0] pr_ra1_raw_w = rat_q[ar_ra1_i];
wire [5:0] pr_rb1_raw_w = rat_q[ar_rb1_i];
wire [5:0] pr_rd0_raw_w = rat_q[ar_rd0_i];
wire [5:0] pr_rd1_raw_w = rat_q[ar_rd1_i];

// Intra-cycle forwarding policy:
// - Slot 0 rename updates are visible to slot 1 reads in same cycle.
// - Why: preserve program-order rename semantics for dual-dispatch pairs.
assign pr_ra0_o = pr_ra0_raw_w;
assign pr_rb0_o = pr_rb0_raw_w;
assign pr_ra1_o = (we0_i && (ar_rd0_i != 5'd0) && (ar_rd0_i == ar_ra1_i)) ? pr_rd0_i : pr_ra1_raw_w;
assign pr_rb1_o = (we0_i && (ar_rd0_i != 5'd0) && (ar_rd0_i == ar_rb1_i)) ? pr_rd0_i : pr_rb1_raw_w;
assign pr_rd0_old_o = pr_rd0_raw_w;
assign pr_rd1_old_o = (we0_i && (ar_rd0_i != 5'd0) && (ar_rd0_i == ar_rd1_i)) ? pr_rd0_i : pr_rd1_raw_w;

integer i;
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    // Identity map on reset: xN -> pN
    for (i = 0; i < 32; i = i + 1)
        rat_q[i] <= i[5:0];
end
else if (flush_i)
begin
    // Restore all 32 architectural mappings from supplied checkpoint bus.
    for (i = 0; i < 32; i = i + 1)
        rat_q[i] <= restore_rat_state_i[(i * 6) +: 6];
end
else
begin
    if (we0_i && (ar_rd0_i != 5'd0))
        rat_q[ar_rd0_i] <= pr_rd0_i;

    if (we1_i && (ar_rd1_i != 5'd0))
        rat_q[ar_rd1_i] <= pr_rd1_i;
end

endmodule
