module tb_top;

reg clk;
reg rst;

reg [7:0] mem[131072:0];
integer i;
integer f;

initial
begin
    $display("Starting bench");

    if (`TRACE)
    begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_top);
    end

    // Reset
    clk = 0;
    rst = 1;
    repeat (5) @(posedge clk);
    rst = 0;

    // Load TCM memory
    for (i=0;i<131072;i=i+1)
        mem[i] = 0;

    f = $fopenr("./build/tcm.bin");
    i = $fread(mem, f);
    for (i=0;i<131072;i=i+1)
        u_mem.write(i, mem[i]);
end

initial
begin
    forever
    begin 
        clk = #5 ~clk;
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

//-----------------------------------------------------------------
// Performance Counters
//-----------------------------------------------------------------
integer cycle_count;
integer instr_count;

initial begin
    cycle_count = 0;
    instr_count = 0;
end

// Count clock cycles after reset
always @(posedge clk)
    if (!rst)
        cycle_count = cycle_count + 1;

// Count retired instructions (pipe 0 + pipe 1 commits)
always @(posedge clk)
begin
    if (!rst)
    begin
        if (u_dut.u_issue.pipe0_valid_wb_w)
            instr_count = instr_count + 1;
        if (u_dut.u_issue.pipe1_valid_wb_w)
            instr_count = instr_count + 1;
    end
end

// Detect program exit: PC stuck in _exit_loop (infinite jal to self)
reg [31:0] prev_pc;
integer    stuck_count;

initial begin
    prev_pc     = 32'b0;
    stuck_count = 0;
end

always @(posedge clk)
begin
    if (!rst)
    begin
        if (mem_i_pc_w == prev_pc)
            stuck_count = stuck_count + 1;
        else
            stuck_count = 0;
        prev_pc = mem_i_pc_w;

        // If PC hasn't changed for 100 cycles, program has exited
        if (stuck_count > 100)
        begin
            $display("=== PROGRAM FINISHED (PC stuck at 0x%08x) ===", mem_i_pc_w);
            $display("========================================");
            $display("  Total cycles:       %0d", cycle_count);
            $display("  Total instructions: %0d", instr_count);
            if (cycle_count > 0)
                $display("  IPC:                %0f", $itor(instr_count) / $itor(cycle_count));
            $display("========================================");
            $finish;
        end
    end
end

// Safety timeout (adjust as needed for larger benchmarks)
initial begin
    @(negedge rst);
    #100000000;
    $display("=== SIMULATION TIMEOUT ===");
    $display("========================================");
    $display("  Total cycles:       %0d", cycle_count);
    $display("  Total instructions: %0d", instr_count);
    if (cycle_count > 0)
        $display("  IPC:                %0f", $itor(instr_count) / $itor(cycle_count));
    $display("========================================");
    $finish;
end

endmodule