// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_scoreboard.sv
// DESCRIPTION : UVM Scoreboard with an internal associative shadow-memory model.
//               - Tracks APB bus write transactions and updates golden state.
//               - Validates read responses against expected register/memory data.
//               - Tallies matches, mismatches, and decode errors.
// ==============================================================================

`ifndef APB_SCOREBOARD_SV
`define APB_SCOREBOARD_SV

`include "uvm_macros.svh"
`include "apb_seq_item.sv"
import uvm_pkg::*;
import apb_pkg::*;

class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  // Analysis Export to receive transactions from the APB Monitor
  uvm_analysis_imp #(apb_seq_item, apb_scoreboard) item_collected_export;

  // Golden Reference Model: Associative array representing the 32-bit register space
  protected logic [ApbDataWidth-1:0] shadow_mem [logic [ApbAddrWidth-1:0]];

  // Verification Statistics
  int unsigned total_trans;
  int unsigned write_trans;
  int unsigned read_trans;
  int unsigned match_count;
  int unsigned mismatch_count;
  int unsigned error_resp_count;

  // ----------------------------------------------------------------------------
  // Constructor
  // ----------------------------------------------------------------------------
  function new(string name = "apb_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    item_collected_export = new("item_collected_export", this);
  endfunction : new

  // ----------------------------------------------------------------------------
  // Build Phase
  // ----------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    total_trans       = 0;
    write_trans       = 0;
    read_trans        = 0;
    match_count       = 0;
    mismatch_count    = 0;
    error_resp_count  = 0;
  endfunction : build_phase

  // ----------------------------------------------------------------------------
  // Analysis Port Write Implementation
  // ----------------------------------------------------------------------------
  virtual function void write(apb_seq_item item);
    total_trans++;

    // Check for PSLVERR response on unmapped access
    if (item.pslverr) begin
      error_resp_count++;
      `uvm_info("SCB_SLVERR", $sformatf("Observed PSLVERR response at PADDR = 0x%08h", item.paddr), UVM_HIGH)
      return;
    end

    // Process Valid APB Writes
    if (item.pwrite) begin
      write_trans++;
      // Handle byte strobes if APB4 strobe is enabled
      if (item.pstrb == '1) begin
        shadow_mem[item.paddr] = item.pwdata;
      end else begin
        logic [ApbDataWidth-1:0] prev_data = shadow_mem.exists(item.paddr) ? shadow_mem[item.paddr] : '0;
        for (int i = 0; i < ApbStrbWidth; i++) begin
          if (item.pstrb[i]) begin
            prev_data[i*8 +: 8] = item.pwdata[i*8 +: 8];
          end
        end
        shadow_mem[item.paddr] = prev_data;
      end

      `uvm_info("SCB_WRITE", $sformatf("Shadow RAM updated: ADDR=0x%08h DATA=0x%08h (STRB=0x%01h)",
                item.paddr, shadow_mem[item.paddr], item.pstrb), UVM_HIGH)
    end
    // Process Valid APB Reads
    else begin
      read_trans++;
      if (shadow_mem.exists(item.paddr)) begin
        logic [ApbDataWidth-1:0] expected_data = shadow_mem[item.paddr];

        // Mask comparison if register has read-side dynamics or pure RAM storage
        if (item.prdata === expected_data) begin
          match_count++;
          `uvm_info("SCB_MATCH", $sformatf("[PASS] ADDR: 0x%08h | DATA: 0x%08h", item.paddr, item.prdata), UVM_HIGH)
        end else begin
          mismatch_count++;
          `uvm_error("SCB_MISMATCH", $sformatf("[FAIL] ADDR: 0x%08h | Expected: 0x%08h | Actual: 0x%08h",
                     item.paddr, expected_data, item.prdata))
        end
      end else begin
        // Read without prior write (initial state check)
        `uvm_info("SCB_UNINIT_READ", $sformatf("Read from uninitialized address 0x%08h -> PRDATA = 0x%08h",
                  item.paddr, item.prdata), UVM_MEDIUM)
      end
    end
  endfunction : write

  // ----------------------------------------------------------------------------
  // Report Phase: Print Verification Summary
  // ----------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB_SUMMARY", "--------------------------------------------------------", UVM_LOW)
    `uvm_info("SCB_SUMMARY", "             APB SCOREBOARD VERIFICATION REPORT         ", UVM_LOW)
    `uvm_info("SCB_SUMMARY", "--------------------------------------------------------", UVM_LOW)
    `uvm_info("SCB_SUMMARY", $sformatf(" Total Processed Transfers : %0d", total_trans), UVM_LOW)
    `uvm_info("SCB_SUMMARY", $sformatf(" Total Write Transfers     : %0d", write_trans), UVM_LOW)
    `uvm_info("SCB_SUMMARY", $sformatf(" Total Read Transfers      : %0d", read_trans), UVM_LOW)
    `uvm_info("SCB_SUMMARY", $sformatf(" PSLVERR Error Responses   : %0d", error_resp_count), UVM_LOW)
    `uvm_info("SCB_SUMMARY", $sformatf(" Data Matches Verified     : %0d", match_count), UVM_LOW)
    `uvm_info("SCB_SUMMARY", $sformatf(" Data Mismatches Detected  : %0d", mismatch_count), UVM_LOW)
    `uvm_info("SCB_SUMMARY", "--------------------------------------------------------", UVM_LOW)

    if (mismatch_count == 0) begin
      `uvm_info("SCB_RESULT", "=== [SCOREBOARD STATUS: PASSED] ZERO MISMATCHES ===", UVM_LOW)
    end else begin
      `uvm_fatal("SCB_RESULT", $sformatf("=== [SCOREBOARD STATUS: FAILED] %0d MISMATCHES FOUND ===", mismatch_count))
    end
  endfunction : report_phase

endclass : apb_scoreboard

`endif // APB_SCOREBOARD_SV
