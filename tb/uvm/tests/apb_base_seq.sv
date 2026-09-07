// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_base_seq.sv
// DESCRIPTION : Reusable UVM Sequence Library for APB Bus Stimulus Generation.
//               - Single register write/read tasks.
//               - Address-sweep sequences across peripheral spaces.
//               - Unmapped address access sequence to test error recovery.
// ==============================================================================

`ifndef APB_BASE_SEQ_SV
`define APB_BASE_SEQ_SV

`include "uvm_macros.svh"
import uvm_pkg::*;
import apb_pkg::*;

// ------------------------------------------------------------------------------
// Base Sequence
// ------------------------------------------------------------------------------
class apb_base_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_base_seq)

  function new(string name = "apb_base_seq");
    super.new(name);
  endfunction : new

  // Helper task: Write a single register via APB
  virtual task write_reg(input logic [ApbAddrWidth-1:0] addr, input logic [ApbDataWidth-1:0] data);
    `uvm_create(req)
    req.paddr  = addr;
    req.pwrite = 1'b1;
    req.pwdata = data;
    req.pstrb  = '1;
    req.pprot  = '0;
    `uvm_send(req)
  endtask : write_reg

  // Helper task: Read a single register via APB
  virtual task read_reg(input logic [ApbAddrWidth-1:0] addr, output logic [ApbDataWidth-1:0] data, output logic err);
    `uvm_create(req)
    req.paddr  = addr;
    req.pwrite = 1'b0;
    req.pwdata = '0;
    req.pstrb  = '1;
    req.pprot  = '0;
    `uvm_send(req)
    data = req.prdata;
    err  = req.pslverr;
  endtask : read_reg

endclass : apb_base_seq

// ------------------------------------------------------------------------------
// Peripheral Subsystem Comprehensive Register Verification Sequence
// ------------------------------------------------------------------------------
class apb_subsystem_reg_seq extends apb_base_seq;
  `uvm_object_utils(apb_subsystem_reg_seq)

  function new(string name = "apb_subsystem_reg_seq");
    super.new(name);
  endfunction : new

  task body();
    logic [ApbDataWidth-1:0] rdata;
    logic                    r_err;

    `uvm_info("SEQ", "=== Phase 1: Verifying APB Memory Controller (RAM) Writes & Reads ===", UVM_LOW)
    for (int i = 0; i < 8; i++) begin
      logic [ApbAddrWidth-1:0] mem_addr = MemCtrlBaseAddr + (i * 4);
      logic [ApbDataWidth-1:0] wr_val   = 32'hA500_0000 | (i * 32'h0001_1111);
      write_reg(mem_addr, wr_val);
      read_reg(mem_addr, rdata, r_err);
    end

    `uvm_info("SEQ", "=== Phase 2: Verifying APB Timer Configuration Registers ===", UVM_LOW)
    // Write Timer Load Value
    write_reg(TimerBaseAddr + 12'h004, 32'h0000_03E8);
    read_reg(TimerBaseAddr + 12'h004, rdata, r_err);
    // Write Timer Prescaler Value
    write_reg(TimerBaseAddr + 12'h00C, 32'h0000_000A);
    read_reg(TimerBaseAddr + 12'h00C, rdata, r_err);

    `uvm_info("SEQ", "=== Phase 3: Verifying APB GPIO Direction & Data Out Registers ===", UVM_LOW)
    write_reg(GpioBaseAddr + 12'h008, 32'hFFFF_0000); // Set upper 16 pins as output
    read_reg(GpioBaseAddr + 12'h008, rdata, r_err);
    write_reg(GpioBaseAddr + 12'h004, 32'h1234_0000); // Drive output data
    read_reg(GpioBaseAddr + 12'h004, rdata, r_err);

    `uvm_info("SEQ", "=== Phase 4: Verifying APB PWM Period & Duty Cycle Registers ===", UVM_LOW)
    write_reg(PwmBaseAddr + 12'h004, 32'h0000_0100); // Period
    read_reg(PwmBaseAddr + 12'h004, rdata, r_err);
    write_reg(PwmBaseAddr + 12'h008, 32'h0000_0080); // 50% Duty
    read_reg(PwmBaseAddr + 12'h008, rdata, r_err);

    `uvm_info("SEQ", "=== Phase 5: Verifying APB Interrupt Controller Mask Registers ===", UVM_LOW)
    write_reg(IctrBaseAddr + 12'h000, 32'h0000_003F); // Enable lower 6 IRQs
    read_reg(IctrBaseAddr + 12'h000, rdata, r_err);

    `uvm_info("SEQ", "=== Phase 6: Testing Decode Error on Unmapped Address ===", UVM_LOW)
    // Access unmapped address window (0x4FFF_0000) to verify PSLVERR generation
    read_reg(32'h4FFF_0000, rdata, r_err);
    if (r_err && rdata === ApbErrRespData) begin
      `uvm_info("SEQ", "[PASS] Unmapped access correctly returned PSLVERR and DEAD_C0DE data payload!", UVM_LOW)
    end else begin
      `uvm_error("SEQ", $sformatf("[FAIL] Expected PSLVERR on unmapped address! r_err=%0b, rdata=0x%08h", r_err, rdata))
    end
  endtask : body

endclass : apb_subsystem_reg_seq

`endif // APB_BASE_SEQ_SV
