module tb_top;

// -----------------------------------------------------------------------------
// tb_top.v
// -----------------------------------------------------------------------------
// Purpose:
//   Top-level Icarus/SystemVerilog testbench for biRISC-V core bring-up and
//   OoO-oriented observability.
//
// Responsibilities:
//   1) Generate clock/reset.
//   2) Load test program image into local TCM model.
//   3) Capture issue/execution/memory logs for debug analysis.
//   4) Derive commit-side trace signals from internal ROB state.
//   5) End simulation on explicit PASS signature or watchdog timeout.
//   6) Optionally instantiate OoO structural assertion checks.
//
// PASS contract with software:
//   - Software writes 0x00000001 to address 0x8001FFFC.
//   - TB detects this write and calls $finish immediately.
//
// Notes:
//   - Hierarchical references are intentionally used for deep observability.
//   - This bench prioritizes debug visibility over strict encapsulation.
// -----------------------------------------------------------------------------

`ifdef SVA_CHECKS
`include "tb_ooo_assertions.sv"
`endif

reg clk;
reg rst;

reg [7:0] mem[131072:0];
integer i;
integer f;
integer f_issue_log;
integer f_exec_log;
integer f_mem_log;
integer sim_cycles_q;
integer sim_max_cycles_q;
reg     pass_seen_r;
reg        exec_log_v0_r;
reg        exec_log_v1_r;
reg [31:0] exec_log_pc0_r;
reg [31:0] exec_log_pc1_r;
reg [31:0] exec_log_ins0_r;
reg [31:0] exec_log_ins1_r;
reg [63:0] rat_phys_bitmap_r;
reg [6:0]  rat_allocated_count_r;
integer    rat_i;
integer    rat_j;

function [31:0] instr_at_pc;
    input [31:0] pc;
    integer idx;
begin
    // Convert architectural PC into local memory-array index space.
    idx = pc - 32'h80000000;

    if (idx >= 0 && (idx + 3) <= 131072)
        instr_at_pc = {mem[idx+3], mem[idx+2], mem[idx+1], mem[idx]};
    else
        instr_at_pc = 32'h00000000;
end
endfunction

// PASS condition: software writes signature 0x00000001 to 0x8001FFFC.
always @(posedge clk)
begin
    if (rst)
        pass_seen_r <= 1'b0;
    else if (!pass_seen_r && (mem_d_wr_w != 4'b0000) &&
             (mem_d_addr_w == 32'h8001fffc) &&
             (mem_d_data_wr_w == 32'h00000001))
    begin
        pass_seen_r <= 1'b1;
        $display("[TB] PASS signature detected at addr=%08x data=%08x", mem_d_addr_w, mem_d_data_wr_w);
        $finish;
    end
end

initial
begin
    // Bring-up banner and optional waveform dumping.
    $display("Starting bench");

    if (`TRACE)
    begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_top);
    end

    f_issue_log = $fopen("issue_log.txt", "w");
    f_exec_log  = $fopen("execution_order_log.txt", "w");
    f_mem_log   = $fopen("memory_dump_log.txt", "w");

    if (f_issue_log == 0 || f_exec_log == 0 || f_mem_log == 0)
    begin
        $display("ERROR: Could not open log files");
        $finish;
    end

    $fdisplay(f_issue_log, "# ISSUE LOG: (dir0, ins0); (dir1, ins1)");
    $fdisplay(f_exec_log,  "# EXECUTION ORDER LOG (EXEC LAUNCH): (dir0, ins0); (dir1, ins1)");
    $fdisplay(f_mem_log,   "# MEMORY DUMP: addr byte0 byte1 byte2 byte3 word");

    // Apply reset for a fixed number of cycles.
    clk = 0;
    rst = 1;
    repeat (5) @(posedge clk);
    rst = 0;

    // Load binary image into local byte array, then mirror into TCM model.
    for (i=0;i<131072;i=i+1)
        mem[i] = 0;

    f = $fopenr("./build/tcm.bin");
    i = $fread(mem, f);
    for (i=0;i<131072;i=i+1)
        u_mem.write(i, mem[i]);

    // Dump loaded memory image to a log for reproducibility/debug.
    for (i=0;i<131072;i=i+4)
        $fdisplay(f_mem_log,
                  "addr=%08x b0=%02x b1=%02x b2=%02x b3=%02x word=%08x",
                  32'h80000000 + i,
                  mem[i],
                  mem[i+1],
                  mem[i+2],
                  mem[i+3],
                  {mem[i+3], mem[i+2], mem[i+1], mem[i]});
