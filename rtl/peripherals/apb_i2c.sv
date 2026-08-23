// ==============================================================================
// AUTHOR      : Ahasan Ullah Khalid
// PROJECT     : apb-peripheral-suite
// FILE        : apb_i2c.sv
// MODULE      : apb_i2c
// DESCRIPTION : Parameterized APB I2C Controller.
//               - Reuses sync_fifo from sv-common-ip-library for TX/RX buffering.
//               - Programmable SCL prescaler, START/STOP generator, ACK/NACK sampler.
//               - Open-drain control interface for external I2C bus pads.
// ==============================================================================


module apb_i2c
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

    // External Open-Drain I2C Physical Interface
    input  wire logic scl_i,
    output logic      scl_o,
    output logic      scl_oe_o,  // 1: Pull Low, 0: High-Z
    input  wire logic sda_i,
    output logic      sda_o,
    output logic      sda_oe_o,  // 1: Pull Low, 0: High-Z

    // Subsystem Level Interrupt Line
    output logic irq_o
);

  // ----------------------------------------------------------------------------
  // Register Offsets & Internal Registers
  // ----------------------------------------------------------------------------
  localparam logic [11:0] RegData = 12'h000;
  localparam logic [11:0] RegStatus = 12'h004;
  localparam logic [11:0] RegCtrl = 12'h008;
  localparam logic [11:0] RegClkDiv = 12'h00C;

  logic [ 3:0] ctrl_q;  // [0] enable, [1] gen_start, [2] gen_stop, [3] int_en
  logic [15:0] clk_div_q;
  logic [15:0] clk_cnt_q;
  logic        scl_tick;
  logic        nack_err_q;

  logic        i2c_en = ctrl_q[0];
  logic        gen_start = ctrl_q[1];
  logic        gen_stop = ctrl_q[2];
  logic        int_en = ctrl_q[3];
  logic        write_en = psel_i & penable_i & pwrite_i;
  logic        read_en = psel_i & penable_i & !pwrite_i;
  logic [11:0] reg_offset = paddr_i[11:0];

  // ----------------------------------------------------------------------------
  // TX & RX FIFO Instantiation (IP Reuse: sync_fifo)
  // ----------------------------------------------------------------------------
  logic        tx_fifo_wr = write_en && (reg_offset == RegData);
  logic        tx_fifo_rd;
  logic [ 7:0] tx_fifo_dout;
  logic        tx_fifo_full;
  logic        tx_fifo_empty;

  logic        rx_fifo_wr;
  logic        rx_fifo_rd = read_en && (reg_offset == RegData);
  logic [ 7:0] rx_fifo_din;
  logic [ 7:0] rx_fifo_dout;
  logic        rx_fifo_full;
  logic        rx_fifo_empty;

  sync_fifo #(
      .DATA_WIDTH(8),
      .DEPTH     (FifoDepth)
  ) u_tx_fifo (
      .clk_i         (pclk_i),
      .rst_n_i       (presetn_i),
      .wr_en_i       (tx_fifo_wr),
      .rd_en_i       (tx_fifo_rd),
      .wr_data_i     (pwdata_i[7:0]),
      .rd_data_o     (tx_fifo_dout),
      .full_o        (tx_fifo_full),
      .empty_o       (tx_fifo_empty),
      .almost_full_o (),
      .almost_empty_o(),
      .fifo_level_o  ()
  );

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
  // 1. SCL Clock Prescaler
  // ----------------------------------------------------------------------------
  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      clk_cnt_q <= '0;
      scl_tick  <= 1'b0;
    end else if (i2c_en) begin
      if (clk_cnt_q >= clk_div_q) begin
        clk_cnt_q <= '0;
        scl_tick  <= 1'b1;
      end else begin
        clk_cnt_q <= clk_cnt_q + 1'b1;
        scl_tick  <= 1'b0;
      end
    end else begin
      clk_cnt_q <= '0;
      scl_tick  <= 1'b0;
    end
  end

  // ----------------------------------------------------------------------------
  // 2. I2C Master State Machine
  // ----------------------------------------------------------------------------
  typedef enum logic [2:0] {
    I2C_IDLE,
    I2C_START,
    I2C_DATA,
    I2C_ACK,
    I2C_STOP
  } i2c_state_e;

  i2c_state_e       state_q;
  logic       [2:0] bit_cnt_q;
  logic       [7:0] shift_reg_q;
  logic             scl_drive;
  logic             sda_drive;
  logic             i2c_busy;

  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      state_q     <= I2C_IDLE;
      tx_fifo_rd  <= 1'b0;
      rx_fifo_wr  <= 1'b0;
      rx_fifo_din <= '0;
      scl_drive   <= 1'b1;
      sda_drive   <= 1'b1;
      bit_cnt_q   <= '0;
      shift_reg_q <= '0;
      nack_err_q  <= 1'b0;
    end else begin
      tx_fifo_rd <= 1'b0;
      rx_fifo_wr <= 1'b0;

      case (state_q)
        I2C_IDLE: begin
          scl_drive <= 1'b1;
          sda_drive <= 1'b1;
          if (i2c_en) begin
            if (gen_start) begin
              state_q <= I2C_START;
            end else if (!tx_fifo_empty) begin
              tx_fifo_rd  <= 1'b1;
              shift_reg_q <= tx_fifo_dout;
              bit_cnt_q   <= 3'd7;
              state_q     <= I2C_DATA;
            end
          end
        end

        I2C_START: begin
          if (scl_tick) begin
            sda_drive <= 1'b0;  // Pull SDA Low while SCL is High
            state_q   <= I2C_IDLE;
          end
        end

        I2C_DATA: begin
          if (scl_tick) begin
            scl_drive <= ~scl_drive;
            if (!scl_drive) begin
              // Setup data on SCL low
              sda_drive   <= shift_reg_q[7];
              shift_reg_q <= {shift_reg_q[6:0], 1'b0};
            end else begin
              // Sample bit on SCL high
              if (bit_cnt_q == 3'd0) begin
                state_q <= I2C_ACK;
              end else begin
                bit_cnt_q <= bit_cnt_q - 1'b1;
              end
            end
          end
        end

        I2C_ACK: begin
          if (scl_tick) begin
            scl_drive <= ~scl_drive;
            if (scl_drive) begin
              // Sample ACK bit from receiver (Low = ACK, High = NACK)
              nack_err_q <= sda_i;
              if (gen_stop) begin
                state_q <= I2C_STOP;
              end else begin
                state_q <= I2C_IDLE;
              end
            end else begin
              sda_drive <= 1'b1;  // Release line for ACK
            end
          end
        end

        I2C_STOP: begin
          if (scl_tick) begin
            sda_drive <= 1'b1;  // Release SDA while SCL is High
            state_q   <= I2C_IDLE;
          end
        end
      endcase
    end
  end

  assign i2c_busy = (state_q != I2C_IDLE);

  // Open-drain outputs (pull line low when output is 0, release when 1)
  assign scl_o    = 1'b0;
  assign scl_oe_o = ~scl_drive;
  assign sda_o    = 1'b0;
  assign sda_oe_o = ~sda_drive;

  // ----------------------------------------------------------------------------
  // 3. APB Interface Registers
  // ----------------------------------------------------------------------------
  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      ctrl_q    <= '0;
      clk_div_q <= 16'd100;
    end else if (write_en) begin
      case (reg_offset)
        RegCtrl:   ctrl_q <= pwdata_i[3:0];
        RegClkDiv: clk_div_q <= pwdata_i[15:0];
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
        prdata_o[5:0] = {
          nack_err_q, rx_fifo_full, rx_fifo_empty, tx_fifo_full, tx_fifo_empty, i2c_busy
        };
        RegCtrl: prdata_o[3:0] = ctrl_q;
        RegClkDiv: prdata_o[15:0] = clk_div_q;
        default: pslverr_o = 1'b1;
      endcase
    end
  end

  assign pready_o = 1'b1;
  assign irq_o    = (int_en) & (tx_fifo_empty | !rx_fifo_empty | nack_err_q);

endmodule : apb_i2c
