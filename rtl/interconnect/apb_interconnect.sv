// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_interconnect.sv
// MODULE      : apb_interconnect
// DESCRIPTION : Central APB Interconnect Module.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype none

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

    // APB Master Port
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

    // APB Slave Ports
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

  logic                 decode_err;
  logic [NumSlaves-1:0] psel_decoded;

  apb_decoder #(
      .AddrWidth(AddrWidth),
      .NumSlaves(NumSlaves)
  ) u_decoder (
      .paddr_i     (m_paddr_i),
      .psel_i      (m_psel_i),
      .psel_o      (psel_decoded),
      .decode_err_o(decode_err)
  );

  assign s_psel_o    = psel_decoded;
  assign s_penable_o = m_penable_i;
  assign s_pwrite_o  = m_pwrite_i;
  assign s_paddr_o   = m_paddr_i;
  assign s_pwdata_o  = m_pwdata_i;
  assign s_pstrb_o   = m_pstrb_i;
  assign s_pprot_o   = m_pprot_i;

  always_comb begin
    if (decode_err) begin
      m_prdata_o  = ApbErrRespData;
      m_pready_o  = 1'b1;
      m_pslverr_o = 1'b1;
    end else begin
      m_prdata_o  = '0;
      m_pready_o  = 1'b1;
      m_pslverr_o = 1'b0;

      for (int unsigned i = 0; i < NumSlaves; i++) begin
        if (psel_decoded[i]) begin
          m_prdata_o  = s_prdata_i[i];
          m_pready_o  = s_pready_i[i];
          m_pslverr_o = s_pslverr_i[i];
          break;
        end
      end
    end
  end

endmodule : apb_interconnect

`default_nettype wire