end

always @(posedge clk)
begin
    if (!rst)
    begin
        // Per-cycle temporary packing of up to two unique execution launches.
        exec_log_v0_r  = 1'b0;
        exec_log_v1_r  = 1'b0;
        exec_log_pc0_r = 32'b0;
        exec_log_pc1_r = 32'b0;
        exec_log_ins0_r = 32'b0;
        exec_log_ins1_r = 32'b0;

        // Issue log: two columns/slots from dual issue dispatch.
        $fdisplay(f_issue_log,
                  "t=%0t (dir0=%08x, ins0=%08x); (dir1=%08x, ins1=%08x) v0=%0d v1=%0d",
                  $time,
                  u_dut.opcode0_pc_w,
                  u_dut.opcode0_opcode_w,
                  u_dut.opcode1_pc_w,
                  u_dut.opcode1_opcode_w,
                  u_dut.exec0_opcode_valid_w,
                  u_dut.exec1_opcode_valid_w);

        // Execution-order log records launch points observed at unit inputs.
        // This avoids dependence on incomplete ROB-tag integration paths.
        if (u_dut.exec0_opcode_valid_w)
        begin
            exec_log_v0_r   = 1'b1;
            exec_log_pc0_r  = u_dut.opcode0_pc_w;
            exec_log_ins0_r = u_dut.opcode0_opcode_w;
        end

        if (u_dut.exec1_opcode_valid_w)
        begin
            if (!exec_log_v0_r)
            begin
                exec_log_v0_r   = 1'b1;
                exec_log_pc0_r  = u_dut.opcode1_pc_w;
                exec_log_ins0_r = u_dut.opcode1_opcode_w;
            end
            else if (!exec_log_v1_r &&
                     ((u_dut.opcode1_pc_w != exec_log_pc0_r) ||
                      (u_dut.opcode1_opcode_w != exec_log_ins0_r)))
            begin
                exec_log_v1_r   = 1'b1;
                exec_log_pc1_r  = u_dut.opcode1_pc_w;
                exec_log_ins1_r = u_dut.opcode1_opcode_w;
            end
        end

        if (u_dut.lsu_opcode_valid_w)
        begin
            if (!exec_log_v0_r)
            begin
                exec_log_v0_r   = 1'b1;
                exec_log_pc0_r  = u_dut.lsu_opcode_pc_w;
                exec_log_ins0_r = u_dut.lsu_opcode_opcode_w;
            end
            else if (!exec_log_v1_r &&
                     ((u_dut.lsu_opcode_pc_w != exec_log_pc0_r) ||
                      (u_dut.lsu_opcode_opcode_w != exec_log_ins0_r)))
            begin
                exec_log_v1_r   = 1'b1;
                exec_log_pc1_r  = u_dut.lsu_opcode_pc_w;
                exec_log_ins1_r = u_dut.lsu_opcode_opcode_w;
            end
        end

        if (u_dut.mul_opcode_valid_w)
        begin
            if (!exec_log_v0_r)
            begin
                exec_log_v0_r   = 1'b1;
                exec_log_pc0_r  = u_dut.mul_opcode_pc_w;
                exec_log_ins0_r = u_dut.mul_opcode_opcode_w;
            end
            else if (!exec_log_v1_r &&
                     ((u_dut.mul_opcode_pc_w != exec_log_pc0_r) ||
                      (u_dut.mul_opcode_opcode_w != exec_log_ins0_r)))
            begin
                exec_log_v1_r   = 1'b1;
                exec_log_pc1_r  = u_dut.mul_opcode_pc_w;
                exec_log_ins1_r = u_dut.mul_opcode_opcode_w;
            end
        end

        if (u_dut.div_opcode_valid_w)
        begin
            if (!exec_log_v0_r)
            begin
                exec_log_v0_r   = 1'b1;
                exec_log_pc0_r  = u_dut.opcode0_pc_w;
                exec_log_ins0_r = u_dut.opcode0_opcode_w;
            end
            else if (!exec_log_v1_r &&
                     ((u_dut.opcode0_pc_w != exec_log_pc0_r) ||
                      (u_dut.opcode0_opcode_w != exec_log_ins0_r)))
            begin
                exec_log_v1_r   = 1'b1;
                exec_log_pc1_r  = u_dut.opcode0_pc_w;
                exec_log_ins1_r = u_dut.opcode0_opcode_w;
            end
        end

        if (exec_log_v0_r || exec_log_v1_r)
        begin
            $fdisplay(f_exec_log,
                      "t=%0t (dir0=%08x, ins0=%08x); (dir1=%08x, ins1=%08x) v0=%0d v1=%0d",
                      $time,
                      exec_log_pc0_r,
                      exec_log_ins0_r,
                      exec_log_pc1_r,
                      exec_log_ins1_r,
                      exec_log_v0_r,
                      exec_log_v1_r);
        end
    end
