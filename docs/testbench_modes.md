# Testbench Mode Integration: OoO + Branch Predictor Testing

## Overview

This document outlines the integration of Out-of-Order (OoO) execution testing and branch predictor testing flavors into a single, configurable testbench (`tb_top.v`) for the biRISC-V core. The goal was to enable testing of both features simultaneously or independently without code duplication.

## Background

Two commits introduced conflicting testbench implementations:
- **bef218d**: Added OoO RTL and TB changes with extensive logging, tracing, and PASS-based exit detection.
- **24fa719**: Added tournament predictor integration with performance counters and PC-stuck exit detection.

The challenge was to merge these into a unified testbench supporting:
- OoO testing (detailed observability)
- Branch predictor testing (performance metrics)
- Combined testing (both features active)

## Implementation Plan

### 1. Test Mode Selection
Introduce preprocessor-based mode selection to enable/disable features dynamically.

### 2. Conditional OoO Features
Wrap OoO-specific code (logging, tracing, assertions) with conditional compilation.

### 3. Conditional Branch Features
Wrap branch-specific code (counters, exit detection) with conditional compilation.

### 4. Shared/Common Code
Maintain common infrastructure (clock, reset, memory loading) unconditionally.

### 5. Coexistence Enhancements
Support "BOTH" mode for simultaneous testing, with independent exit conditions.

### 6. Implementation Steps
Apply conditional compilation, restructure code for preprocessor compatibility, and validate syntax.

## Changes Implemented

### Preprocessor Configuration
```verilog
// Test mode selection: define TEST_MODE_OOO, TEST_MODE_BRANCH, or TEST_MODE_BOTH
`ifdef TEST_MODE_OOO
`define ENABLE_OOO
`endif
`ifdef TEST_MODE_BRANCH
`define ENABLE_BRANCH
`endif
`ifdef TEST_MODE_BOTH
`define ENABLE_OOO
`define ENABLE_BRANCH
`endif
`ifndef ENABLE_OOO
`ifndef ENABLE_BRANCH
`define ENABLE_BRANCH  // default
`endif
`endif
```

### OoO Features (Conditional)
- **Logging Setup**: Issue log, execution order log, memory dump log
- **PASS Detection**: Memory write monitoring for test completion
- **Watchdog Timeout**: Simulation timeout for OoO tests
- **Commit Tracing**: Two `biriscv_trace_sim` instances for retirement visibility
- **RAT Monitoring**: Physical register allocation tracking
- **SVA Assertions**: Structural checks when `SVA_CHECKS` is defined

### Branch Features (Conditional)
- **Performance Counters**: Cycle count, instruction count, IPC calculation
- **Exit Detection**: PC stuck in loop detection for program completion
- **Safety Timeout**: Fallback simulation timeout

### Code Restructuring
- Split initial blocks to avoid preprocessor issues inside statements
- Conditional memory dumping for OoO mode
- Independent exit conditions (PASS write or PC stuck)

## Usage
For OoO simulations:
```
cd tb/tb_core_icarus
bash run_ooo_sim.sh
```

For branch-related simulations
```
cd tb/tb_core_icarus
bash run_branch_sim.sh
```


### Compilation Flags
- **OoO Testing**: `iverilog ... -DTEST_MODE_OOO ...`
- **Branch Testing**: `iverilog ... -DTEST_MODE_BRANCH ...` (default if no flag)
- **Combined Testing**: `iverilog ... -DTEST_MODE_BOTH ...`

### Runtime Behavior
- **OoO Mode**: Generates detailed logs, uses PASS detection, enables assertions
- **Branch Mode**: Tracks performance metrics, uses PC stuck detection
- **Both Mode**: Combines all features; simulation ends on first exit condition met

### File Outputs
- **OoO**: `issue_log.txt`, `execution_order_log.txt`, `memory_dump_log.txt`
- **Branch**: Console output with cycle/instruction/IPC stats
- **Both**: All outputs combined

## Validation

- Syntax validated with Icarus Verilog
- Preprocessor directives balanced and conflict-free
- Default mode ensures backward compatibility
- No performance impact when features are disabled

## Future Enhancements

- Parameterize timeouts and log file names
- Add mode-specific waveform dumping
- Integrate with automated test suites
- Support additional test modes (e.g., in-order baseline)

## Files Modified

- `tb/tb_core_icarus/tb_top.v`: Main testbench with conditional compilation

## Related Commits

- bef218d: OoO RTL and TB changes
- 24fa719: Tournament predictor integration</content>
<parameter name="filePath">/home/fabian/Documents/TEC/Maestria/IC_2026/parallel_processing/biRISC-V_Nexus/docs/testbench_modes.md