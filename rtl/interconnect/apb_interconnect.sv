// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_interconnect.sv
// MODULE      : apb_interconnect
// DESCRIPTION : Master 1-to-N APB Central Interconnect & Address Decoder.
//               - Decodes base addresses using per-peripheral 4KB address slots.
//               - Routes Master setup and access phase transfers to targeted slaves.
//               - Muxes read data and ready/slverr responses back to the master.
//               - Generates PSLVERR and DEAD_C0DE on unmapped address access.
// ==============================================================================

module apb_interconnect
  import apb_pkg::*;
#(
    parameter int unsigned AddrWidth = ApbAddrWidth,
    parameter int unsigned DataWidth = ApbDataWidth,
    parameter int unsigned StrbWidth = ApbStrbWidth,
    parameter int unsigned ProtWidth = ApbProtWidth,
    parameter int unsigned NumSlaves = NumPeripherals
) (
    input wire logic pclk_i,
    input wire logic presetn_i,

    // --------------------------------------------------------------------------
    // APB Host Master Port
    // --------------------------------------------------------------------------
    input wire logic [AddrWidth-1:0] m_paddr_i,
    input wire logic                 m_psel_i,
    input wire logic                 m_penable_i,
    input wire logic                 m_pwrite_i,
    input wire logic [DataWidth-1:0] m_pwdata_i,
    input wire logic [StrbWidth-1:0] m_pstrb_i,
    input wire logic [ProtWidth-1:0] m_pprot_i,

    output logic [DataWidth-1:0] m_prdata_o,
    output logic                 m_pready_o,
    output logic                 m_pslverr_o,

    // --------------------------------------------------------------------------
    // Downstream Slave Interfaces (1-to-N)
    // --------------------------------------------------------------------------
    output logic [NumSlaves-1:0] s_psel_o,
    output logic                 s_penable_o,
    output logic                 s_pwrite_o,
    output logic [AddrWidth-1:0] s_paddr_o,
    output logic [DataWidth-1:0] s_pwdata_o,
    output logic [StrbWidth-1:0] s_pstrb_o,
    output logic [ProtWidth-1:0] s_pprot_o,

    input wire logic [NumSlaves-1:0][DataWidth-1:0] s_prdata_i,
    input wire logic [NumSlaves-1:0]                s_pready_i,
    input wire logic [NumSlaves-1:0]                s_pslverr_i
);

  // ----------------------------------------------------------------------------
  // 1. Address Decoding Logic
  // ----------------------------------------------------------------------------
  int unsigned target_slave;
  logic        addr_unmapped;

  always_comb begin
    target_slave  = 0;
    addr_unmapped = 1'b0;

    // Check 64KB base region (0x4000_xxxx)
    if (m_paddr_i[31:16] == 16'h4000) begin
      case (m_paddr_i[15:12])
        4'h0: target_slave = 0;  // UART
        4'h1: target_slave = 1;  // SPI
        4'h2: target_slave = 2;  // I2C
        4'h3: target_slave = 3;  // GPIO
        4'h4: target_slave = 4;  // Timer
        4'h5: target_slave = 5;  // PWM
        4'h6: target_slave = 6;  // WDT
        4'h7: target_slave = 7;  // Memory Controller
        4'h8: target_slave = 8;  // Interrupt Controller
        default: begin
          target_slave  = 0;
          addr_unmapped = 1'b1;
        end
      endcase
    end else begin
      target_slave  = 0;
      addr_unmapped = 1'b1;
    end
  end

  // ----------------------------------------------------------------------------
  // 2. Downstream Master Bus Broadcasting
  // ----------------------------------------------------------------------------
  // Ensure control lines strictly drop to 0 during idle or reset to avoid X/Z propagation
  assign s_penable_o = (presetn_i && m_psel_i) ? m_penable_i : 1'b0;
  assign s_pwrite_o  = (presetn_i && m_psel_i) ? m_pwrite_i : 1'b0;
  assign s_paddr_o   = m_paddr_i;
  assign s_pwdata_o  = (m_pwrite_i) ? m_pwdata_i : '0;
  assign s_pstrb_o   = m_pstrb_i;
  assign s_pprot_o   = m_pprot_i;

  // One-hot slave select strobe
  always_comb begin
    s_psel_o = '0;
    if (presetn_i && m_psel_i && !addr_unmapped) begin
      if (target_slave < NumSlaves) begin
        s_psel_o[target_slave] = 1'b1;
      end
    end
  end

  // ----------------------------------------------------------------------------
  // 3. Upstream Response Multiplexing & Error Handling
  // ----------------------------------------------------------------------------
  always_comb begin
    m_prdata_o  = '0;
    m_pready_o  = 1'b1;
    m_pslverr_o = 1'b0;

    if (m_psel_i) begin
      if (addr_unmapped) begin
        m_prdata_o  = ApbErrRespData;
        m_pready_o  = 1'b1;
        m_pslverr_o = 1'b1;
      end else if (target_slave < NumSlaves) begin
        m_prdata_o  = s_prdata_i[target_slave];
        m_pready_o  = s_pready_i[target_slave];
        m_pslverr_o = s_pslverr_i[target_slave];
      end
    end
  end

endmodule : apb_interconnect
