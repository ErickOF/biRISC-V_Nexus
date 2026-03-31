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

module biriscv_prf
#(
    parameter XILINX_RAM_STYLE = "distributed"
)
(
    // Inputs
     input           clk_i
    ,input           rst_i
    // wr_* ports:
    //   Connected from global CDB buses.
    //   Carry up to two physical-register writes per cycle.
    //   Why: commit execute/memory results into renamed register space.
    ,input           wr_en_0_i
    ,input           wr_en_1_i
    ,input  [  5:0]  wr_idx_0_i
    ,input  [  5:0]  wr_idx_1_i
    ,input  [ 31:0]  wr_data_0_i
    ,input  [ 31:0]  wr_data_1_i
    ,input  [  5:0]  ra0_i
    ,input  [  5:0]  rb0_i
    ,input  [  5:0]  ra1_i
    ,input  [  5:0]  rb1_i
    // commit_rd*_i:
    //   Connected from ROB commit physical-destination outputs.
    //   Used for commit-side value visibility (trace/debug/retire observability).
    ,input  [  5:0]  commit_rd0_i
    ,input  [  5:0]  commit_rd1_i

    // Outputs
    // ra*/rb* values:
    //   Connected to issue/rename operand supply path.
    //   Provide current physical-source operand values.
    ,output [ 31:0]  ra0_value_o
    ,output [ 31:0]  rb0_value_o
    ,output [ 31:0]  ra1_value_o
    ,output [ 31:0]  rb1_value_o
    // commit_rd*_value_o:
    //   Connected to commit-trace/retire observability path.
    //   Return value currently stored at committed physical destination tags.
    ,output [ 31:0]  commit_rd0_value_o
    ,output [ 31:0]  commit_rd1_value_o
);

(* ram_style = XILINX_RAM_STYLE, ram_extract = "yes" *) reg [31:0] prf_q[0:63];

integer i;
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    for (i = 0; i < 64; i = i + 1)
        prf_q[i] <= 32'b0;
end
else
begin
    // Dual-write CDB commit into PRF; p0 remains hardwired to zero.
    if (wr_en_0_i && (wr_idx_0_i != 6'd0))
        prf_q[wr_idx_0_i] <= wr_data_0_i;

    if (wr_en_1_i && (wr_idx_1_i != 6'd0))
        prf_q[wr_idx_1_i] <= wr_data_1_i;

    prf_q[0] <= 32'b0;
end

// Write-first bypass behavior:
// - If a read index matches an in-flight write this cycle, return newest write.
// - This is consumed by rename/issue and commit-read outputs for deterministic
//   same-cycle visibility without requiring extra forwarding stages.
// - Priority favors write port 1 over port 0 when both target same index.
function [31:0] prf_read;
    input [5:0] idx;
begin
    if (idx == 6'd0)
        prf_read = 32'b0;
    else if (wr_en_1_i && (wr_idx_1_i == idx) && (wr_idx_1_i != 6'd0))
        prf_read = wr_data_1_i;
    else if (wr_en_0_i && (wr_idx_0_i == idx) && (wr_idx_0_i != 6'd0))
        prf_read = wr_data_0_i;
    else
        prf_read = prf_q[idx];
end
endfunction

assign ra0_value_o       = prf_read(ra0_i);
assign rb0_value_o       = prf_read(rb0_i);
assign ra1_value_o       = prf_read(ra1_i);
assign rb1_value_o       = prf_read(rb1_i);
assign commit_rd0_value_o = prf_read(commit_rd0_i);
assign commit_rd1_value_o = prf_read(commit_rd1_i);

endmodule
