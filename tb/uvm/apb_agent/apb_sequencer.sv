// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_sequencer.sv
// DESCRIPTION : UVM Sequencer routing apb_seq_item packets to the driver.
// ==============================================================================

`ifndef APB_SEQUENCER_SV
`define APB_SEQUENCER_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

typedef uvm_sequencer #(apb_seq_item) apb_sequencer;

`endif // APB_SEQUENCER_SV
