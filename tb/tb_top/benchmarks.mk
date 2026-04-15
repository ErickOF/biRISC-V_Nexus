# Benchmark integration for UC Berkeley riscv-benchmarks
# This file is included by tb/tb_top/makefile when present.

BENCH_TOP := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BENCH_DIR := $(abspath $(BENCH_TOP)/../riscv-benchmarks)
BENCH_LINK_SCRIPT := $(BENCH_TOP)/bench.ld

RISCV_PREFIX ?= riscv32-unknown-elf-
RISCV_GCC ?= $(RISCV_PREFIX)gcc
RISCV_OBJCOPY ?= $(RISCV_PREFIX)objcopy
RISCV_GCC_OPTS ?= -march=rv32im_zicsr -mabi=ilp32 -static -std=gnu99 -O2 -ffast-math -fno-common -fno-builtin-printf
RISCV_LINK ?= $(RISCV_GCC) -T $(BENCH_LINK_SCRIPT) $(incs)
RISCV_LINK_OPTS ?= -nostdlib -nostartfiles -ffast-math -L/usr/local/riscv_32bits_multilib/lib/gcc/riscv32-unknown-elf/13.2.0/rv32i/ilp32 -lgcc -Wl,-v
XLEN ?= 32

BENCHMARKS := \
    median \
    qsort \
    rsort \
    towers \
    vvadd \
    multiply \
    mm \
    dhrystone \
    spmv \
    mt-vvadd \
    mt-matmul \
    mt-mm \
    mt-mask-sfilter \
    mt-csaxpy \
    mt-histo

BENCH_MAKE := $(MAKE) -C $(BENCH_DIR)
BENCH_MAKE_OPTS := RISCV_PREFIX=$(RISCV_PREFIX) XLEN=$(XLEN) \
    RISCV_GCC_OPTS="$(RISCV_GCC_OPTS)" \
    RISCV_LINK="$(RISCV_LINK)" \
    RISCV_LINK_OPTS="$(RISCV_LINK_OPTS)" \
    RISCV_OBJCOPY=$(RISCV_OBJCOPY)

.PHONY: prepare-benchmarks benchmarks run-benchmark run-all-benchmarks clean-benchmarks

prepare-benchmarks:
	@echo "Preparing benchmark repository..."
	@bash "$(abspath $(BENCH_TOP)/../../scripts/prepare_benchmarks.sh)"

benchmarks: build prepare-benchmarks
	$(BENCH_MAKE) $(BENCH_MAKE_OPTS) all

run-benchmark: build prepare-benchmarks
	@if [ -z "$(BENCH)" ]; then \
	  echo "ERROR: BENCH=<benchmark-name> is required"; \
	  exit 1; \
	fi
	$(BENCH_MAKE) $(BENCH_MAKE_OPTS) $(BENCH).riscv
	$(RISCV_OBJCOPY) -O elf32-little $(BENCH_DIR)/$(BENCH).riscv $(BENCH_DIR)/$(BENCH).elf
	@echo "Running benchmark $(BENCH) in simulation"
	./build/test.x -f $(BENCH_DIR)/$(BENCH).elf -c 10000

run-all-benchmarks: build prepare-benchmarks
	@for b in $(BENCHMARKS); do \
	  echo "=== BENCHMARK: $$b ==="; \
	  $(BENCH_MAKE) $(BENCH_MAKE_OPTS) $$b.riscv; \
	  $(RISCV_OBJCOPY) -O elf32-little $(BENCH_DIR)/$$b.riscv $(BENCH_DIR)/$$b.elf; \
	  ./build/test.x -f $(BENCH_DIR)/$$b.elf -c 10000000; \
	done

clean-benchmarks:
	$(BENCH_MAKE) clean
	-rm -f $(BENCH_DIR)/*.elf
