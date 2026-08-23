// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_timer.sv
// MODULE      : apb_timer
// DESCRIPTION : Parameterized 32-bit APB Timer Peripheral.
//               - Programmable prescaler for tick generation.
//               - Periodic auto-reload or one-shot countdown mode.
//               - Interrupt pulse and status generation on terminal count.
// ==============================================================================


module apb_timer
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

    // Interrupt Output Line
    output logic irq_o
);

  // ----------------------------------------------------------------------------
  // Register Address Offsets
  // ----------------------------------------------------------------------------
  localparam logic [11:0] RegCtrl = 12'h000;
  localparam logic [11:0] RegLoad = 12'h004;
  localparam logic [11:0] RegValue = 12'h008;
  localparam logic [11:0] RegPrescale = 12'h00C;
  localparam logic [11:0] RegIntStatus = 12'h010;

  // ----------------------------------------------------------------------------
  // Registers & Internal State
  // ----------------------------------------------------------------------------
  // Control bits: [0] = Enable, [1] = AutoReload, [2] = IntEn
  logic [ 2:0] ctrl_q;
  logic [31:0] load_q;
  logic [31:0] value_q;
  logic [31:0] prescale_q;
  logic [31:0] prescale_cnt_q;
  logic        int_status_q;

  logic        timer_en = ctrl_q[0];
  logic        auto_reload = ctrl_q[1];
  logic        int_en = ctrl_q[2];
  logic        write_en = psel_i & penable_i & pwrite_i;
  logic [11:0] reg_offset = paddr_i[11:0];

  // ----------------------------------------------------------------------------
  // 1. Prescaler & Timer Core Countdown Logic
  // ----------------------------------------------------------------------------
  logic        prescale_tick = (prescale_cnt_q == '0);

  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      ctrl_q         <= '0;
      load_q         <= '0;
      value_q        <= '0;
      prescale_q     <= '0;
      prescale_cnt_q <= '0;
      int_status_q   <= 1'b0;
    end else begin
      // Default: decrement prescaler counter if timer is active
      if (timer_en) begin
        if (prescale_cnt_q == '0) begin
          prescale_cnt_q <= prescale_q;

          // Decrement timer value
          if (value_q == 32'd0) begin
            int_status_q <= 1'b1;  // Trigger terminal count interrupt
            if (auto_reload) begin
              value_q <= load_q;
            end else begin
              ctrl_q[0] <= 1'b0;  // Stop timer in one-shot mode
            end
          end else begin
            value_q <= value_q - 1'b1;
          end
        end else begin
          prescale_cnt_q <= prescale_cnt_q - 1'b1;
        end
      end

      // APB Register Writes
      if (write_en) begin
        case (reg_offset)
          RegCtrl: begin
            ctrl_q <= pwdata_i[2:0];
            // If newly enabled, reload prescaler counter
            if (pwdata_i[0] && !timer_en) begin
              prescale_cnt_q <= prescale_q;
            end
          end
          RegLoad: begin
            load_q  <= pwdata_i;
            value_q <= pwdata_i;  // Immediate reload on load write
          end
          RegPrescale: begin
            prescale_q     <= pwdata_i;
            prescale_cnt_q <= pwdata_i;
          end
          RegIntStatus: begin
            if (pwdata_i[0]) begin
              int_status_q <= 1'b0;  // W1C
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
        RegCtrl:      prdata_o[2:0] = ctrl_q;
        RegLoad:      prdata_o = load_q;
        RegValue:     prdata_o = value_q;
        RegPrescale:  prdata_o = prescale_q;
        RegIntStatus: prdata_o[0] = int_status_q;
        default:      pslverr_o = 1'b1;
      endcase
    end
  end

  // ----------------------------------------------------------------------------
  // 3. Output Handshakes & Interrupt Drive
  // ----------------------------------------------------------------------------
  assign pready_o = 1'b1;
  assign irq_o    = int_status_q & int_en;

endmodule : apb_timer
