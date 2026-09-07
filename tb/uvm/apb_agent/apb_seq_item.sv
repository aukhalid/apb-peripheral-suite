// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_seq_item.sv
// DESCRIPTION : UVM Sequence Item representing an APB3/APB4 Bus Transaction.
// ==============================================================================

`ifndef APB_SEQ_ITEM_SV
`define APB_SEQ_ITEM_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
import apb_pkg::*;

class apb_seq_item extends uvm_sequence_item;

  // ----------------------------------------------------------------------------
  // Transaction Fields
  // ----------------------------------------------------------------------------
  rand logic [ApbAddrWidth-1:0] paddr;
  rand logic                    pwrite; // 1 = Write, 0 = Read
  rand logic [ApbDataWidth-1:0] pwdata;
  rand logic [ApbStrbWidth-1:0] pstrb;
  rand logic [ApbProtWidth-1:0] pprot;

  // Response Fields (Driven by Monitor / Returned by Slave)
  logic [ApbDataWidth-1:0]      prdata;
  logic                         pslverr;

  // ----------------------------------------------------------------------------
  // Constraints
  // ----------------------------------------------------------------------------
  // Default: align addresses to 4-byte boundaries (word-aligned)
  constraint c_addr_align {
    paddr[1:0] == 2'b00;
  }

  // Default: enable all byte lanes during writes
  constraint c_default_strb {
    pstrb == '1;
  }

  // ----------------------------------------------------------------------------
  // UVM Field Automation Macros
  // ----------------------------------------------------------------------------
  `uvm_object_utils_begin(apb_seq_item)
    `uvm_field_int(paddr,   UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(pwrite,  UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(pwdata,  UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(pstrb,   UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(pprot,   UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(prdata,  UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(pslverr, UVM_ALL_ON | UVM_BIN)
  `uvm_object_utils_end

  // ----------------------------------------------------------------------------
  // Constructor
  // ----------------------------------------------------------------------------
  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction : new

endclass : apb_seq_item

`endif // APB_SEQ_ITEM_SV
