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
`include "biriscv_defs.v"

module biriscv_trace_sim
(
    input                        clk_i
    // commit_valid*_i:
    //   Connected from ROB commit-valid outputs (via TB or top-level wrappers).
    //   Marks that corresponding commit slot contains a retiring instruction.
    ,input                        commit_valid0_i
    ,input                        commit_valid1_i
    // commit_pc*_i / commit_instr*_i:
    //   Connected from commit-side PC/instruction reconstruction path.
    //   Provide architectural context for trace readability and debug.
    ,input  [31:0]                commit_pc0_i
    ,input  [31:0]                commit_pc1_i
    ,input  [31:0]                commit_instr0_i
    ,input  [31:0]                commit_instr1_i
    // commit_arch_rd*_i / commit_rd_val*_i:
    //   Connected from ROB commit metadata + PRF commit readback path.
    //   Allow trace to print destination architectural register and value.
    //   rd==x0 is suppressed to avoid meaningless write-value printouts.
    ,input  [4:0]                 commit_arch_rd0_i
    ,input  [4:0]                 commit_arch_rd1_i
    ,input  [31:0]                commit_rd_val0_i
    ,input  [31:0]                commit_rd_val1_i
);

// OoO trace policy:
// - Print only on ROB commit (not on execute launch), so output reflects
//   architectural retirement order.
// - Sample at posedge clk_i so both commit lanes are time-aligned to core state.
always @ (posedge clk_i)
begin
    if (commit_valid0_i)
    begin
        if (commit_arch_rd0_i != 5'd0)
            $display("COMMIT0 pc=%08x instr=%08x rd=x%0d val=%08x", commit_pc0_i, commit_instr0_i, commit_arch_rd0_i, commit_rd_val0_i);
        else
            $display("COMMIT0 pc=%08x instr=%08x", commit_pc0_i, commit_instr0_i);
    end
end

always @ (posedge clk_i)
begin
    if (commit_valid1_i)
    begin
        if (commit_arch_rd1_i != 5'd0)
            $display("COMMIT1 pc=%08x instr=%08x rd=x%0d val=%08x", commit_pc1_i, commit_instr1_i, commit_arch_rd1_i, commit_rd_val1_i);
        else
            $display("COMMIT1 pc=%08x instr=%08x", commit_pc1_i, commit_instr1_i);
    end
end

endmodule
