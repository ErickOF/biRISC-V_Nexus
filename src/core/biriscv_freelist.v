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

module biriscv_freelist
(
    // Inputs
     input           clk_i
    ,input           rst_i
    // pop_req_*_i:
    //   Connected from rename/dispatch allocation demand.
    //   Request one/two free physical registers this cycle.
    //   Why: provide fresh physical destinations for register-renamed writes.
    ,input           pop_req_0_i
    ,input           pop_req_1_i
    // push_req_*_i + push_idx_*_i:
    //   Connected from ROB commit path (old physical destinations).
    //   Return stale physical registers to the free pool.
    //   Why: recycle physical registers once architectural state commits.
    ,input           push_req_0_i
    ,input           push_req_1_i
    ,input  [  5:0]  push_idx_0_i
    ,input  [  5:0]  push_idx_1_i

    // Outputs
    // pop_idx_*_o + pop_valid_*_o:
    //   Connected back to rename stage.
    //   Carry allocated physical destination tags for up to two instructions.
    ,output [  5:0]  pop_idx_0_o
    ,output [  5:0]  pop_idx_1_o
    ,output          pop_valid_0_o
    ,output          pop_valid_1_o
    // empty_o:
    //   Connected to rename stall logic.
    //   Why: block rename when no free physical register is available.
    ,output          empty_o
);

localparam DEPTH        = 64;
localparam RESET_COUNT  = 32;

reg [5:0] fifo_q[0:DEPTH-1];
reg [5:0] head_ptr_q;
reg [5:0] tail_ptr_q;
// count_q tracks total free entries currently available.
// This is consumed indirectly by grant logic and empty/full behavior.
reg [6:0] count_q;

wire [6:0] free_slots_w = 7'd64 - count_q;

wire       pop_grant_0_w = pop_req_0_i && (count_q != 7'd0);
wire       pop_grant_1_w = pop_req_1_i && (count_q > {6'd0, pop_grant_0_w});
wire [1:0] pop_cnt_w     = {1'b0, pop_grant_0_w} + {1'b0, pop_grant_1_w};

wire       push_grant_0_w = push_req_0_i && (free_slots_w != 7'd0);
wire       push_grant_1_w = push_req_1_i && (free_slots_w > {6'd0, push_grant_0_w});
wire [1:0] push_cnt_w     = {1'b0, push_grant_0_w} + {1'b0, push_grant_1_w};

wire [5:0] pop_ptr_1_w = head_ptr_q + {5'd0, pop_grant_0_w};
wire [5:0] push_ptr_1_w = tail_ptr_q + {5'd0, push_grant_0_w};

assign pop_valid_0_o = pop_grant_0_w;
assign pop_valid_1_o = pop_grant_1_w;
// pop index outputs are consumed by rename to form pr_rd assignments.
assign pop_idx_0_o   = fifo_q[head_ptr_q];
assign pop_idx_1_o   = fifo_q[pop_ptr_1_w];
assign empty_o       = (count_q == 7'd0);

integer i;
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    // Reset seeding policy: p0..p31 are architectural/initial mappings,
    // so free list starts with p32..p63 available for rename allocation.
    for (i = 0; i < RESET_COUNT; i = i + 1)
        fifo_q[i] <= 6'd32 + i[5:0];

    head_ptr_q <= 6'd0;
    tail_ptr_q <= 6'd32;
    count_q    <= 7'd32;
end
else
begin
    if (push_grant_0_w)
        fifo_q[tail_ptr_q] <= push_idx_0_i;

    if (push_grant_1_w)
        fifo_q[push_ptr_1_w] <= push_idx_1_i;

    head_ptr_q <= head_ptr_q + {4'd0, pop_cnt_w};
    tail_ptr_q <= tail_ptr_q + {4'd0, push_cnt_w};
    count_q    <= count_q + {5'd0, push_cnt_w} - {5'd0, pop_cnt_w};
end

endmodule
