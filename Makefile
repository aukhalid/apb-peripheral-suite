# ==============================================================================
# AUTHOR      : Ahasan Ullah Khalid
# PROJECT     : apb-peripheral-suite
# FILE        : Makefile
# DESCRIPTION : Master Build & Verification Automation System
#               - Static code linting with Verilator
#               - UVM & SVA Simulation with AMD Vivado XSim
#               - IP reuse integration from sv-common-ip-library submodule
#               - GTKWave visualizer and artifact isolation
# ==============================================================================

### ------------------------------------------------------------------------------
### 1. Dynamic Path Resolutions & Workspace Layout
### ------------------------------------------------------------------------------
PWD         := $(shell pwd)
BUILD_DIR   := $(PWD)/build
WAVE_DIR    := $(BUILD_DIR)/waves
SUBMODULE   := $(PWD)/submodule/sv-common-ip-library

### Submodule Assets Discovery
COMMON_PKGS := $(abspath $(sort $(wildcard $(SUBMODULE)/common/packages/*.sv)))
COMMON_IFS  := $(abspath $(sort $(wildcard $(SUBMODULE)/common/interfaces/*.sv)))
COMMON_ASRT := $(abspath $(sort $(wildcard $(SUBMODULE)/common/assertions/*.sv)))
COMMON_MACROS := $(SUBMODULE)/common/macros

# Reused RTL modules from Project 1
REUSED_RTL  := $(abspath $(sort $(wildcard $(SUBMODULE)/rtl/foundation/*/*.sv \
                                           $(SUBMODULE)/rtl/memory/*/*.sv \
                                           $(SUBMODULE)/rtl/datapath/*/*.sv \
                                           $(SUBMODULE)/rtl/combinational/*/*.sv \
                                           $(SUBMODULE)/foundation/*/*.sv \
                                           $(SUBMODULE)/memory/*/*.sv \
                                           $(SUBMODULE)/datapath/*/*.sv \
                                           $(SUBMODULE)/combinational/*/*.sv)))

### Project 2 RTL Source Discovery
PKG_SRCS    := $(abspath $(sort $(wildcard rtl/pkg/*.sv)))
INTC_SRCS   := $(abspath $(sort $(wildcard rtl/interconnect/*.sv)))
CTRL_SRCS   := $(abspath $(sort $(wildcard rtl/controllers/*.sv)))
PERIPH_SRCS := $(abspath $(sort $(wildcard rtl/peripherals/*.sv)))
TOP_RTL     := $(abspath $(sort $(wildcard rtl/top/*.sv)))
ALL_RTL     := $(INTC_SRCS) $(CTRL_SRCS) $(PERIPH_SRCS) $(TOP_RTL)

### Project 2 Verification / TB Discovery
TB_IF       := $(abspath $(sort $(wildcard tb/if/*.sv)))
TB_AGENT    := $(abspath $(sort $(wildcard tb/uvm/apb_agent/*.sv)))
TB_ENV      := $(abspath $(sort $(wildcard tb/uvm/env/*.sv)))
TB_TESTS    := $(abspath $(sort $(wildcard tb/uvm/tests/*.sv)))
TB_TOP      := $(abspath $(wildcard tb/uvm/tb_top.sv))

### ------------------------------------------------------------------------------
### 2. Simulator, UVM & Linter Configuration
### ------------------------------------------------------------------------------
SIM_TOP     := tb_top
TEST_NAME   ?= apb_reg_test
SNAPSHOT    := $(SIM_TOP)_snapshot
VCD_FILE    := $(WAVE_DIR)/dump.vcd

### Include Directories
VERILATOR_INC := -I$(PWD)/rtl/pkg \
                 -I$(PWD)/tb/if \
                 -I$(PWD)/tb/uvm/apb_agent \
                 -I$(PWD)/tb/uvm/env \
                 -I$(PWD)/tb/uvm/tests \
                 -I$(COMMON_MACROS)

XVLOG_INC     := -i $(PWD)/rtl/pkg \
                 -i $(PWD)/tb/if \
                 -i $(PWD)/tb/uvm/apb_agent \
                 -i $(PWD)/tb/uvm/env \
                 -i $(PWD)/tb/uvm/tests \
                 -i $(COMMON_MACROS)

### Verilator Lint Flags
VERILATOR_FLAGS := --lint-only -Wall --assert -DSIMULATION $(VERILATOR_INC) \
                   -y rtl/pkg \
                   -y rtl/interconnect \
                   -y rtl/controllers \
                   -y rtl/peripherals \
                   -y rtl/top

### Vivado XSim Flags (Enables UVM & SVA)
XVLOG_FLAGS := -sv $(XVLOG_INC) -d SIMULATION -L uvm
XELAB_FLAGS := -L uvm -timescale 1ns/1ps -debug typical

.PHONY: all setup lint sim test wave clean help

all: lint sim

### ------------------------------------------------------------------------------
### 3. Environment Initialization
### ------------------------------------------------------------------------------
setup:
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(WAVE_DIR)

### ------------------------------------------------------------------------------
### 4. Static Linting (Verilator)
### ------------------------------------------------------------------------------
lint:
	@echo "=== [LINT] Running Verilator Static Analysis on Subsystem RTL ==="
	@if [ -n "$(strip $(PKG_SRCS)$(ALL_RTL))" ]; then \
		verilator $(VERILATOR_FLAGS) $(PKG_SRCS) $(ALL_RTL); \
		echo "=== [LINT SUCCESS] Zero errors/warnings found in APB Subsystem RTL! ==="; \
	else \
		echo "[LINT NOTICE] No RTL files detected yet to lint."; \
	fi

### ------------------------------------------------------------------------------
### 5. Multi-Stage Simulation Target (Vivado XSim)
### ------------------------------------------------------------------------------
sim: setup
	@echo "=== [SIM] Step 1: Compiling Submodule Packages & Infrastructure ==="
	@if [ -n "$(strip $(COMMON_PKGS))" ]; then cd $(BUILD_DIR) && xvlog $(XVLOG_FLAGS) $(COMMON_PKGS); fi
	@if [ -n "$(strip $(COMMON_IFS))" ];  then cd $(BUILD_DIR) && xvlog $(XVLOG_FLAGS) $(COMMON_IFS); fi
	@if [ -n "$(strip $(COMMON_ASRT))" ]; then cd $(BUILD_DIR) && xvlog $(XVLOG_FLAGS) $(COMMON_ASRT); fi
	@if [ -n "$(strip $(REUSED_RTL))" ];  then cd $(BUILD_DIR) && xvlog $(XVLOG_FLAGS) $(REUSED_RTL); fi
	@echo "=== [SIM SUCCESS] Submodule Infrastructure Compiled ==="

	@echo "=== [SIM] Step 2: Compiling APB Protocol Packages & Interfaces ==="
	@if [ -n "$(strip $(PKG_SRCS))" ];    then cd $(BUILD_DIR) && xvlog $(XVLOG_FLAGS) $(PKG_SRCS); fi
	@if [ -n "$(strip $(TB_IF))" ];       then cd $(BUILD_DIR) && xvlog $(XVLOG_FLAGS) $(TB_IF); fi
	@echo "=== [SIM SUCCESS] APB Package & Interface Compiled ==="

	@echo "=== [SIM] Step 3: Compiling APB Subsystem RTL ==="
	@if [ -n "$(strip $(ALL_RTL))" ];     then cd $(BUILD_DIR) && xvlog $(XVLOG_FLAGS) $(ALL_RTL); fi
	@echo "=== [SIM SUCCESS] Subsystem RTL Compiled ==="

	@echo "=== [SIM] Step 4: Compiling UVM Verification Components ==="
	@if [ -n "$(strip $(TB_AGENT))" ];   then cd $(BUILD_DIR) && xvlog $(XVLOG_FLAGS) $(TB_AGENT); fi
	@if [ -n "$(strip $(TB_ENV))" ];     then cd $(BUILD_DIR) && xvlog $(XVLOG_FLAGS) $(TB_ENV); fi
	@if [ -n "$(strip $(TB_TESTS))" ];   then cd $(BUILD_DIR) && xvlog $(XVLOG_FLAGS) $(TB_TESTS); fi
	@if [ -n "$(strip $(TB_TOP))" ];     then cd $(BUILD_DIR) && xvlog $(XVLOG_FLAGS) $(TB_TOP); fi
	@echo "=== [SIM SUCCESS] UVM Testbench Compiled ==="

	@echo "=== [SIM] Step 5: Elaborating Simulation Snapshot ==="
	@cd $(BUILD_DIR) && xelab $(SIM_TOP) $(XELAB_FLAGS) -s $(SNAPSHOT)
	@echo "=== [SIM SUCCESS] Elaboration Completed ==="

	@echo "=== [SIM] Step 6: Executing UVM Test: $(TEST_NAME) ==="
	@cd $(BUILD_DIR) && xsim $(SNAPSHOT) -testplusarg "UVM_TESTNAME=$(TEST_NAME)" -runall
	@if [ -f $(BUILD_DIR)/dump.vcd ]; then mv $(BUILD_DIR)/dump.vcd $(VCD_FILE); fi
	@echo "=== [SIM SUCCESS] Simulation Finished! Waveform stored at $(VCD_FILE) ==="

### Run a specific test quickly (e.g., make test TEST_NAME=base_test)
test: sim

### ------------------------------------------------------------------------------
### 6. Waveform Viewer (GTKWave)
### ------------------------------------------------------------------------------
wave:
	@if [ -f $(VCD_FILE) ]; then \
		echo "=== Launching GTKWave GUI ==="; \
		gtkwave $(VCD_FILE) & \
	else \
		echo "[ERROR] No waveform file found at $(VCD_FILE). Run 'make sim' first!"; \
	fi

### ------------------------------------------------------------------------------
### 7. Clean Build Artifacts
### ------------------------------------------------------------------------------
clean:
	@echo "=== Purging Build Artifacts & Logs ==="
	@rm -rf $(BUILD_DIR) *.log *.jou *.pb *.vcd .Xil/ xsim.dir/

### ------------------------------------------------------------------------------
### 8. Help Menu
### ------------------------------------------------------------------------------
help:
	@echo "======================================================================="
	@echo "  APB PERIPHERAL SUITE AUTOMATION MAKEFILE"
	@echo "======================================================================="
	@echo "  make lint                  : Run Verilator syntax/SVA static check"
	@echo "  make sim                   : Compile & simulate default test ($(TEST_NAME))"
	@echo "  make test TEST_NAME=<name> : Run a specific UVM test"
	@echo "  make wave                  : Launch GTKWave GUI with dumped trace"
	@echo "  make clean                 : Purge build/ directory and simulation logs"
	@echo "======================================================================="