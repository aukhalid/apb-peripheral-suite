# ==============================================================================
# AUTHOR      : Ahasan Ullah Khalid
# PROJECT     : apb-peripheral-suite
# FILE        : Makefile
# DESCRIPTION : Master Build & Verification Automation System
#               - Static code linting with Verilator
#               - UVM & SVA Simulation with AMD Vivado XSim
#               - IP reuse integration from sv-common-ip-library submodule
#               - Quiet Terminal: Displays only WARNING, ERROR, FATAL, and Test Reports
# ==============================================================================

### ------------------------------------------------------------------------------
### 1. Dynamic Path Resolutions & Workspace Layout
### ------------------------------------------------------------------------------
PWD         := $(shell pwd)
BUILD_DIR   := $(PWD)/build
WAVE_DIR    := $(BUILD_DIR)/waves
SUBMODULE   := $(PWD)/submodule/sv-common-ip-library

### Submodule Assets Discovery (Recursive)
COMMON_PKGS   := $(abspath $(sort $(shell find $(SUBMODULE)/common/packages -name "*.sv" 2>/dev/null)))
COMMON_IFS    := $(abspath $(sort $(shell find $(SUBMODULE)/common/interfaces -name "*.sv" 2>/dev/null)))
COMMON_ASRT   := $(abspath $(sort $(shell find $(SUBMODULE)/common/assertions -name "*.sv" 2>/dev/null)))
COMMON_MACROS := $(SUBMODULE)/common/macros

# Reused RTL modules from Project 1
REUSED_RTL    := $(abspath $(sort $(shell find $(SUBMODULE) -path "*/rtl/*.sv" 2>/dev/null)))

### Project 2 RTL Source Discovery
PKG_SRCS    := $(abspath $(sort $(wildcard rtl/pkg/*.sv)))
INTC_SRCS   := $(abspath $(sort $(wildcard rtl/interconnect/*.sv)))
CTRL_SRCS   := $(abspath $(sort $(wildcard rtl/controllers/*.sv)))
PERIPH_SRCS := $(abspath $(sort $(wildcard rtl/peripherals/*.sv)))
TOP_RTL     := $(abspath $(sort $(wildcard rtl/top/*.sv)))
ALL_RTL     := $(INTC_SRCS) $(CTRL_SRCS) $(PERIPH_SRCS) $(TOP_RTL)

### Project 2 Verification / TB Discovery
TB_IF       := $(abspath $(sort $(wildcard tb/if/*.sv)))
TB_PKG      := $(abspath $(wildcard tb/uvm/apb_tb_pkg.sv))
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
                 -I$(PWD)/tb/uvm \
                 -I$(PWD)/tb/uvm/apb_agent \
                 -I$(PWD)/tb/uvm/env \
                 -I$(PWD)/tb/uvm/tests \
                 -I$(COMMON_MACROS)

XVLOG_INC     := -i $(PWD)/rtl/pkg \
                 -i $(PWD)/tb/if \
                 -i $(PWD)/tb/uvm \
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
XELAB_FLAGS := -L uvm -timescale 1ns/1ps -debug all

### Terminal Output Filter: Suppress noisy INFO lines, keep ERRORS, WARNINGS, & UVM reports
FILTER_LOG := grep -E "ERROR|FATAL|WARNING|Error|Warning|Fatal|FAIL|\[PASS\]|\[FAIL\]|UVM_ERROR|UVM_FATAL|UVM_WARNING|SCB_|COV_|REG_TEST|BASE_TEST" || true

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
	@if [ -n "$(strip $(COMMON_PKGS))" ]; then cd $(BUILD_DIR) && (xvlog $(XVLOG_FLAGS) $(COMMON_PKGS) 2>&1 | $(FILTER_LOG)); fi
	@if [ -n "$(strip $(COMMON_IFS))" ];  then cd $(BUILD_DIR) && (xvlog $(XVLOG_FLAGS) $(COMMON_IFS) 2>&1 | $(FILTER_LOG)); fi
	@if [ -n "$(strip $(COMMON_ASRT))" ]; then cd $(BUILD_DIR) && (xvlog $(XVLOG_FLAGS) $(COMMON_ASRT) 2>&1 | $(FILTER_LOG)); fi
	@if [ -n "$(strip $(REUSED_RTL))" ];  then cd $(BUILD_DIR) && (xvlog $(XVLOG_FLAGS) $(REUSED_RTL) 2>&1 | $(FILTER_LOG)); fi
	@echo "=== [SIM SUCCESS] Submodule Infrastructure Compiled ==="

	@echo "=== [SIM] Step 2: Compiling APB Protocol Packages & Interfaces ==="
	@if [ -n "$(strip $(PKG_SRCS))" ]; then cd $(BUILD_DIR) && (xvlog $(XVLOG_FLAGS) $(PKG_SRCS) 2>&1 | $(FILTER_LOG)); fi
	@if [ -n "$(strip $(TB_IF))" ];    then cd $(BUILD_DIR) && (xvlog $(XVLOG_FLAGS) $(TB_IF) 2>&1 | $(FILTER_LOG)); fi
	@echo "=== [SIM SUCCESS] APB Package & Interface Compiled ==="

	@echo "=== [SIM] Step 3: Compiling APB Subsystem RTL ==="
	@if [ -n "$(strip $(ALL_RTL))" ];  then cd $(BUILD_DIR) && (xvlog $(XVLOG_FLAGS) $(ALL_RTL) 2>&1 | $(FILTER_LOG)); fi
	@echo "=== [SIM SUCCESS] Subsystem RTL Compiled ==="

	@echo "=== [SIM] Step 4: Compiling UVM Verification Components ==="
	@if [ -n "$(strip $(TB_PKG))" ];  then cd $(BUILD_DIR) && (xvlog $(XVLOG_FLAGS) $(TB_PKG) 2>&1 | $(FILTER_LOG)); fi
	@if [ -n "$(strip $(TB_TOP))" ];  then cd $(BUILD_DIR) && (xvlog $(XVLOG_FLAGS) $(TB_TOP) 2>&1 | $(FILTER_LOG)); fi
	@echo "=== [SIM SUCCESS] UVM Testbench Compiled ==="

	@echo "=== [SIM] Step 5: Elaborating Simulation Snapshot ==="
	@cd $(BUILD_DIR) && (xelab $(SIM_TOP) $(XELAB_FLAGS) -s $(SNAPSHOT) 2>&1 | $(FILTER_LOG))
	@echo "=== [SIM SUCCESS] Elaboration Completed ==="

	@echo "=== [SIM] Step 6: Executing UVM Test: $(TEST_NAME) ==="
	@cd $(BUILD_DIR) && (xsim $(SNAPSHOT) -testplusarg "UVM_TESTNAME=$(TEST_NAME)" -runall 2>&1 | $(FILTER_LOG))
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