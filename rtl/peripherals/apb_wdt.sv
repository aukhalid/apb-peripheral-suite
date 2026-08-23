// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_wdt.sv
// MODULE      : apb_wdt
// DESCRIPTION : Parameterized APB Watchdog Recovery Timer (WDT).
//               - Countdown timer with programmable reload interval.
//               - Secure "kick" service sequence (0xA5A5) prevents runaway resets.
//               - Generates interrupt alert and system reset pulse upon expiry.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype none

module apb_wdt
  import apb_pkg::*;
#(
    parameter int unsigned AddrWidth = ApbAddrWidth,
    parameter int unsigned DataWidth = ApbDataWidth
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

    // System Recovery Reset & Interrupt Lines
    output logic wdt_rst_o,
    output logic irq_o
);

  // ----------------------------------------------------------------------------
  // Register Offsets & Magic Service Key
  // ----------------------------------------------------------------------------
  localparam logic [11:0] RegCtrl = 12'h000;
  localparam logic [11:0] RegReload = 12'h004;
  localparam logic [11:0] RegValue = 12'h008;
  localparam logic [11:0] RegKick = 12'h00C;
  localparam logic [11:0] RegStatus = 12'h010;

  localparam logic [15:0] WdtKickKey = 16'hA5A5;

  // ----------------------------------------------------------------------------
  // Registers & Internal State
  // ----------------------------------------------------------------------------
  logic [ 2:0] ctrl_q;  // [0] enable, [1] rst_action_en, [2] int_en
  logic [31:0] reload_q;
  logic [31:0] value_q;
  logic        status_timeout_q;
  logic        rst_pulse_q;

  logic        wdt_en = ctrl_q[0];
  logic        rst_act_en = ctrl_q[1];
  logic        int_en = ctrl_q[2];

  logic        write_en = psel_i & penable_i & pwrite_i;
  logic [11:0] reg_offset = paddr_i[11:0];

  // ----------------------------------------------------------------------------
  // 1. Watchdog Countdown & Reset Strobe Logic
  // ----------------------------------------------------------------------------
  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      ctrl_q           <= '0;
      reload_q         <= 32'h0000_FFFF;
      value_q          <= 32'h0000_FFFF;
      status_timeout_q <= 1'b0;
      rst_pulse_q      <= 1'b0;
    end else begin
      rst_pulse_q <= 1'b0;  // 1-cycle reset pulse

      // Active countdown
      if (wdt_en) begin
        if (value_q == 32'd0) begin
          status_timeout_q <= 1'b1;
          value_q          <= reload_q;
          if (rst_act_en) begin
            rst_pulse_q <= 1'b1;
          end
        end else begin
          value_q <= value_q - 1'b1;
        end
      end

      // APB Register Writes
      if (write_en) begin
        case (reg_offset)
          RegCtrl: begin
            ctrl_q <= pwdata_i[2:0];
          end
          RegReload: begin
            reload_q <= pwdata_i;
          end
          RegKick: begin
            // Service the watchdog if correct key is written
            if (pwdata_i[15:0] == WdtKickKey) begin
              value_q <= reload_q;
            end
          end
          RegStatus: begin
            if (pwdata_i[0]) begin
              status_timeout_q <= 1'b0;  // W1C
            end
          end
          default: ;
        endcase
      end
    end
  end

  // ----------------------------------------------------------------------------
  // 2. APB Read Multiplexer
  // ----------------------------------------------------------------------------
  always_comb begin
    prdata_o  = '0;
    pslverr_o = 1'b0;

    if (psel_i && !pwrite_i) begin
      case (reg_offset)
        RegCtrl:   prdata_o[2:0] = ctrl_q;
        RegReload: prdata_o = reload_q;
        RegValue:  prdata_o = value_q;
        RegStatus: prdata_o[0] = status_timeout_q;
        default:   pslverr_o = 1'b1;
      endcase
    end
  end

  assign pready_o  = 1'b1;
  assign irq_o     = status_timeout_q & int_en;
  assign wdt_rst_o = rst_pulse_q;

endmodule : apb_wdt
