// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : tb_top.sv
// MODULE      : tb_top
// DESCRIPTION : Master UVM Top-Level Simulation Testbench Fixture.
//               - Generates 100 MHz APB system clock (pclk) and reset (presetn).
//               - Instantiates the physical AMBA APB interface (apb_if).
//               - Connects the DUT (apb_subsystem_top) with loopbacks and pull-ups.
//               - Registers virtual interface into uvm_config_db.
//               - Initiates the UVM phase engine via run_test().
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype none

`include "uvm_macros.svh"
import uvm_pkg::*;
import apb_pkg::*;

// Include all UVM tests into the compilation scope
`include "base_test.sv"
`include "apb_reg_test.sv"

module tb_top;

  // ----------------------------------------------------------------------------
  // 1. Parameters & Clock Generation
  // ----------------------------------------------------------------------------
  localparam time CLK_PERIOD = 10ns; // 100 MHz Reference Clock

  logic pclk;
  logic presetn;

  // Free-running System Clock
  initial begin
    pclk = 1'b0;
    forever #(CLK_PERIOD / 2) pclk = ~pclk;
  end

  // Asynchronous Reset Generation Sequence
  initial begin
    presetn = 1'b0;
    #(CLK_PERIOD * 3);
    @(posedge pclk);
    presetn <= 1'b1;
    `uvm_info("TB_TOP", "=== System Reset Released (presetn = 1) ===", UVM_LOW)
  end

  // ----------------------------------------------------------------------------
  // 2. Physical Interface Instantiation
  // ----------------------------------------------------------------------------
  apb_if #(
      .AddrWidth (ApbAddrWidth),
      .DataWidth (ApbDataWidth),
      .StrbWidth (ApbStrbWidth),
      .ProtWidth (ApbProtWidth)
  ) vif (
      .pclk    (pclk),
      .presetn (presetn)
  );

  // ----------------------------------------------------------------------------
  // 3. External Signal Harness & Loopback Wires
  // ----------------------------------------------------------------------------
  // UART Lines
  wire  logic        uart_tx;
  logic              uart_rx;

  // Hardware Loopback: Route TX output straight back to RX input
  assign uart_rx = uart_tx;

  // SPI Lines
  wire  logic        spi_sck;
  wire  logic        spi_mosi;
  wire  logic        spi_miso;
  wire  logic [0:0]  spi_ss_n;

  // Loopback MOSI -> MISO for self-testing SPI
  assign spi_miso = spi_mosi;

  // I2C Open-Drain Bus with External Pull-ups
  wire  logic        i2c_scl_out;
  wire  logic        i2c_scl_oe;
  wire  logic        i2c_sda_out;
  wire  logic        i2c_sda_oe;

  wire  logic        i2c_scl_bus;
  wire  logic        i2c_sda_bus;

  // Open-drain pull-down / resistive pull-up behavior
  assign i2c_scl_bus = i2c_scl_oe ? i2c_scl_out : 1'bz;
  assign i2c_sda_bus = i2c_sda_oe ? i2c_sda_out : 1'bz;
  pulldown(i2c_scl_bus); // Simulates passive line pull-up via pull1/weak
  pullup(i2c_sda_bus);

  // GPIO Lines
  wire  logic [31:0] gpio_out;
  wire  logic [31:0] gpio_dir;
  logic [31:0]       gpio_in;

  // Route output pins back into input pins
  assign gpio_in = gpio_out;

  // PWM & Watchdog Status
  wire  logic        pwm_signal;
  wire  logic        wdt_reset;
  wire  logic        subsystem_irq;

  // ----------------------------------------------------------------------------
  // 4. DUT Instantiation (apb_subsystem_top)
  // ----------------------------------------------------------------------------
  apb_subsystem_top #(
      .AddrWidth (ApbAddrWidth),
      .DataWidth (ApbDataWidth),
      .StrbWidth (ApbStrbWidth),
      .ProtWidth (ApbProtWidth),
      .GpioWidth (32),
      .SpiSlaves (1),
      .MemDepth  (256),
      .FifoDepth (16)
  ) u_dut (
      .pclk_i        (pclk),
      .presetn_i     (presetn),

      // APB Host Master Port (Bound to apb_if)
      .paddr_i       (vif.paddr),
      .psel_i        (vif.psel),
      .penable_i     (vif.penable),
      .pwrite_i      (vif.pwrite),
      .pwdata_i      (vif.pwdata),
      .pstrb_i       (vif.pstrb),
      .pprot_i       (vif.pprot),
      .prdata_o      (vif.prdata),
      .pready_o      (vif.pready),
      .pslverr_o     (vif.pslverr),

      // External Physical Interfaces
      .uart_rx_i     (uart_rx),
      .uart_tx_o     (uart_tx),

      .spi_sck_o     (spi_sck),
      .spi_mosi_o    (spi_mosi),
      .spi_miso_i    (spi_miso),
      .spi_ss_n_o    (spi_ss_n),

      .i2c_scl_i     (i2c_scl_bus),
      .i2c_scl_o     (i2c_scl_out),
      .i2c_scl_oe_o  (i2c_scl_oe),
      .i2c_sda_i     (i2c_sda_bus),
      .i2c_sda_o     (i2c_sda_out),
      .i2c_sda_oe_o  (i2c_sda_oe),

      .gpio_pin_i    (gpio_in),
      .gpio_pin_o    (gpio_out),
      .gpio_dir_o    (gpio_dir),

      .pwm_o         (pwm_signal),
      .wdt_rst_o     (wdt_reset),
      .irq_top_o     (subsystem_irq)
  );

  // ----------------------------------------------------------------------------
  // 5. Testbench Setup & UVM Invocation
  // ----------------------------------------------------------------------------
  initial begin
    // Set virtual interface in Config DB for driver and monitor access
    uvm_config_db#(virtual apb_if)::set(null, "*", "vif", vif);

    // Waveform Dump Setup
    `ifdef SIMULATION
      $dumpfile("dump.vcd");
      $dumpvars(0, tb_top);
    `endif

    // Start UVM Test selected via CLI (+UVM_TESTNAME=...)
    run_test();
  end

endmodule : tb_top

`default_nettype wire
