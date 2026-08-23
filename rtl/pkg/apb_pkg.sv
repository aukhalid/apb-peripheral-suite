// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_pkg.sv
// DESCRIPTION : Global APB protocol definitions, address map offsets, slave
//               indexes, and helper functions for the peripheral subsystem.
// ==============================================================================

package apb_pkg;

  // ----------------------------------------------------------------------------
  // 1. Bus Width Defaults
  // ----------------------------------------------------------------------------
  localparam int ApbAddrWidth = 32;
  localparam int ApbDataWidth = 32;
  localparam int ApbStrbWidth = ApbDataWidth / 8;
  localparam int ApbProtWidth = 3;

  // ----------------------------------------------------------------------------
  // 2. Peripheral Index IDs
  // ----------------------------------------------------------------------------
  localparam int NumPeripherals = 9;

  typedef enum int {
    SlvUart    = 0,
    SlvSpi     = 1,
    SlvI2c     = 2,
    SlvGpio    = 3,
    SlvTimer   = 4,
    SlvPwm     = 5,
    SlvWdt     = 6,
    SlvMemCtrl = 7,
    SlvIctr    = 8
  } apb_slave_id_e;

  // ----------------------------------------------------------------------------
  // 3. Subsystem Memory Address Map (Base Addresses & Windows)
  // ----------------------------------------------------------------------------
  localparam logic [ApbAddrWidth-1:0] UartBaseAddr = 32'h4000_0000;
  localparam logic [ApbAddrWidth-1:0] SpiBaseAddr = 32'h4000_1000;
  localparam logic [ApbAddrWidth-1:0] I2cBaseAddr = 32'h4000_2000;
  localparam logic [ApbAddrWidth-1:0] GpioBaseAddr = 32'h4000_3000;
  localparam logic [ApbAddrWidth-1:0] TimerBaseAddr = 32'h4000_4000;
  localparam logic [ApbAddrWidth-1:0] PwmBaseAddr = 32'h4000_5000;
  localparam logic [ApbAddrWidth-1:0] WdtBaseAddr = 32'h4000_6000;
  localparam logic [ApbAddrWidth-1:0] MemCtrlBaseAddr = 32'h4000_7000;
  localparam logic [ApbAddrWidth-1:0] IctrBaseAddr = 32'h4000_8000;

  // Each peripheral window is allocated 4 KB (0x1000 bytes)
  localparam logic [ApbAddrWidth-1:0] PeriphWindowSize = 32'h0000_1000;
  localparam logic [ApbAddrWidth-1:0] PeriphAddrMask = ~(PeriphWindowSize - 1'b1);  // 32'hFFFF_F000

  // ----------------------------------------------------------------------------
  // 4. Default Error Fallback Values
  // ----------------------------------------------------------------------------
  localparam logic [ApbDataWidth-1:0] ApbErrRespData = 32'hDEAD_C0DE;

  // ----------------------------------------------------------------------------
  // 5. APB Protocol Transfer States
  // ----------------------------------------------------------------------------
  typedef enum logic [1:0] {
    ApbIdle   = 2'b00,
    ApbSetup  = 2'b01,
    ApbAccess = 2'b10
  } apb_state_e;

endpackage : apb_pkg
