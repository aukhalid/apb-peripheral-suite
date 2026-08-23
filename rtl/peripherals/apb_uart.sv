// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_uart.sv
// MODULE      : apb_uart
// DESCRIPTION : Parameterized APB Full-Duplex UART Controller.
//               - Reuses sync_fifo from sv-common-ip-library for TX & RX buffering.
//               - Programmable baud rate generator, 8N1 transmission framing.
//               - Interrupt signaling for TX empty and RX ready events.
// ==============================================================================

`timescale 1ns / 1ps
`default_nettype none

module apb_uart
  import apb_pkg::*;
#(
    parameter int unsigned AddrWidth = ApbAddrWidth,
    parameter int unsigned DataWidth = ApbDataWidth,
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

    // UART Physical Lines
    input  wire logic uart_rx_i,
    output logic      uart_tx_o,

    // Subsystem Level Interrupt Line
    output logic irq_o
);

  // ----------------------------------------------------------------------------
  // Register Address Offsets
  // ----------------------------------------------------------------------------
  localparam logic [11:0] RegData = 12'h000;
  localparam logic [11:0] RegStatus = 12'h004;
  localparam logic [11:0] RegCtrl = 12'h008;
  localparam logic [11:0] RegBaudDiv = 12'h00C;

  // ----------------------------------------------------------------------------
  // Registers & Internal State
  // ----------------------------------------------------------------------------
  logic [ 3:0] ctrl_q;  // [0] tx_en, [1] rx_en, [2] tx_int_en, [3] rx_int_en
  logic [15:0] baud_div_q;
  logic [15:0] baud_cnt_q;
  logic        baud_tick;

  logic        tx_en = ctrl_q[0];
  logic        rx_en = ctrl_q[1];
  logic        tx_int_en = ctrl_q[2];
  logic        rx_int_en = ctrl_q[3];
  logic        write_en = psel_i & penable_i & pwrite_i;
  logic        read_en = psel_i & penable_i & !pwrite_i;
  logic [11:0] reg_offset = paddr_i[11:0];

  // ----------------------------------------------------------------------------
  // TX & RX FIFO Signals (IP Reuse: sync_fifo)
  // ----------------------------------------------------------------------------
  logic        tx_fifo_wr = write_en && (reg_offset == RegData);
  logic        tx_fifo_rd;
  logic [ 7:0] tx_fifo_din = pwdata_i[7:0];
  logic [ 7:0] tx_fifo_dout;
  logic        tx_fifo_full;
  logic        tx_fifo_empty;

  logic        rx_fifo_wr;
  logic        rx_fifo_rd = read_en && (reg_offset == RegData);
  logic [ 7:0] rx_fifo_din;
  logic [ 7:0] rx_fifo_dout;
  logic        rx_fifo_full;
  logic        rx_fifo_empty;

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
  // 1. Baud Rate Generator
  // ----------------------------------------------------------------------------
  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      baud_cnt_q <= '0;
      baud_tick  <= 1'b0;
    end else begin
      if (baud_cnt_q >= baud_div_q) begin
        baud_cnt_q <= '0;
        baud_tick  <= 1'b1;
      end else begin
        baud_cnt_q <= baud_cnt_q + 1'b1;
        baud_tick  <= 1'b0;
      end
    end
  end

  // ----------------------------------------------------------------------------
  // 2. UART Transmitter FSM (8N1)
  // ----------------------------------------------------------------------------
  typedef enum logic [1:0] {
    TX_IDLE,
    TX_START,
    TX_DATA,
    TX_STOP
  } tx_state_e;
  tx_state_e       tx_state_q;
  logic      [2:0] tx_bit_cnt_q;
  logic      [7:0] tx_shift_reg_q;
  logic            tx_busy;

  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      tx_state_q     <= TX_IDLE;
      uart_tx_o      <= 1'b1;
      tx_fifo_rd     <= 1'b0;
      tx_bit_cnt_q   <= '0;
      tx_shift_reg_q <= '0;
    end else begin
      tx_fifo_rd <= 1'b0;  // Default pulse

      case (tx_state_q)
        TX_IDLE: begin
          uart_tx_o <= 1'b1;
          if (tx_en && !tx_fifo_empty) begin
            tx_fifo_rd     <= 1'b1;
            tx_shift_reg_q <= tx_fifo_dout;
            tx_state_q     <= TX_START;
          end
        end

        TX_START: begin
          if (baud_tick) begin
            uart_tx_o    <= 1'b0; // Start bit
            tx_bit_cnt_q <= '0;
            tx_state_q   <= TX_DATA;
          end
        end

        TX_DATA: begin
          if (baud_tick) begin
            uart_tx_o      <= tx_shift_reg_q[0];
            tx_shift_reg_q <= {1'b0, tx_shift_reg_q[7:1]};
            if (tx_bit_cnt_q == 3'd7) begin
              tx_state_q <= TX_STOP;
            end else begin
              tx_bit_cnt_q <= tx_bit_cnt_q + 1'b1;
            end
          end
        end

        TX_STOP: begin
          if (baud_tick) begin
            uart_tx_o  <= 1'b1;  // Stop bit
            tx_state_q <= TX_IDLE;
          end
        end
      endcase
    end
  end

  assign tx_busy = (tx_state_q != TX_IDLE);

  // ----------------------------------------------------------------------------
  // 3. UART Receiver FSM (8N1)
  // ----------------------------------------------------------------------------
  typedef enum logic [1:0] {
    RX_IDLE,
    RX_START,
    RX_DATA,
    RX_STOP
  } rx_state_e;
  rx_state_e rx_state_q;
  logic [2:0] rx_bit_cnt_q;
  logic [7:0] rx_shift_reg_q;
  logic [1:0] rx_sync_q;

  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      rx_sync_q <= 2'b11;
    end else begin
      rx_sync_q <= {rx_sync_q[0], uart_rx_i};
    end
  end

  logic rx_in = rx_sync_q[1];

  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      rx_state_q     <= RX_IDLE;
      rx_bit_cnt_q   <= '0;
      rx_shift_reg_q <= '0;
      rx_fifo_wr     <= 1'b0;
      rx_fifo_din    <= '0;
    end else begin
      rx_fifo_wr <= 1'b0;

      case (rx_state_q)
        RX_IDLE: begin
          if (rx_en && (rx_in == 1'b0)) begin  // Detect Start bit
            rx_state_q <= RX_START;
          end
        end

        RX_START: begin
          if (baud_tick) begin
            rx_bit_cnt_q <= '0;
            rx_state_q   <= RX_DATA;
          end
        end

        RX_DATA: begin
          if (baud_tick) begin
            rx_shift_reg_q <= {rx_in, rx_shift_reg_q[7:1]};
            if (rx_bit_cnt_q == 3'd7) begin
              rx_state_q <= RX_STOP;
            end else begin
              rx_bit_cnt_q <= rx_bit_cnt_q + 1'b1;
            end
          end
        end

        RX_STOP: begin
          if (baud_tick) begin
            if (rx_in == 1'b1 && !rx_fifo_full) begin  // Stop bit validated
              rx_fifo_wr  <= 1'b1;
              rx_fifo_din <= rx_shift_reg_q;
            end
            rx_state_q <= RX_IDLE;
          end
        end
      endcase
    end
  end

  // ----------------------------------------------------------------------------
  // 4. APB Registers Read/Write Handling
  // ----------------------------------------------------------------------------
  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      ctrl_q     <= '0;
      baud_div_q <= 16'd27;  // Default division
    end else if (write_en) begin
      case (reg_offset)
        RegCtrl:    ctrl_q <= pwdata_i[3:0];
        RegBaudDiv: baud_div_q <= pwdata_i[15:0];
        default:    ;
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
        prdata_o[4:0] = {tx_busy, rx_fifo_empty, rx_fifo_full, tx_fifo_empty, tx_fifo_full};
        RegCtrl: prdata_o[3:0] = ctrl_q;
        RegBaudDiv: prdata_o[15:0] = baud_div_q;
        default: pslverr_o = 1'b1;
      endcase
    end
  end

  // ----------------------------------------------------------------------------
  // 5. Output Drives & Interrupt Lines
  // ----------------------------------------------------------------------------
  assign pready_o = 1'b1;
  assign irq_o    = (tx_fifo_empty & tx_int_en) | (!rx_fifo_empty & rx_int_en);

endmodule : apb_uart
