// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_decoder.sv
// MODULE      : apb_decoder
// DESCRIPTION : Parameterized Address Decoder for the APB Interconnect.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype none

module apb_decoder
  import apb_pkg::*;
#(
    parameter int unsigned AddrWidth = ApbAddrWidth,
    parameter int unsigned NumSlaves = NumPeripherals
) (
    input wire logic [AddrWidth-1:0] paddr_i,
    input wire logic                 psel_i,

    output logic [NumSlaves-1:0] psel_o,
    output logic                 decode_err_o
);

  logic [NumSlaves-1:0][AddrWidth-1:0] slave_base_addr;

  assign slave_base_addr[SlvUart]    = UartBaseAddr;
  assign slave_base_addr[SlvSpi]     = SpiBaseAddr;
  assign slave_base_addr[SlvI2c]     = I2cBaseAddr;
  assign slave_base_addr[SlvGpio]    = GpioBaseAddr;
  assign slave_base_addr[SlvTimer]   = TimerBaseAddr;
  assign slave_base_addr[SlvPwm]     = PwmBaseAddr;
  assign slave_base_addr[SlvWdt]     = WdtBaseAddr;
  assign slave_base_addr[SlvMemCtrl] = MemCtrlBaseAddr;
  assign slave_base_addr[SlvIctr]    = IctrBaseAddr;

  always_comb begin
    psel_o       = '0;
    decode_err_o = 1'b0;

    if (psel_i) begin
      decode_err_o = 1'b1;

      for (int unsigned i = 0; i < NumSlaves; i++) begin
        if ((paddr_i & PeriphAddrMask) == slave_base_addr[i]) begin
          psel_o[i]    = 1'b1;
          decode_err_o = 1'b0;
          break;
        end
      end
    end
  end

endmodule : apb_decoder

`default_nettype wire
