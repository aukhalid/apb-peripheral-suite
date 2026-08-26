// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_subsystem_top.sv
// MODULE      : apb_subsystem_top
// DESCRIPTION : Master top-level SoC peripheral subsystem wrapper.
//               - Integrates APB Interconnect/Decoder and 9 peripheral cores.
//               - Aggregates peripheral interrupts to the central Interrupt Controller.
//               - Exposes all external physical communication pins and GPIOs.
// ==============================================================================

module apb_subsystem_top
  import apb_pkg::*;
#(
    parameter int unsigned AddrWidth = ApbAddrWidth,
    parameter int unsigned DataWidth = ApbDataWidth,
    parameter int unsigned StrbWidth = ApbStrbWidth,
    parameter int unsigned ProtWidth = ApbProtWidth,
    parameter int unsigned GpioWidth = 32,
    parameter int unsigned SpiSlaves = 1,
    parameter int unsigned MemDepth  = 256,
    parameter int unsigned FifoDepth = 16
) (
    input wire logic pclk_i,
    input wire logic presetn_i,

    // --------------------------------------------------------------------------
    // APB Host Master Bus Port
    // --------------------------------------------------------------------------
    input wire logic [AddrWidth-1:0] paddr_i,
    input wire logic                 psel_i,
    input wire logic                 penable_i,
    input wire logic                 pwrite_i,
    input wire logic [DataWidth-1:0] pwdata_i,
    input wire logic [StrbWidth-1:0] pstrb_i,
    input wire logic [ProtWidth-1:0] pprot_i,

    output logic [DataWidth-1:0] prdata_o,
    output logic                 pready_o,
    output logic                 pslverr_o,

    // --------------------------------------------------------------------------
    // External Physical Peripheral I/O
    // --------------------------------------------------------------------------
    // UART
    input  wire logic uart_rx_i,
    output logic      uart_tx_o,

    // SPI Master
    output logic                      spi_sck_o,
    output logic                      spi_mosi_o,
    input  wire logic                 spi_miso_i,
    output logic      [SpiSlaves-1:0] spi_ss_n_o,

    // I2C Open-Drain Interface
    input  wire logic i2c_scl_i,
    output logic      i2c_scl_o,
    output logic      i2c_scl_oe_o,
    input  wire logic i2c_sda_i,
    output logic      i2c_sda_o,
    output logic      i2c_sda_oe_o,

    // GPIO
    input  wire logic [GpioWidth-1:0] gpio_pin_i,
    output logic      [GpioWidth-1:0] gpio_pin_o,
    output logic      [GpioWidth-1:0] gpio_dir_o,

    // PWM
    output logic pwm_o,

    // Watchdog System Reset & Top-Level Interrupt
    output logic wdt_rst_o,
    output logic irq_top_o
);

  localparam int unsigned NumSlaves = NumPeripherals;
  localparam int unsigned NumIrq = 8;

  // ----------------------------------------------------------------------------
  // Internal Interconnect Bus Routing Signals
  // ----------------------------------------------------------------------------
  logic [NumSlaves-1:0]                s_psel;
  logic                                s_penable;
  logic                                s_pwrite;
  logic [AddrWidth-1:0]                s_paddr;
  logic [DataWidth-1:0]                s_pwdata;
  logic [StrbWidth-1:0]                s_pstrb;
  logic [ProtWidth-1:0]                s_pprot;

  logic [NumSlaves-1:0][DataWidth-1:0] s_prdata;
  logic [NumSlaves-1:0]                s_pready;
  logic [NumSlaves-1:0]                s_pslverr;

  // ----------------------------------------------------------------------------
  // Internal Interrupt Routing Lines
  // ----------------------------------------------------------------------------
  logic [   NumIrq-1:0]                irq_lines;
  logic                                uart_irq;
  logic                                spi_irq;
  logic                                i2c_irq;
  logic                                gpio_irq;
  logic                                timer_irq;
  logic                                wdt_irq;

  assign irq_lines[0] = uart_irq;
  assign irq_lines[1] = spi_irq;
  assign irq_lines[2] = i2c_irq;
  assign irq_lines[3] = gpio_irq;
  assign irq_lines[4] = timer_irq;
  assign irq_lines[5] = wdt_irq;
  assign irq_lines[6] = 1'b0;
  assign irq_lines[7] = 1'b0;

  // ============================================================================
  // 1. APB Central Interconnect
  // ============================================================================
  apb_interconnect #(
      .AddrWidth(AddrWidth),
      .DataWidth(DataWidth),
      .StrbWidth(StrbWidth),
      .ProtWidth(ProtWidth),
      .NumSlaves(NumSlaves)
  ) u_interconnect (
      .pclk_i     (pclk_i),
      .presetn_i  (presetn_i),
      .m_paddr_i  (paddr_i),
      .m_psel_i   (psel_i),
      .m_penable_i(penable_i),
      .m_pwrite_i (pwrite_i),
      .m_pwdata_i (pwdata_i),
      .m_pstrb_i  (pstrb_i),
      .m_pprot_i  (pprot_i),
      .m_prdata_o (prdata_o),
      .m_pready_o (pready_o),
      .m_pslverr_o(pslverr_o),
      .s_psel_o   (s_psel),
      .s_penable_o(s_penable),
      .s_pwrite_o (s_pwrite),
      .s_paddr_o  (s_paddr),
      .s_pwdata_o (s_pwdata),
      .s_pstrb_o  (s_pstrb),
      .s_pprot_o  (s_pprot),
      .s_prdata_i (s_prdata),
      .s_pready_i (s_pready),
      .s_pslverr_i(s_pslverr)
  );

  // ============================================================================
  // 2. Peripheral Instances
  // ============================================================================

  // Slave 0: UART Controller
  apb_uart #(
      .AddrWidth(AddrWidth),
      .DataWidth(DataWidth),
      .FifoDepth(FifoDepth)
  ) u_uart (
      .pclk_i   (pclk_i),
      .presetn_i(presetn_i),
      .paddr_i  (s_paddr),
      .psel_i   (s_psel[SlvUart]),
      .penable_i(s_penable),
      .pwrite_i (s_pwrite),
      .pwdata_i (s_pwdata),
      .prdata_o (s_prdata[SlvUart]),
      .pready_o (s_pready[SlvUart]),
      .pslverr_o(s_pslverr[SlvUart]),
      .uart_rx_i(uart_rx_i),
      .uart_tx_o(uart_tx_o),
      .irq_o    (uart_irq)
  );

  // Slave 1: SPI Master Controller
  apb_spi #(
      .AddrWidth(AddrWidth),
      .DataWidth(DataWidth),
      .NumSlaves(SpiSlaves),
      .FifoDepth(FifoDepth)
  ) u_spi (
      .pclk_i    (pclk_i),
      .presetn_i (presetn_i),
      .paddr_i   (s_paddr),
      .psel_i    (s_psel[SlvSpi]),
      .penable_i (s_penable),
      .pwrite_i  (s_pwrite),
      .pwdata_i  (s_pwdata),
      .prdata_o  (s_prdata[SlvSpi]),
      .pready_o  (s_pready[SlvSpi]),
      .pslverr_o (s_pslverr[SlvSpi]),
      .spi_sck_o (spi_sck_o),
      .spi_mosi_o(spi_mosi_o),
      .spi_miso_i(spi_miso_i),
      .spi_ss_n_o(spi_ss_n_o),
      .irq_o     (spi_irq)
  );

  // Slave 2: I2C Controller
  apb_i2c #(
      .AddrWidth(AddrWidth),
      .DataWidth(DataWidth),
      .FifoDepth(FifoDepth)
  ) u_i2c (
      .pclk_i   (pclk_i),
      .presetn_i(presetn_i),
      .paddr_i  (s_paddr),
      .psel_i   (s_psel[SlvI2c]),
      .penable_i(s_penable),
      .pwrite_i (s_pwrite),
      .pwdata_i (s_pwdata),
      .prdata_o (s_prdata[SlvI2c]),
      .pready_o (s_pready[SlvI2c]),
      .pslverr_o(s_pslverr[SlvI2c]),
      .scl_i    (i2c_scl_i),
      .scl_o    (i2c_scl_o),
      .scl_oe_o (i2c_scl_oe_o),
      .sda_i    (i2c_sda_i),
      .sda_o    (i2c_sda_o),
      .sda_oe_o (i2c_sda_oe_o),
      .irq_o    (i2c_irq)
  );

  // Slave 3: GPIO Array
  apb_gpio #(
      .AddrWidth(AddrWidth),
      .DataWidth(DataWidth),
      .GpioWidth(GpioWidth)
  ) u_gpio (
      .pclk_i    (pclk_i),
      .presetn_i (presetn_i),
      .paddr_i   (s_paddr),
      .psel_i    (s_psel[SlvGpio]),
      .penable_i (s_penable),
      .pwrite_i  (s_pwrite),
      .pwdata_i  (s_pwdata),
      .prdata_o  (s_prdata[SlvGpio]),
      .pready_o  (s_pready[SlvGpio]),
      .pslverr_o (s_pslverr[SlvGpio]),
      .gpio_pin_i(gpio_pin_i),
      .gpio_pin_o(gpio_pin_o),
      .gpio_dir_o(gpio_dir_o),
      .irq_o     (gpio_irq)
  );

  // Slave 4: Timer Peripheral
  apb_timer #(
      .AddrWidth(AddrWidth),
      .DataWidth(DataWidth)
  ) u_timer (
      .pclk_i   (pclk_i),
      .presetn_i(presetn_i),
      .paddr_i  (s_paddr),
      .psel_i   (s_psel[SlvTimer]),
      .penable_i(s_penable),
      .pwrite_i (s_pwrite),
      .pwdata_i (s_pwdata),
      .prdata_o (s_prdata[SlvTimer]),
      .pready_o (s_pready[SlvTimer]),
      .pslverr_o(s_pslverr[SlvTimer]),
      .irq_o    (timer_irq)
  );

  // Slave 5: PWM Generator
  apb_pwm #(
      .AddrWidth(AddrWidth),
      .DataWidth(DataWidth)
  ) u_pwm (
      .pclk_i   (pclk_i),
      .presetn_i(presetn_i),
      .paddr_i  (s_paddr),
      .psel_i   (s_psel[SlvPwm]),
      .penable_i(s_penable),
      .pwrite_i (s_pwrite),
      .pwdata_i (s_pwdata),
      .prdata_o (s_prdata[SlvPwm]),
      .pready_o (s_pready[SlvPwm]),
      .pslverr_o(s_pslverr[SlvPwm]),
      .pwm_o    (pwm_o)
  );

  // Slave 6: Watchdog Timer
  apb_wdt #(
      .AddrWidth(AddrWidth),
      .DataWidth(DataWidth)
  ) u_wdt (
      .pclk_i   (pclk_i),
      .presetn_i(presetn_i),
      .paddr_i  (s_paddr),
      .psel_i   (s_psel[SlvWdt]),
      .penable_i(s_penable),
      .pwrite_i (s_pwrite),
      .pwdata_i (s_pwdata),
      .prdata_o (s_prdata[SlvWdt]),
      .pready_o (s_pready[SlvWdt]),
      .pslverr_o(s_pslverr[SlvWdt]),
      .wdt_rst_o(wdt_rst_o),
      .irq_o    (wdt_irq)
  );

  // Slave 7: SRAM Memory Controller
  apb_mem_ctrl #(
      .AddrWidth(AddrWidth),
      .DataWidth(DataWidth),
      .MemDepth (MemDepth)
  ) u_mem_ctrl (
      .pclk_i   (pclk_i),
      .presetn_i(presetn_i),
      .paddr_i  (s_paddr),
      .psel_i   (s_psel[SlvMemCtrl]),
      .penable_i(s_penable),
      .pwrite_i (s_pwrite),
      .pwdata_i (s_pwdata),
      .prdata_o (s_prdata[SlvMemCtrl]),
      .pready_o (s_pready[SlvMemCtrl]),
      .pslverr_o(s_pslverr[SlvMemCtrl])
  );

  // Slave 8: Priority Interrupt Controller
  apb_ictr #(
      .AddrWidth(AddrWidth),
      .DataWidth(DataWidth),
      .NumIrq   (NumIrq)
  ) u_ictr (
      .pclk_i       (pclk_i),
      .presetn_i    (presetn_i),
      .paddr_i      (s_paddr),
      .psel_i       (s_psel[SlvIctr]),
      .penable_i    (s_penable),
      .pwrite_i     (s_pwrite),
      .pwdata_i     (s_pwdata),
      .prdata_o     (s_prdata[SlvIctr]),
      .pready_o     (s_pready[SlvIctr]),
      .pslverr_o    (s_pslverr[SlvIctr]),
      .irq_sources_i(irq_lines),
      .irq_top_o    (irq_top_o)
  );

endmodule : apb_subsystem_top
