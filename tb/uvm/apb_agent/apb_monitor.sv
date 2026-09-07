// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_monitor.sv
// DESCRIPTION : Passive UVM Monitor sampling APB transactions to analysis port.
// ==============================================================================

`ifndef APB_MONITOR_SV
`define APB_MONITOR_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
import apb_pkg::*;

class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;
  uvm_analysis_port #(apb_seq_item) item_collected_port;

  function new(string name = "apb_monitor", uvm_component parent = null);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("MON_NO_VIF", {"Virtual interface must be set for: ", get_full_name(), ".vif"})
    end
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    apb_seq_item trans;

    forever begin
      @(posedge vif.pclk);
      // Sample transaction during valid access handshake
      if (vif.presetn === 1'b1 && vif.psel === 1'b1 && vif.penable === 1'b1 && vif.pready === 1'b1) begin
        trans = apb_seq_item::type_id::create("trans");
        trans.paddr   = vif.paddr;
        trans.pwrite  = vif.pwrite;
        trans.pwdata  = vif.pwdata;
        trans.pstrb   = vif.pstrb;
        trans.pprot   = vif.pprot;
        trans.prdata  = vif.prdata;
        trans.pslverr = vif.pslverr;

        item_collected_port.write(trans);
      end
    end
  endtask : run_phase

endclass : apb_monitor

`endif // APB_MONITOR_SV