end

initial
begin
    // Free-running 100 MHz equivalent clock (10 time-unit period).
    forever
    begin 
        clk = #5 ~clk;
    end
end

// Watchdog to avoid endless simulation when software stays in a terminal loop.
// Override with: vvp ... +MAX_CYCLES=<N>
initial
begin
    pass_seen_r = 1'b0;
    sim_cycles_q = 0;
    if (!$value$plusargs("MAX_CYCLES=%d", sim_max_cycles_q))
        sim_max_cycles_q = 200000;

    wait(!rst);
    forever
    begin
        @(posedge clk);
        sim_cycles_q = sim_cycles_q + 1;

        if (sim_cycles_q >= sim_max_cycles_q)
        begin
            // Explicit timeout terminates tests that fail to signal PASS.
            $display("[TB] TIMEOUT: reached MAX_CYCLES=%0d, finishing simulation.", sim_max_cycles_q);
            $finish;
        end
    end
end

wire          mem_i_rd_w;
wire          mem_i_flush_w;
wire          mem_i_invalidate_w;
wire [ 31:0]  mem_i_pc_w;
wire [ 31:0]  mem_d_addr_w;
wire [ 31:0]  mem_d_data_wr_w;
wire          mem_d_rd_w;
wire [  3:0]  mem_d_wr_w;
wire          mem_d_cacheable_w;
wire [ 10:0]  mem_d_req_tag_w;
wire          mem_d_invalidate_w;
wire          mem_d_writeback_w;
wire          mem_d_flush_w;
wire          mem_i_accept_w;
wire          mem_i_valid_w;
wire          mem_i_error_w;
wire [ 63:0]  mem_i_inst_w;
wire [ 31:0]  mem_d_data_rd_w;
wire          mem_d_accept_w;
wire          mem_d_ack_w;
wire          mem_d_error_w;
wire [ 10:0]  mem_d_resp_tag_w;

