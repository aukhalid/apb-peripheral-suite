// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_env.sv
// DESCRIPTION : Master UVM Environment for the APB Subsystem.
//               - Instantiates the active APB Agent, Scoreboard, and Coverage.
//               - Binds the Agent's analysis port to the Scoreboard and Coverage.
// ==============================================================================

`ifndef APB_ENV_SV
`define APB_ENV_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

// `include "apb_agent.sv"
// `include "apb_scoreboard.sv"
// `include "apb_coverage.sv"

class apb_env extends uvm_env;
  `uvm_component_utils(apb_env)

  // Subcomponents
  apb_agent      agent;
  apb_scoreboard scoreboard;
  apb_coverage   coverage;

  // ----------------------------------------------------------------------------
  // Constructor
  // ----------------------------------------------------------------------------
  function new(string name = "apb_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  // ----------------------------------------------------------------------------
  // Build Phase: Instantiate Agent, Scoreboard, and Coverage Collector
  // ----------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    agent      = apb_agent::type_id::create("agent", this);
    scoreboard = apb_scoreboard::type_id::create("scoreboard", this);
    coverage   = apb_coverage::type_id::create("coverage", this);
  endfunction : build_phase

  // ----------------------------------------------------------------------------
  // Connect Phase: Route Analysis Ports
  // ----------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Broadcast transactions from the Agent's monitor to Scoreboard & Coverage
    agent.apb_analysis_port.connect(scoreboard.item_collected_export);
    agent.apb_analysis_port.connect(coverage.analysis_export);
  endfunction : connect_phase

endclass : apb_env

`endif // APB_ENV_SV
