// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_coverage.sv
// DESCRIPTION : UVM Subscriber sampling functional coverage on APB transactions.
//               - Peripheral address space hit coverage across all 9 IPs.
//               - Access mode cross coverage (Read vs. Write).
//               - APB4 byte-strobe coverage bins.
// ==============================================================================

`ifndef APB_COVERAGE_SV
`define APB_COVERAGE_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
import apb_pkg::*;

class apb_coverage extends uvm_subscriber #(apb_seq_item);
  `uvm_component_utils(apb_coverage)

  // Transaction handle sampled by the covergroup
  apb_seq_item trans_sampled;

  // ----------------------------------------------------------------------------
  // Functional Coverage Group
  // ----------------------------------------------------------------------------
  covergroup cg_apb_bus;
    option.per_instance = 1;
    option.name = "apb_subsystem_functional_coverage";

    // 1. Peripheral Address Map Space Bins
    cp_peripheral_addr: coverpoint trans_sampled.paddr {
      bins uart_slot     = {[UartBaseAddr    : UartBaseAddr    + PeriphWindowSize - 1]};
      bins spi_slot      = {[SpiBaseAddr     : SpiBaseAddr     + PeriphWindowSize - 1]};
      bins i2c_slot      = {[I2cBaseAddr     : I2cBaseAddr     + PeriphWindowSize - 1]};
      bins gpio_slot     = {[GpioBaseAddr    : GpioBaseAddr    + PeriphWindowSize - 1]};
      bins timer_slot    = {[TimerBaseAddr   : TimerBaseAddr   + PeriphWindowSize - 1]};
      bins pwm_slot      = {[PwmBaseAddr     : PwmBaseAddr     + PeriphWindowSize - 1]};
      bins wdt_slot      = {[WdtBaseAddr     : WdtBaseAddr     + PeriphWindowSize - 1]};
      bins mem_ctrl_slot = {[MemCtrlBaseAddr : MemCtrlBaseAddr + PeriphWindowSize - 1]};
      bins ictr_slot     = {[IctrBaseAddr    : IctrBaseAddr    + PeriphWindowSize - 1]};
      bins unmapped_slot = default;
    }

    // 2. Transfer Direction (Read / Write)
    cp_direction: coverpoint trans_sampled.pwrite {
      bins read  = {1'b0};
      bins write = {1'b1};
    }

    // 3. Byte Enable Strobes
    cp_strb: coverpoint trans_sampled.pstrb {
      bins full_word  = {4'b1111};
      bins lower_half = {4'b0011};
      bins upper_half = {4'b1100};
      bins byte_lane0 = {4'b0001};
      bins byte_lane1 = {4'b0010};
      bins byte_lane2 = {4'b0100};
      bins byte_lane3 = {4'b1000};
    }

    // 4. Slave Error Handshake Indicator
    cp_error: coverpoint trans_sampled.pslverr {
      bins normal_ok  = {1'b0};
      bins slv_err    = {1'b1};
    }

    // 5. Cross Coverage: Ensure both Read and Write happen to all 9 peripheral slots
    cross_addr_x_dir: cross cp_peripheral_addr, cp_direction;

    // 6. Cross Coverage: Verify error assertion on unmapped accesses
    cross_unmapped_x_error: cross cp_peripheral_addr, cp_error {
      bins unmapped_error_hit = binsof(cp_peripheral_addr.unmapped_slot) && binsof(cp_error.slv_err);
    }
  endgroup : cg_apb_bus

  // ----------------------------------------------------------------------------
  // Constructor
  // ----------------------------------------------------------------------------
  function new(string name = "apb_coverage", uvm_component parent = null);
    super.new(name, parent);
    cg_apb_bus = new();
  endfunction : new

  // ----------------------------------------------------------------------------
  // Subscriber Sample Implementation
  // ----------------------------------------------------------------------------
  virtual function void write(apb_seq_item t);
    trans_sampled = t;
    cg_apb_bus.sample();
  endfunction : write

  // ----------------------------------------------------------------------------
  // Report Phase
  // ----------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV_REPORT", $sformatf("Overall APB Bus Functional Coverage = %0.2f%%",
              cg_apb_bus.get_inst_coverage()), UVM_LOW)
  endfunction : report_phase

endclass : apb_coverage

`endif // APB_COVERAGE_SV
