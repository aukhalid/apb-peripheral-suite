// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_driver.sv
// DESCRIPTION : UVM Driver converting apb_seq_item to APB physical pin toggles.
// ==============================================================================

`ifndef APB_DRIVER_SV
`define APB_DRIVER_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
import apb_pkg::*;

class apb_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(apb_driver)

  // Virtual interface handle
  virtual apb_if vif;

  function new(string name = "apb_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("DRV_NO_VIF", {"Virtual interface must be set for: ", get_full_name(), ".vif"})
    end
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    // Initialize bus pins
    vif.paddr   <= '0;
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwrite  <= 1'b0;
    vif.pwdata  <= '0;
    vif.pstrb   <= '0;
    vif.pprot   <= '0;

    // Wait for reset release
    @(posedge vif.presetn);
    @(posedge vif.pclk);

    forever begin
      seq_item_port.get_next_item(req);
      drive_transfer(req);
      seq_item_port.item_done();
    end
  endtask : run_phase

  // ----------------------------------------------------------------------------
  // APB Protocol Driver Task (Setup Phase -> Access Phase Handshake)
  // ----------------------------------------------------------------------------
  virtual task drive_transfer(apb_seq_item item);
    // 1. SETUP PHASE: Drive address, control lines, and assert PSEL
    @(posedge vif.pclk);
    vif.paddr   <= item.paddr;
    vif.pwrite  <= item.pwrite;
    vif.pwdata  <= item.pwdata;
    vif.pstrb   <= item.pstrb;
    vif.pprot   <= item.pprot;
    vif.psel    <= 1'b1;
    vif.penable <= 1'b0;

    // 2. ACCESS PHASE: Assert PENABLE on the next clock cycle
    @(posedge vif.pclk);
    vif.penable <= 1'b1;

    // Wait for PREADY handshake from slave
    while (!vif.pready) begin
      @(posedge vif.pclk);
    end

    // Capture read payload if read cycle
    if (!item.pwrite) begin
      item.prdata = vif.prdata;
    end
    item.pslverr = vif.pslverr;

    // 3. COMPLETE / RETURN TO IDLE
    @(posedge vif.pclk);
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
  endtask : drive_transfer

endclass : apb_driver

`endif // APB_DRIVER_SV
