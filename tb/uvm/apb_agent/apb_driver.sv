`ifndef APB_DRIVER_SV
`define APB_DRIVER_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
import apb_pkg::*;

class apb_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(apb_driver)

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
    // 1. Initialize all APB lines to deterministic 0 at Time 0
    vif.paddr   <= '0;
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwrite  <= 1'b0;
    vif.pwdata  <= '0;
    vif.pstrb   <= '0;
    vif.pprot   <= '0;

    // 2. Wait until tb_top releases reset
    wait (vif.presetn === 1'b1);
    @(posedge vif.pclk);

    forever begin
      seq_item_port.get_next_item(req);
      drive_transfer(req);
      seq_item_port.item_done();
    end
  endtask : run_phase

  virtual task drive_transfer(apb_seq_item item);
    // 1. SETUP PHASE
    @(posedge vif.pclk);
    vif.paddr   <= item.paddr;
    vif.pwrite  <= item.pwrite;
    vif.pwdata  <= (item.pwrite) ? item.pwdata : '0;
    vif.pstrb   <= item.pstrb;
    vif.pprot   <= item.pprot;
    vif.psel    <= 1'b1;
    vif.penable <= 1'b0;

    // 2. ACCESS PHASE
    @(posedge vif.pclk);
    vif.penable <= 1'b1;

    // Wait for slave to respond
    @(posedge vif.pclk);
    while (vif.pready !== 1'b1) begin
      @(posedge vif.pclk);
    end

    // Capture response on the completing edge
    if (!item.pwrite) begin
      item.prdata = vif.prdata;
    end
    item.pslverr = vif.pslverr;

    // 3. IDLE PHASE: Return strobe lines strictly to 0
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwrite  <= 1'b0;
  endtask : drive_transfer

endclass : apb_driver

`endif  // APB_DRIVER_SV
