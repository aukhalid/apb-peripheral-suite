// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_ictr.sv
// MODULE      : apb_ictr
// DESCRIPTION : Parameterized APB Interrupt Priority Controller.
//               - Reuses fixed_arbiter from sv-common-ip-library.
//               - Aggregates up to 32 peripheral interrupt lines.
//               - Programmable enable, raw status, latched pending, and clear.
//               - Raises single top-level IRQ to the host processor.
// ==============================================================================

module apb_ictr
  import apb_pkg::*;
#(
    parameter int unsigned AddrWidth = ApbAddrWidth,
    parameter int unsigned DataWidth = ApbDataWidth,
    parameter int unsigned NumIrq    = 8
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

    // Peripheral Interrupt Inputs
    input wire logic [NumIrq-1:0] irq_sources_i,

    // Top-Level Subsystem Interrupt Line
    output logic irq_top_o
);

  // ----------------------------------------------------------------------------
  // Register Offsets
  // ----------------------------------------------------------------------------
  localparam logic [11:0] RegEnable = 12'h000;
  localparam logic [11:0] RegRawStatus = 12'h004;
  localparam logic [11:0] RegPending = 12'h008;
  localparam logic [11:0] RegServiced = 12'h00C;
  localparam logic [11:0] RegClear = 12'h010;

  // ----------------------------------------------------------------------------
  // Internal Registers & State
  // ----------------------------------------------------------------------------
  logic [NumIrq-1:0] enable_q;
  logic [NumIrq-1:0] latched_irq_q;

  logic write_en = psel_i & penable_i & pwrite_i;
  logic [11:0] reg_offset = paddr_i[11:0];

  // Latch edge/level interrupts
  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      enable_q      <= '0;
      latched_irq_q <= '0;
    end else begin
      // Latch new incoming IRQ events
      latched_irq_q <= latched_irq_q | irq_sources_i;

      // Register Writes
      if (write_en) begin
        case (reg_offset)
          RegEnable: enable_q <= pwdata_i[NumIrq-1:0];
          RegClear:  latched_irq_q <= latched_irq_q & ~pwdata_i[NumIrq-1:0];  // W1C
          default:   ;
        endcase
      end
    end
  end

  // Active Pending Vector
  logic [NumIrq-1:0] pending_irq = latched_irq_q & enable_q;
  logic [NumIrq-1:0] granted_irq;
  logic              grant_valid;

  // ----------------------------------------------------------------------------
  // Reused Fixed Priority Arbiter (sv-common-ip-library)
  // ----------------------------------------------------------------------------
  fixed_arbiter #(
      .NUM_REQS                     (NumIrq),
      .LOWEST_INDEX_HIGHEST_PRIORITY(1'b1)
  ) u_priority_arbiter (
      .clk_i        (pclk_i),
      .rst_n_i      (presetn_i),
      .req_i        (pending_irq),
      .grant_o      (granted_irq),
      .grant_valid_o(grant_valid)
  );

  // ----------------------------------------------------------------------------
  // APB Read Multiplexer
  // ----------------------------------------------------------------------------
  always_comb begin
    prdata_o  = '0;
    pslverr_o = 1'b0;

    if (psel_i && !pwrite_i) begin
      case (reg_offset)
        RegEnable:    prdata_o[NumIrq-1:0] = enable_q;
        RegRawStatus: prdata_o[NumIrq-1:0] = irq_sources_i;
        RegPending:   prdata_o[NumIrq-1:0] = pending_irq;
        RegServiced:  prdata_o[NumIrq-1:0] = granted_irq;
        default:      pslverr_o = 1'b1;
      endcase
    end
  end

  assign pready_o  = 1'b1;
  assign irq_top_o = grant_valid;

endmodule : apb_ictr
