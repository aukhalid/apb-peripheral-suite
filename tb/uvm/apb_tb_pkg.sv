// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_tb_pkg.sv
// DESCRIPTION : Unified UVM Verification Package for APB Subsystem.
//               Compiles all UVM components into a single compilation unit.
// ==============================================================================

`ifndef APB_TB_PKG_SV
`define APB_TB_PKG_SV

package apb_tb_pkg;

  `include "uvm_macros.svh"
  import uvm_pkg::*;
  import apb_pkg::*;

  // 1. Agent components in dependency order
  `include "apb_seq_item.sv"
  `include "apb_sequencer.sv"
  `include "apb_driver.sv"
  `include "apb_monitor.sv"
  `include "apb_agent.sv"

  // 2. Environment components
  `include "apb_scoreboard.sv"
  `include "apb_coverage.sv"
  `include "apb_env.sv"

  // 3. Sequences & Tests
  `include "apb_base_seq.sv"
  `include "base_test.sv"
  `include "apb_reg_test.sv"

endpackage : apb_tb_pkg

`endif  // APB_TB_PKG_SV
