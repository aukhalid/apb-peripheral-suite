// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_gpio.sv
// MODULE      : apb_gpio
// DESCRIPTION : Parameterized APB General Purpose I/O (GPIO) Controller.
//               - Configurable pin width.
//               - Direction mask, data out, and synchronized pin inputs.
//               - Per-pin edge detection with Write-1-to-Clear interrupt status.
// ==============================================================================

module apb_gpio
  import apb_pkg::*;
#(
    parameter int unsigned AddrWidth = ApbAddrWidth,
    parameter int unsigned DataWidth = ApbDataWidth,
    parameter int unsigned GpioWidth = 32
) (
    input wire logic pclk_i,
    input wire logic presetn_i,

    // APB Slave Interface
    input wire logic [AddrWidth-1:0] paddr_i,
    input wire logic                 psel_i,
    input wire logic                 penable_i,
    input wire logic                 pwrite_i,
    input wire logic [DataWidth-1:0] pwdata_i,

    output logic [DataWidth-1:0] prdata_o,
    output logic                 pready_o,
    output logic                 pslverr_o,

    // External GPIO Pins Interface
    input  wire logic [GpioWidth-1:0] gpio_pin_i,
    output logic      [GpioWidth-1:0] gpio_pin_o,
    output logic      [GpioWidth-1:0] gpio_dir_o,  // 1: Output, 0: Input

    // Subsystem Level Interrupt Line
    output logic irq_o
);

  // ----------------------------------------------------------------------------
  // Register Address Offsets
  // ----------------------------------------------------------------------------
  localparam logic [11:0] RegDataIn = 12'h000;
  localparam logic [11:0] RegDataOut = 12'h004;
  localparam logic [11:0] RegDir = 12'h008;
  localparam logic [11:0] RegIntEn = 12'h00C;
  localparam logic [11:0] RegIntStatus = 12'h010;

  // ----------------------------------------------------------------------------
  // Register Storage
  // ----------------------------------------------------------------------------
  logic [GpioWidth-1:0] data_out_q;
  logic [GpioWidth-1:0] dir_q;
  logic [GpioWidth-1:0] int_en_q;
  logic [GpioWidth-1:0] int_status_q;

  // Synchronization & Edge Detection Registers
  logic [GpioWidth-1:0] pin_sync_stage1;
  logic [GpioWidth-1:0] pin_sync_stage2;
  logic [GpioWidth-1:0] pin_sync_stage3;
  logic [GpioWidth-1:0] pin_edge_pulse;

  // ----------------------------------------------------------------------------
  // 1. Two-Stage Input Synchronizer & Edge Detector
  // ----------------------------------------------------------------------------
  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      pin_sync_stage1 <= '0;
      pin_sync_stage2 <= '0;
      pin_sync_stage3 <= '0;
    end else begin
      pin_sync_stage1 <= gpio_pin_i;
      pin_sync_stage2 <= pin_sync_stage1;
      pin_sync_stage3 <= pin_sync_stage2;
    end
  end

  assign pin_edge_pulse = pin_sync_stage2 ^ pin_sync_stage3;  // Any-edge transition

  // ----------------------------------------------------------------------------
  // 2. APB Write Operations & Interrupt Handling
  // ----------------------------------------------------------------------------
  logic write_en = psel_i & penable_i & pwrite_i;
  logic [11:0] reg_offset = paddr_i[11:0];

  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      data_out_q   <= '0;
      dir_q        <= '0;
      int_en_q     <= '0;
      int_status_q <= '0;
    end else begin
      // Hardware interrupt flag set on edge detection (when enabled)
      int_status_q <= int_status_q | (pin_edge_pulse & int_en_q);

      if (write_en) begin
        case (reg_offset)
          RegDataOut:   data_out_q <= pwdata_i[GpioWidth-1:0];
          RegDir:       dir_q <= pwdata_i[GpioWidth-1:0];
          RegIntEn:     int_en_q <= pwdata_i[GpioWidth-1:0];
          RegIntStatus: int_status_q <= int_status_q & ~pwdata_i[GpioWidth-1:0];  // W1C
          default:      ;  // Ignore unmapped register writes
        endcase
      end
    end
  end

  // ----------------------------------------------------------------------------
  // 3. APB Read Multiplexer
  // ----------------------------------------------------------------------------
  always_comb begin
    prdata_o  = '0;
    pslverr_o = 1'b0;

    if (psel_i && !pwrite_i) begin
      case (reg_offset)
        RegDataIn:    prdata_o[GpioWidth-1:0] = pin_sync_stage2;
        RegDataOut:   prdata_o[GpioWidth-1:0] = data_out_q;
        RegDir:       prdata_o[GpioWidth-1:0] = dir_q;
        RegIntEn:     prdata_o[GpioWidth-1:0] = int_en_q;
        RegIntStatus: prdata_o[GpioWidth-1:0] = int_status_q;
        default:      pslverr_o = 1'b1;  // Flag unmapped register access
      endcase
    end
  end

  // ----------------------------------------------------------------------------
  // 4. Output Ports Drive
  // ----------------------------------------------------------------------------
  assign pready_o   = 1'b1;  // Zero-wait-state register access
  assign gpio_pin_o = data_out_q;
  assign gpio_dir_o = dir_q;
  assign irq_o      = |int_status_q;

endmodule : apb_gpio

