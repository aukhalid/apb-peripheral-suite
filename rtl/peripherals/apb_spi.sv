// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_spi.sv
// MODULE      : apb_spi
// DESCRIPTION : Parameterized APB Serial Peripheral Interface (SPI) Master.
//               - Reuses sync_fifo from sv-common-ip-library for TX & RX buffering.
//               - Configurable CPOL/CPHA clock modes and programmable SCK prescaler.
//               - Active-low slave select driver with transfer interrupt generation.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype none

module apb_spi
  import apb_pkg::*;
#(
    parameter int unsigned AddrWidth = ApbAddrWidth,
    parameter int unsigned DataWidth = ApbDataWidth,
    parameter int unsigned NumSlaves = 1,
    parameter int unsigned FifoDepth = 16
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

    // SPI Physical Pins
    output logic                      spi_sck_o,
    output logic                      spi_mosi_o,
    input  wire logic                 spi_miso_i,
    output logic      [NumSlaves-1:0] spi_ss_n_o,

    // Subsystem Level Interrupt Line
    output logic irq_o
);

  // ----------------------------------------------------------------------------
  // Register Address Offsets
  // ----------------------------------------------------------------------------
  localparam logic [11:0] RegData = 12'h000;
  localparam logic [11:0] RegStatus = 12'h004;
  localparam logic [11:0] RegCtrl = 12'h008;
  localparam logic [11:0] RegClkDiv = 12'h00C;
  localparam logic [11:0] RegSsCtrl = 12'h010;

  // ----------------------------------------------------------------------------
  // Registers & Internal State
  // ----------------------------------------------------------------------------
  logic [          4:0] ctrl_q;  // [0] spi_en, [1] cpol, [2] cpha, [3] tx_int_en, [4] rx_int_en
  logic [         15:0] clk_div_q;
  logic [NumSlaves-1:0] ss_ctrl_q;

  logic                 spi_en = ctrl_q[0];
  logic                 cpol = ctrl_q[1];
  logic                 cpha = ctrl_q[2];
  logic                 tx_int_en = ctrl_q[3];
  logic                 rx_int_en = ctrl_q[4];
  logic                 write_en = psel_i & penable_i & pwrite_i;
  logic                 read_en = psel_i & penable_i & !pwrite_i;
  logic [         11:0] reg_offset = paddr_i[11:0];

  // ----------------------------------------------------------------------------
  // TX & RX FIFO Signals (IP Reuse: sync_fifo)
  // ----------------------------------------------------------------------------
  logic                 tx_fifo_wr = write_en && (reg_offset == RegData);
  logic                 tx_fifo_rd;
  logic [          7:0] tx_fifo_din = pwdata_i[7:0];
  logic [          7:0] tx_fifo_dout;
  logic                 tx_fifo_full;
  logic                 tx_fifo_empty;

  logic                 rx_fifo_wr;
  logic                 rx_fifo_rd = read_en && (reg_offset == RegData);
  logic [          7:0] rx_fifo_din;
  logic [          7:0] rx_fifo_dout;
  logic                 rx_fifo_full;
  logic                 rx_fifo_empty;

  // Reused TX FIFO
  sync_fifo #(
      .DATA_WIDTH(8),
      .DEPTH     (FifoDepth)
  ) u_tx_fifo (
      .clk_i         (pclk_i),
      .rst_n_i       (presetn_i),
      .wr_en_i       (tx_fifo_wr),
      .rd_en_i       (tx_fifo_rd),
      .wr_data_i     (tx_fifo_din),
      .rd_data_o     (tx_fifo_dout),
      .full_o        (tx_fifo_full),
      .empty_o       (tx_fifo_empty),
      .almost_full_o (),
      .almost_empty_o(),
      .fifo_level_o  ()
  );

  // Reused RX FIFO
  sync_fifo #(
      .DATA_WIDTH(8),
      .DEPTH     (FifoDepth)
  ) u_rx_fifo (
      .clk_i         (pclk_i),
      .rst_n_i       (presetn_i),
      .wr_en_i       (rx_fifo_wr),
      .rd_en_i       (rx_fifo_rd),
      .wr_data_i     (rx_fifo_din),
      .rd_data_o     (rx_fifo_dout),
      .full_o        (rx_fifo_full),
      .empty_o       (rx_fifo_empty),
      .almost_full_o (),
      .almost_empty_o(),
      .fifo_level_o  ()
  );

  // ----------------------------------------------------------------------------
  // 1. SPI Master Engine & Bit-Shifter
  // ----------------------------------------------------------------------------
  typedef enum logic [1:0] {
    SPI_IDLE,
    SPI_TRANSFER,
    SPI_DONE
  } spi_state_e;
  spi_state_e        spi_state_q;

  logic       [15:0] clk_cnt_q;
  logic       [ 2:0] bit_cnt_q;
  logic       [ 7:0] tx_shift_reg_q;
  logic       [ 7:0] rx_shift_reg_q;
  logic              sck_internal;
  logic              spi_busy;

  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      spi_state_q    <= SPI_IDLE;
      tx_fifo_rd     <= 1'b0;
      rx_fifo_wr     <= 1'b0;
      rx_fifo_din    <= '0;
      tx_shift_reg_q <= '0;
      rx_shift_reg_q <= '0;
      bit_cnt_q      <= '0;
      clk_cnt_q      <= '0;
      sck_internal   <= 1'b0;
    end else begin
      tx_fifo_rd <= 1'b0;
      rx_fifo_wr <= 1'b0;

      case (spi_state_q)
        SPI_IDLE: begin
          sck_internal <= cpol;
          if (spi_en && !tx_fifo_empty) begin
            tx_fifo_rd     <= 1'b1;
            tx_shift_reg_q <= tx_fifo_dout;
            bit_cnt_q      <= 3'd7;
            clk_cnt_q      <= '0;
            spi_state_q    <= SPI_TRANSFER;
          end
        end

        SPI_TRANSFER: begin
          if (clk_cnt_q >= clk_div_q) begin
            clk_cnt_q    <= '0;
            sck_internal <= ~sck_internal;

            // Sample MISO on active clock phase
            if (sck_internal == (cpol ^ cpha)) begin
              rx_shift_reg_q <= {rx_shift_reg_q[6:0], spi_miso_i};
              if (bit_cnt_q == 3'd0) begin
                spi_state_q <= SPI_DONE;
              end else begin
                bit_cnt_q <= bit_cnt_q - 1'b1;
              end
            end else begin
              // Shift MOSI on alternate clock phase
              tx_shift_reg_q <= {tx_shift_reg_q[6:0], 1'b0};
            end
          end else begin
            clk_cnt_q <= clk_cnt_q + 1'b1;
          end
        end

        SPI_DONE: begin
          sck_internal <= cpol;
          if (!rx_fifo_full) begin
            rx_fifo_wr  <= 1'b1;
            rx_fifo_din <= rx_shift_reg_q;
          end
          spi_state_q <= SPI_IDLE;
        end
      endcase
    end
  end

  assign spi_busy   = (spi_state_q != SPI_IDLE);
  assign spi_sck_o  = sck_internal;
  assign spi_mosi_o = tx_shift_reg_q[7];
  assign spi_ss_n_o = (spi_busy) ? ss_ctrl_q : {NumSlaves{1'b1}};

  // ----------------------------------------------------------------------------
  // 2. APB Register Read/Write Handling
  // ----------------------------------------------------------------------------
  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      ctrl_q    <= '0;
      clk_div_q <= 16'd4;
      ss_ctrl_q <= '0;
    end else if (write_en) begin
      case (reg_offset)
        RegCtrl:   ctrl_q <= pwdata_i[4:0];
        RegClkDiv: clk_div_q <= pwdata_i[15:0];
        RegSsCtrl: ss_ctrl_q <= pwdata_i[NumSlaves-1:0];
        default:   ;
      endcase
    end
  end

  always_comb begin
    prdata_o  = '0;
    pslverr_o = 1'b0;

    if (psel_i && !pwrite_i) begin
      case (reg_offset)
        RegData: prdata_o[7:0] = rx_fifo_dout;
        RegStatus:
        prdata_o[4:0] = {spi_busy, rx_fifo_empty, rx_fifo_full, tx_fifo_empty, tx_fifo_full};
        RegCtrl: prdata_o[4:0] = ctrl_q;
        RegClkDiv: prdata_o[15:0] = clk_div_q;
        RegSsCtrl: prdata_o[NumSlaves-1:0] = ss_ctrl_q;
        default: pslverr_o = 1'b1;
      endcase
    end
  end

  // ----------------------------------------------------------------------------
  // 3. Output Drives & Interrupt Lines
  // ----------------------------------------------------------------------------
  assign pready_o = 1'b1;
  assign irq_o    = (tx_fifo_empty & tx_int_en) | (!rx_fifo_empty & rx_int_en);

endmodule : apb_spi
