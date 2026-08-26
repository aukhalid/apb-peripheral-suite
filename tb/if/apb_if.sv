// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_if.sv
// MODULE      : apb_if
// DESCRIPTION : SystemVerilog AMBA APB3/APB4 Bus Interface.
//               - Bundles all APB bus control, address, and data signals.
//               - Clocking blocks for synchronous UVM Driver and Monitor.
//               - Embedded SVA protocol assertion monitors.
// ==============================================================================

interface apb_if
  import apb_pkg::*;
#(
    parameter int unsigned AddrWidth = ApbAddrWidth,
    parameter int unsigned DataWidth = ApbDataWidth,
    parameter int unsigned StrbWidth = ApbStrbWidth,
    parameter int unsigned ProtWidth = ApbProtWidth
) (
    input wire logic pclk,
    input wire logic presetn
);

  // ----------------------------------------------------------------------------
  // Bus Signals
  // ----------------------------------------------------------------------------
  logic [AddrWidth-1:0] paddr;
  logic                 psel;
  logic                 penable;
  logic                 pwrite;
  logic [DataWidth-1:0] pwdata;
  logic [StrbWidth-1:0] pstrb;
  logic [ProtWidth-1:0] pprot;

  logic [DataWidth-1:0] prdata;
  logic                 pready;
  logic                 pslverr;

  // ----------------------------------------------------------------------------
  // Clocking Blocks (For UVM Verification Components)
  // ----------------------------------------------------------------------------

  // Driver Clocking Block (Active Master Drive)
  clocking drv_cb @(posedge pclk);
    default input #1step output #1ns;
    output paddr;
    output psel;
    output penable;
    output pwrite;
    output pwdata;
    output pstrb;
    output pprot;
    input prdata;
    input pready;
    input pslverr;
  endclocking : drv_cb

  // Monitor Clocking Block (Passive Bus Sampling)
  clocking mon_cb @(posedge pclk);
    default input #1step output #1ns;
    input paddr;
    input psel;
    input penable;
    input pwrite;
    input pwdata;
    input pstrb;
    input pprot;
    input prdata;
    input pready;
    input pslverr;
  endclocking : mon_cb

  // ----------------------------------------------------------------------------
  // Modports
  // ----------------------------------------------------------------------------

  // Master BFM / UVM Driver Modport
  modport master_mp(
      input pclk,
      input presetn,
      input prdata,
      input pready,
      input pslverr,
      output paddr,
      output psel,
      output penable,
      output pwrite,
      output pwdata,
      output pstrb,
      output pprot
  );

  // Slave Device / DUT Modport
  modport slave_mp(
      input pclk,
      input presetn,
      input paddr,
      input psel,
      input penable,
      input pwrite,
      input pwdata,
      input pstrb,
      input pprot,
      output prdata,
      output pready,
      output pslverr
  );

  // Passive Monitor Modport
  modport monitor_mp(clocking mon_cb, input pclk, input presetn);

  // ----------------------------------------------------------------------------
  // SystemVerilog Assertions (SVA) Protocol Checker Layer
  // ----------------------------------------------------------------------------
`ifdef SIMULATION

  // 1. Unknown (X/Z) State Checks on Critical Bus Controls
  property p_no_x_on_control;
    @(posedge pclk) disable iff (!presetn) !$isunknown(
        psel
    ) && !$isunknown(
        penable
    );
  endproperty
  assert_no_x_on_control :
  assert property (p_no_x_on_control)
  else $error("[APB_IF SVA] PSEL or PENABLE resolved to unknown X/Z state!");

  // 2. APB Phase Handshake: PENABLE must assert exactly 1 cycle after PSEL
  property p_enable_follows_sel;
    @(posedge pclk) disable iff (!presetn) (psel && !penable) |=> (psel && penable);
  endproperty
  assert_enable_follows_sel :
  assert property (p_enable_follows_sel)
  else
    $error(
        "[APB_IF SVA] PENABLE must assert exactly one cycle after PSEL (Setup -> Access phase failure)!"
    );

  // 3. Address Stability: PADDR must not change during an active access phase until PREADY is high
  property p_addr_stable_during_access;
    @(posedge pclk) disable iff (!presetn) (psel && penable && !pready) |=> $stable(
        paddr
    );
  endproperty
  assert_addr_stable_during_access :
  assert property (p_addr_stable_during_access)
  else $error("[APB_IF SVA] PADDR changed while waiting for PREADY handshake!");

  // 4. Control Signals Stability: PWRITE must remain stable during active transfer
  property p_control_stable_during_access;
    @(posedge pclk) disable iff (!presetn) (psel && penable && !pready) |=> $stable(
        pwrite
    );
  endproperty
  assert_control_stable_during_access :
  assert property (p_control_stable_during_access)
  else $error("[APB_IF SVA] PWRITE changed while waiting for PREADY handshake!");

  // 5. Write Data Stability: PWDATA must not mutate while waiting for slave ready
  property p_wdata_stable_during_write;
    @(posedge pclk) disable iff (!presetn) (psel && penable && pwrite && !pready) |=> $stable(
        pwdata
    );
  endproperty
  assert_wdata_stable_during_write :
  assert property (p_wdata_stable_during_write)
  else $error("[APB_IF SVA] PWDATA corrupted during write access before PREADY was asserted!");

`endif

endinterface : apb_if