riscv_core
u_dut
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // Inputs
     .clk_i(clk)
    ,.rst_i(rst)
    ,.mem_d_data_rd_i(mem_d_data_rd_w)
    ,.mem_d_accept_i(mem_d_accept_w)
    ,.mem_d_ack_i(mem_d_ack_w)
    ,.mem_d_error_i(mem_d_error_w)
    ,.mem_d_resp_tag_i(mem_d_resp_tag_w)
    ,.mem_i_accept_i(mem_i_accept_w)
    ,.mem_i_valid_i(mem_i_valid_w)
    ,.mem_i_error_i(mem_i_error_w)
    ,.mem_i_inst_i(mem_i_inst_w)
    ,.intr_i(1'b0)
    ,.reset_vector_i(32'h80000000)
    ,.cpu_id_i('b0)

    // Outputs
    ,.mem_d_addr_o(mem_d_addr_w)
    ,.mem_d_data_wr_o(mem_d_data_wr_w)
    ,.mem_d_rd_o(mem_d_rd_w)
    ,.mem_d_wr_o(mem_d_wr_w)
    ,.mem_d_cacheable_o(mem_d_cacheable_w)
    ,.mem_d_req_tag_o(mem_d_req_tag_w)
    ,.mem_d_invalidate_o(mem_d_invalidate_w)
    ,.mem_d_writeback_o(mem_d_writeback_w)
    ,.mem_d_flush_o(mem_d_flush_w)
    ,.mem_i_rd_o(mem_i_rd_w)
    ,.mem_i_flush_o(mem_i_flush_w)
    ,.mem_i_invalidate_o(mem_i_invalidate_w)
    ,.mem_i_pc_o(mem_i_pc_w)
);

tcm_mem
u_mem
(
    // Inputs
     .clk_i(clk)
    ,.rst_i(rst)
    ,.mem_i_rd_i(mem_i_rd_w)
    ,.mem_i_flush_i(mem_i_flush_w)
    ,.mem_i_invalidate_i(mem_i_invalidate_w)
    ,.mem_i_pc_i(mem_i_pc_w)
    ,.mem_d_addr_i(mem_d_addr_w)
    ,.mem_d_data_wr_i(mem_d_data_wr_w)
    ,.mem_d_rd_i(mem_d_rd_w)
    ,.mem_d_wr_i(mem_d_wr_w)
    ,.mem_d_cacheable_i(mem_d_cacheable_w)
    ,.mem_d_req_tag_i(mem_d_req_tag_w)
    ,.mem_d_invalidate_i(mem_d_invalidate_w)
    ,.mem_d_writeback_i(mem_d_writeback_w)
    ,.mem_d_flush_i(mem_d_flush_w)

    // Outputs
    ,.mem_i_accept_o(mem_i_accept_w)
    ,.mem_i_valid_o(mem_i_valid_w)
    ,.mem_i_error_o(mem_i_error_w)
    ,.mem_i_inst_o(mem_i_inst_w)
    ,.mem_d_data_rd_o(mem_d_data_rd_w)
    ,.mem_d_accept_o(mem_d_accept_w)
    ,.mem_d_ack_o(mem_d_ack_w)
    ,.mem_d_error_o(mem_d_error_w)
    ,.mem_d_resp_tag_o(mem_d_resp_tag_w)
);

// Commit-trace signals are derived from internal ROB visibility.
// This keeps trace output aligned to architectural retirement points.
wire        commit_valid0_w   = u_dut.u_rob_ooo.commit_valid0_o;
wire        commit_valid1_w   = u_dut.u_rob_ooo.commit_valid1_o;
wire [31:0] commit_pc0_w      = u_dut.u_rob_ooo.commit_pc0_o;
wire [31:0] commit_pc1_w      = u_dut.u_rob_ooo.commit_pc1_o;
wire [31:0] commit_instr0_w   = instr_at_pc(commit_pc0_w);
wire [31:0] commit_instr1_w   = instr_at_pc(commit_pc1_w);
wire [4:0]  commit_arch_rd0_w = u_dut.u_rob_ooo.commit_arch_rd0_o;
wire [4:0]  commit_arch_rd1_w = u_dut.u_rob_ooo.commit_arch_rd1_o;
wire [31:0] commit_rd_val0_w  = u_dut.rob_top_commit_rd_val0_w;
wire [31:0] commit_rd_val1_w  = u_dut.rob_top_commit_rd_val1_w;

// One trace instance per commit lane to preserve per-slot visibility.
biriscv_trace_sim
u_trace_commit_pipe0
(
    .clk_i(clk)
    ,.commit_valid0_i(commit_valid0_w)
    ,.commit_valid1_i(1'b0)
    ,.commit_pc0_i(commit_pc0_w)
    ,.commit_pc1_i(32'b0)
    ,.commit_instr0_i(commit_instr0_w)
    ,.commit_instr1_i(32'b0)
    ,.commit_arch_rd0_i(commit_arch_rd0_w)
    ,.commit_arch_rd1_i(5'b0)
    ,.commit_rd_val0_i(commit_rd_val0_w)
    ,.commit_rd_val1_i(32'b0)
);

biriscv_trace_sim
u_trace_commit_pipe1
(
    .clk_i(clk)
    ,.commit_valid0_i(commit_valid1_w)
    ,.commit_valid1_i(1'b0)
    ,.commit_pc0_i(commit_pc1_w)
    ,.commit_pc1_i(32'b0)
    ,.commit_instr0_i(commit_instr1_w)
    ,.commit_instr1_i(32'b0)
    ,.commit_arch_rd0_i(commit_arch_rd1_w)
    ,.commit_arch_rd1_i(5'b0)
    ,.commit_rd_val0_i(commit_rd_val1_w)
    ,.commit_rd_val1_i(32'b0)
);

// Count unique physical registers currently referenced by RAT.
always @ *
begin
    // Compute number of unique physical registers referenced by RAT mapping.
    rat_phys_bitmap_r    = 64'b0;
    rat_allocated_count_r = 7'b0;

    for (rat_i = 0; rat_i < 32; rat_i = rat_i + 1)
        rat_phys_bitmap_r[u_dut.u_rat_ooo.rat_q[rat_i]] = 1'b1;

    for (rat_j = 0; rat_j < 64; rat_j = rat_j + 1)
        rat_allocated_count_r = rat_allocated_count_r + {6'b0, rat_phys_bitmap_r[rat_j]};
end

`ifdef SVA_CHECKS
// Optional OoO structural checks; enabled only when SVA_CHECKS is defined.
tb_ooo_assertions
u_ooo_assertions
(
     .clk_i(clk)
    ,.rst_i(rst)
    ,.freelist_free_count_i(u_dut.u_freelist_ooo.count_q)
    ,.freelist_empty_i(u_dut.u_freelist_ooo.empty_o)
    ,.freelist_full_i(u_dut.u_freelist_ooo.count_q == 7'd64)
    ,.pop_req_0_i(u_dut.u_freelist_ooo.pop_req_0_i)
    ,.pop_req_1_i(u_dut.u_freelist_ooo.pop_req_1_i)
    ,.pop_valid_0_i(u_dut.u_freelist_ooo.pop_valid_0_o)
    ,.pop_valid_1_i(u_dut.u_freelist_ooo.pop_valid_1_o)
    ,.pop_idx_0_i(u_dut.u_freelist_ooo.pop_idx_0_o)
    ,.pop_idx_1_i(u_dut.u_freelist_ooo.pop_idx_1_o)
    ,.push_req_0_i(u_dut.u_freelist_ooo.push_req_0_i)
    ,.push_req_1_i(u_dut.u_freelist_ooo.push_req_1_i)
    ,.rat_allocated_count_i(rat_allocated_count_r)
    ,.rob_inflight_count_i({1'b0, u_dut.u_rob_ooo.count_q})
    ,.rob_full_i(u_dut.u_rob_ooo.full_o)
    ,.rob_dispatch_0_i(u_dut.u_rob_ooo.push0_i)
    ,.rob_dispatch_1_i(u_dut.u_rob_ooo.push1_i)
);
`endif

endmodule
