// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : base_test.sv
// DESCRIPTION : Master UVM Base Test.
//               - Instantiates the apb_env container environment.
//               - Configures global simulation timeout watchdogs.
//               - Prints component hierarchy topology upon elaboration.
// ==============================================================================

`ifndef BASE_TEST_SV
`define BASE_TEST_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

// `include "apb_env.sv"
// `include "apb_base_seq.sv"

class base_test extends uvm_test;
  `uvm_component_utils(base_test)

  // Subsystem Verification Environment Container
  apb_env env;

  // ----------------------------------------------------------------------------
  // Constructor
  // ----------------------------------------------------------------------------
  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  // ----------------------------------------------------------------------------
  // Build Phase
  // ----------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env", this);
  endfunction : build_phase

  // ----------------------------------------------------------------------------
  // End of Elaboration: Print topology structure
  // ----------------------------------------------------------------------------
  // function void end_of_elaboration_phase(uvm_phase phase);
  //   super.end_of_elaboration_phase(phase);
  //   `uvm_info("BASE_TEST", "Printing UVM Component Topology Hierarchy:", UVM_LOW)
  //   uvm_top.print_topology();
  // endfunction : end_of_elaboration_phase

  // ----------------------------------------------------------------------------
  // Run Phase: Base test execution watchdog
  // ----------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting base_test");
    `uvm_info("BASE_TEST", "Base test executing idle sanity sequence...", UVM_LOW)
    #100ns;
    phase.drop_objection(this, "Finished base_test");
  endtask : run_phase

endclass : base_test

`endif // BASE_TEST_SV
