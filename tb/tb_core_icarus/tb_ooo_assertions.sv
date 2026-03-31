module tb_ooo_assertions
(
    input logic        clk_i
    ,input logic        rst_i

    // Free List accounting / status
    ,input logic [6:0]  freelist_free_count_i
    ,input logic        freelist_empty_i
    ,input logic        freelist_full_i
    ,input logic        pop_req_0_i
    ,input logic        pop_req_1_i
    ,input logic        pop_valid_0_i
    ,input logic        pop_valid_1_i
    ,input logic [5:0]  pop_idx_0_i
    ,input logic [5:0]  pop_idx_1_i
    ,input logic        push_req_0_i
    ,input logic        push_req_1_i

    // OoO global accounting
    ,input logic [6:0]  rat_allocated_count_i
    ,input logic [6:0]  rob_inflight_count_i

    // ROB dispatch flow control
    ,input logic        rob_full_i
    ,input logic        rob_dispatch_0_i
    ,input logic        rob_dispatch_1_i
);

// -----------------------------------------------------------------------------
// tb_ooo_assertions.sv
// -----------------------------------------------------------------------------
// Purpose:
//   Lightweight procedural assertion block for OoO validation in simulators
//   with limited SVA feature support.
//
// Scope of checks:
//   1) Physical register conservation across Free List + RAT + ROB.
//   2) Free List underflow / overflow protocol violations.
//   3) Duplicate physical allocation in the same cycle.
//   4) ROB overflow protection (dispatch while full).
//
// Design notes:
//   - Checks are synchronous on the core clock.
//   - Checks are disabled during reset.
//   - Failures use $fatal(1, ...) to stop simulation immediately with context.
//
// Interface contract (high level):
//   - freelist_free_count_i: number of currently free physical registers.
//   - rat_allocated_count_i: number of unique physical registers referenced by
//     the RAT architectural map view.
//   - rob_inflight_count_i: number of allocated but not-yet-committed ROB
//     entries that still hold rename ownership.
//   - pop_req_* / pop_valid_* / pop_idx_*: two-lane allocation handshake from
//     Free List to rename path.
//   - push_req_*: two-lane return requests to Free List at commit.
//   - rob_full_i / rob_dispatch_*: dispatch flow-control guard for ROB writes.
//
// Assumptions behind conservation check:
//   - The accounting model intentionally partitions PRF ownership into three
//     domains: free pool, RAT-visible mappings, and in-flight ROB ownership.
//   - If the integration strategy changes ownership rules, update this checker
//     accordingly to avoid false positives.
// -----------------------------------------------------------------------------

localparam integer PRF_TOTAL_REGS = 64;

always @(posedge clk_i)
begin
    if (!rst_i)
    begin
        // ---------------------------------------------------------------------
        // Check 1: Physical register conservation.
        // The sum of free entries, RAT-referenced mappings, and ROB in-flight
        // allocations must always equal the total number of physical registers.
        // Any mismatch indicates leaks, double-counting, or lost ownership.
        // ---------------------------------------------------------------------
        if ((freelist_free_count_i + rat_allocated_count_i + rob_inflight_count_i) != PRF_TOTAL_REGS)
            $fatal(1,
                   "SVA[OoO]: PRF conservation failed: free=%0d rat=%0d rob=%0d total=%0d",
                   freelist_free_count_i,
                   rat_allocated_count_i,
                   rob_inflight_count_i,
                   freelist_free_count_i + rat_allocated_count_i + rob_inflight_count_i);

        // ---------------------------------------------------------------------
        // Check 2a: Free List underflow attempt.
        // Pop requests are illegal when the Free List reports empty.
        // ---------------------------------------------------------------------
        if (freelist_empty_i && (pop_req_0_i || pop_req_1_i))
            $fatal(1,
                   "SVA[OoO]: Free List underflow attempt: empty=1 pop_req0=%0d pop_req1=%0d",
                   pop_req_0_i,
                   pop_req_1_i);

        // ---------------------------------------------------------------------
        // Check 2b: Free List overflow attempt.
        // Push requests are illegal when the Free List reports full.
        // ---------------------------------------------------------------------
        if (freelist_full_i && (push_req_0_i || push_req_1_i))
            $fatal(1,
                   "SVA[OoO]: Free List overflow attempt: full=1 push_req0=%0d push_req1=%0d",
                   push_req_0_i,
                   push_req_1_i);

        // ---------------------------------------------------------------------
        // Check 3: Duplicate allocation in the same cycle.
        // If both pop channels are valid, their physical indices must differ.
        // ---------------------------------------------------------------------
        if (pop_valid_0_i && pop_valid_1_i && (pop_idx_0_i == pop_idx_1_i))
            $fatal(1,
                   "SVA[OoO]: duplicate physical register allocation in same cycle: idx=%0d",
                   pop_idx_0_i);

        // ---------------------------------------------------------------------
        // Check 4: ROB overflow protection.
        // Dispatch requests are illegal when ROB full is asserted.
        // ---------------------------------------------------------------------
        if (rob_full_i && (rob_dispatch_0_i || rob_dispatch_1_i))
            $fatal(1,
                   "SVA[OoO]: ROB overflow attempt: full=1 dispatch0=%0d dispatch1=%0d",
                   rob_dispatch_0_i,
                   rob_dispatch_1_i);
    end
end

endmodule
