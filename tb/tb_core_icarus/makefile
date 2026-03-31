###############################################################################
# Variables: Program ELF
###############################################################################
ELF_FILE ?= test.elf

OBJCOPY ?= riscv32-unknown-elf-objcopy
ifeq ($(shell which $(OBJCOPY)),)
  ${error $(OBJCOPY) missing from PATH}
endif
ifeq ($(shell which iverilog),)
  ${error iverilog missing from PATH - Icarus Verilog required}
endif


###############################################################################
# Variables: Defaults
###############################################################################
TRACE          ?= 1

SRC_V_DIR      ?= ../../src/core .
SRC_DIR        ?= .

EXE            ?= output.out

###############################################################################
# Variables: Verilog
###############################################################################
SRC_OOO_V   := ../../src/core/biriscv_freelist.v \
			   ../../src/core/biriscv_prf.v \
			   ../../src/core/biriscv_rat.v \
			   ../../src/core/biriscv_rob.v \
			   ../../src/core/biriscv_rename.v \
			   ../../src/core/biriscv_issue_ooo.v

SRC_V       ?= $(sort $(foreach src,$(SRC_V_DIR),$(wildcard $(src)/*.v)) $(SRC_OOO_V))
SRC_SV      ?= $(wildcard $(SRC_DIR)/*.sv)
SRC_ALL     ?= $(SRC_V) $(SRC_SV)

VFLAGS      += $(patsubst %,-I%,$(SRC_V_DIR))
VFLAGS      += -DTRACE=$(TRACE)
VFLAGS      += -Dverilog_sim
VFLAGS      += -g2012

###############################################################################
# Variables: Lists of objects, source and deps
###############################################################################
BUILD_DIR      ?= build/

###############################################################################
# Rules
###############################################################################
all: run

$(BUILD_DIR):
	@mkdir -p $@

$(BUILD_DIR)/tcm.bin: $(ELF_FILE) | $(BUILD_DIR)
	$(OBJCOPY) $< -O binary $@

$(BUILD_DIR)/$(EXE): $(SRC_ALL) | $(BUILD_DIR)
	@echo "# Compiling verilog"
	iverilog $(VFLAGS) -o $@ $(SRC_ALL)

run: $(BUILD_DIR)/$(EXE) $(BUILD_DIR)/tcm.bin
	vvp $(BUILD_DIR)/$(EXE) -vcd

view:
	gtkwave waveform.vcd gtksettings.sav  

clean:
	rm -rf $(BUILD_DIR) *.vcd
