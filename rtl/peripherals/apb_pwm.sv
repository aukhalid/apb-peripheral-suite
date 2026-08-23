// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_pwm.sv
// MODULE      : apb_pwm
// DESCRIPTION : Parameterized APB Pulse-Width Modulation (PWM) Generator.
//               - Configurable clock prescaler, period, and duty registers.
//               - Optional output polarity invert control.
// ==============================================================================

module apb_pwm
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

    // PWM Waveform Output Pin
    output logic pwm_o
);

  // ----------------------------------------------------------------------------
  // Register Offsets
  // ----------------------------------------------------------------------------
  localparam logic [11:0] RegCtrl = 12'h000;
  localparam logic [11:0] RegPeriod = 12'h004;
  localparam logic [11:0] RegDuty = 12'h008;
  localparam logic [11:0] RegPrescale = 12'h00C;

  // ----------------------------------------------------------------------------
  // Registers & Internal State
  // ----------------------------------------------------------------------------
  logic [ 1:0] ctrl_q;  // [0] enable, [1] invert_polarity
  logic [31:0] period_q;
  logic [31:0] duty_q;
  logic [31:0] prescale_q;

  logic [31:0] prescale_cnt_q;
  logic [31:0] pwm_cnt_q;
  logic        pwm_raw_q;

  logic        pwm_en = ctrl_q[0];
  logic        inv_pol = ctrl_q[1];
  logic        write_en = psel_i & penable_i & pwrite_i;
  logic [11:0] reg_offset = paddr_i[11:0];

  // ----------------------------------------------------------------------------
  // 1. Prescaler & Waveform Generation Engine
  // ----------------------------------------------------------------------------
  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      prescale_cnt_q <= '0;
      pwm_cnt_q      <= '0;
      pwm_raw_q      <= 1'b0;
    end else if (pwm_en) begin
      if (prescale_cnt_q >= prescale_q) begin
        prescale_cnt_q <= '0;

        // Advance Period Counter
        if (pwm_cnt_q >= period_q) begin
          pwm_cnt_q <= '0;
          pwm_raw_q <= (duty_q > 32'd0);
        end else begin
          pwm_cnt_q <= pwm_cnt_q + 1'b1;
          if (pwm_cnt_q < duty_q) begin
            pwm_raw_q <= 1'b1;
          end else begin
            pwm_raw_q <= 1'b0;
          end
        end
      end else begin
        prescale_cnt_q <= prescale_cnt_q + 1'b1;
      end
    end else begin
      prescale_cnt_q <= '0;
      pwm_cnt_q      <= '0;
      pwm_raw_q      <= 1'b0;
    end
  end

  // ----------------------------------------------------------------------------
  // 2. APB Register Read/Write Handling
  // ----------------------------------------------------------------------------
  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      ctrl_q     <= '0;
      period_q   <= 32'h0000_00FF;
      duty_q     <= 32'h0000_007F;
      prescale_q <= '0;
    end else if (write_en) begin
      case (reg_offset)
        RegCtrl:     ctrl_q <= pwdata_i[1:0];
        RegPeriod:   period_q <= pwdata_i;
        RegDuty:     duty_q <= pwdata_i;
        RegPrescale: prescale_q <= pwdata_i;
        default:     ;
      endcase
    end
  end

  always_comb begin
    prdata_o  = '0;
    pslverr_o = 1'b0;

    if (psel_i && !pwrite_i) begin
      case (reg_offset)
        RegCtrl:     prdata_o[1:0] = ctrl_q;
        RegPeriod:   prdata_o = period_q;
        RegDuty:     prdata_o = duty_q;
        RegPrescale: prdata_o = prescale_q;
        default:     pslverr_o = 1'b1;
      endcase
    end
  end

  assign pready_o = 1'b1;
  assign pwm_o    = inv_pol ? ~pwm_raw_q : pwm_raw_q;

endmodule : apb_pwm
