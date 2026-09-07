// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_mem_ctrl.sv
// MODULE      : apb_mem_ctrl
// DESCRIPTION : Parameterized APB On-Chip SRAM Memory Controller.
//               - Reuses single_port_ram from sv-common-ip-library.
//               - Converts APB read/write accesses to synchronous RAM strobes.
//               - Configurable address depth and zero-wait-state transfers.
// ==============================================================================

module apb_mem_ctrl
  import apb_pkg::*;
#(
    parameter int unsigned AddrWidth = ApbAddrWidth,
    parameter int unsigned DataWidth = ApbDataWidth,
    parameter int unsigned MemDepth  = 256
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
    output logic                 pslverr_o
);

  localparam int RamAddrWidth = $clog2(MemDepth);

  // ----------------------------------------------------------------------------
  // Internal RAM Control Signals
  // ----------------------------------------------------------------------------
  logic ram_wr_en = (presetn_i && psel_i === 1'b1 && penable_i === 1'b1 && pwrite_i === 1'b1);
  logic [RamAddrWidth-1:0] ram_addr = (psel_i) ? paddr_i[RamAddrWidth+1:2] : '0;
  logic [DataWidth-1:0] ram_rd_data;

  // ----------------------------------------------------------------------------
  // Reused Single-Port RAM Instance (sv-common-ip-library)
  // ----------------------------------------------------------------------------
  single_port_ram #(
      .DATA_WIDTH(DataWidth),
      .ADDR_WIDTH(RamAddrWidth)
  ) u_sram_core (
      .clk_i    (pclk_i),
      .rst_n_i  (presetn_i),
      .wr_en_i  (ram_wr_en),
      .addr_i   (ram_addr),
      .wr_data_i(pwdata_i),
      .rd_data_o(ram_rd_data)
  );

  // ----------------------------------------------------------------------------
  // APB Output Handshakes
  // ----------------------------------------------------------------------------
  assign prdata_o  = ram_rd_data;
  assign pready_o  = 1'b1;
  assign pslverr_o = 1'b0;

endmodule : apb_mem_ctrl
