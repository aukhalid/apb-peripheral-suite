// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_reg_test.sv
// DESCRIPTION : Comprehensive APB Subsystem Register Test.
//               - Inherits from base_test.
//               - Launches apb_subsystem_reg_seq on the active APB Sequencer.
//               - Verifies register read/write integrity across all peripheral blocks.
// ==============================================================================

`ifndef APB_REG_TEST_SV
`define APB_REG_TEST_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "base_test.sv"

class apb_reg_test extends base_test;
  `uvm_component_utils(apb_reg_test)

  function new(string name = "apb_reg_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  // ----------------------------------------------------------------------------
  // Run Phase: Launch register test sequence
  // ----------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    apb_subsystem_reg_seq reg_seq;
    reg_seq = apb_subsystem_reg_seq::type_id::create("reg_seq");

    phase.raise_objection(this, "Starting apb_reg_test");
    `uvm_info("REG_TEST", "Executing full APB Subsystem Register Verification Sequence...", UVM_LOW)

    // Start sequence on the APB agent's sequencer
    reg_seq.start(env.agent.sequencer);

    #200ns; // Drainage time for monitors and scoreboards to complete sampling
    phase.drop_objection(this, "Completed apb_reg_test");
  endtask : run_phase

endclass : apb_reg_test

`endif // APB_REG_TEST_SV
