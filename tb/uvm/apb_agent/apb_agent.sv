// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_agent.sv
// DESCRIPTION : UVM APB Agent encapsulating Sequencer, Driver, and Monitor.
//               - Supports UVM_ACTIVE (Driver + Sequencer + Monitor)
//               - Supports UVM_PASSIVE (Monitor only)
// ==============================================================================

`ifndef APB_AGENT_SV
`define APB_AGENT_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

// `include "apb_seq_item.sv"
// `include "apb_sequencer.sv"
// `include "apb_driver.sv"
// `include "apb_monitor.sv"

class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  // Subcomponents
  apb_driver    driver;
  apb_sequencer sequencer;
  apb_monitor   monitor;

  // Analysis Port exposed to the Environment / Scoreboard
  uvm_analysis_port #(apb_seq_item) apb_analysis_port;

  // ----------------------------------------------------------------------------
  // Constructor
  // ----------------------------------------------------------------------------
  function new(string name = "apb_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  // ----------------------------------------------------------------------------
  // Build Phase: Factory instantiation of components
  // ----------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Always instantiate the passive monitor
    monitor = apb_monitor::type_id::create("monitor", this);
    apb_analysis_port = new("apb_analysis_port", this);

    // If configured as active, instantiate driver and sequencer
    if (get_is_active() == UVM_ACTIVE) begin
      driver    = apb_driver::type_id::create("driver", this);
      sequencer = apb_sequencer::type_id::create("sequencer", this);
    end
  endfunction : build_phase

  // ----------------------------------------------------------------------------
  // Connect Phase: Hook TLM ports together
  // ----------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Forward transactions observed by monitor to agent's output port
    monitor.item_collected_port.connect(apb_analysis_port);

    // Connect Driver's pull port to Sequencer's export
    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction : connect_phase

endclass : apb_agent

`endif // APB_AGENT_SV
