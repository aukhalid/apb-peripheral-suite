# APB Interconnect & Address Decoder Specification

## 1. Architectural Overview

The `apb_interconnect` module connects a single APB Master (CPU, DMA, or Testbench BFM) to multiple APB Slaves (Peripherals) using centralized address decoding and response multiplexing.

### Key Features

- **Parameterized Addressing:** Configurable address widths, data widths, and number of peripheral slaves.
- **Decode Error Handling:** If the master accesses an unmapped address region, the interconnect intercepts the transaction, returns `PSLVERR = 1'b1`, asserts `PREADY = 1'b1`, and returns `PRDATA = 32'hDEAD_C0DE` without locking up the bus.
- **Zero-Cycle Multiplexing:** Combinational routing of control signals (`PENABLE`, `PWRITE`, `PWDATA`, `PADDR`) and one-hot `PSEL` generation.

---

## 2. Memory Map Layout

Each peripheral occupies a 4 KB ($0x1000$) aligned address slot:

| Slave ID | Peripheral Name | Base Address  |  End Address  | Purpose                              |
| :------: | :-------------- | :-----------: | :-----------: | :----------------------------------- |
|   `0`    | `apb_uart`      | `0x4000_0000` | `0x4000_0FFF` | Serial Communication Console         |
|   `1`    | `apb_spi`       | `0x4000_1000` | `0x4000_1FFF` | High-Speed Synchronous Serial Bus    |
|   `2`    | `apb_i2c`       | `0x4000_2000` | `0x4000_2FFF` | Two-Wire Sensor Interface            |
|   `3`    | `apb_gpio`      | `0x4000_3000` | `0x4000_3FFF` | General Purpose Digital I/O Pins     |
|   `4`    | `apb_timer`     | `0x4000_4000` | `0x4000_4FFF` | Real-Time Counters & Periodic Timers |
|   `5`    | `apb_pwm`       | `0x4000_5000` | `0x4000_5FFF` | Pulse-Width Modulation Generator     |
|   `6`    | `apb_wdt`       | `0x4000_6000` | `0x4000_6FFF` | Watchdog Recovery Timer              |
|   `7`    | `apb_mem_ctrl`  | `0x4000_7000` | `0x4000_7FFF` | On-Chip SRAM Bridge Controller       |
|   `8`    | `apb_ictr`      | `0x4000_8000` | `0x4000_8FFF` | Priority Interrupt Controller        |

---

## 3. Signal Interface

### Master Port (Connected to Host / Bus Master)

| Port Name     | Direction |    Width     | Description                                 |
| :------------ | :-------: | :----------: | :------------------------------------------ |
| `pclk_i`      |   Input   |      1       | Global APB system clock.                    |
| `presetn_i`   |   Input   |      1       | Active-low system reset.                    |
| `m_paddr_i`   |   Input   | `ADDR_WIDTH` | Address bus driven by master.               |
| `m_psel_i`    |   Input   |      1       | Master transfer select strobe.              |
| `m_penable_i` |   Input   |      1       | Master transfer enable strobe.              |
| `m_pwrite_i`  |   Input   |      1       | High for write, low for read.               |
| `m_pwdata_i`  |   Input   | `DATA_WIDTH` | Master write data payload.                  |
| `m_pstrb_i`   |   Input   | `STRB_WIDTH` | Byte write strobes (optional APB4 feature). |
| `m_pprot_i`   |   Input   |      3       | Protection type descriptor.                 |
| `m_prdata_o`  |  Output   | `DATA_WIDTH` | Read data routed back to master.            |
| `m_pready_o`  |  Output   |      1       | Transfer complete handshake.                |
| `m_pslverr_o` |  Output   |      1       | Error flag returned to master.              |

### Slave Interfaces (Connected to Peripherals `0` to `NUM_SLAVES-1`)

| Port Name     | Direction |           Width           | Description                              |
| :------------ | :-------: | :-----------------------: | :--------------------------------------- |
| `s_psel_o`    |  Output   |       `NUM_SLAVES`        | One-hot peripheral select vector.        |
| `s_penable_o` |  Output   |             1             | Broadcast enable strobe to all slaves.   |
| `s_pwrite_o`  |  Output   |             1             | Broadcast write strobe.                  |
| `s_paddr_o`   |  Output   |       `ADDR_WIDTH`        | Broadcast address bus.                   |
| `s_pwdata_o`  |  Output   |       `DATA_WIDTH`        | Broadcast write data.                    |
| `s_pstrb_o`   |  Output   |       `STRB_WIDTH`        | Broadcast byte strobes.                  |
| `s_pprot_o`   |  Output   |             3             | Broadcast protection bits.               |
| `s_prdata_i`  |   Input   | `NUM_SLAVES * DATA_WIDTH` | Flattened read data from all slaves.     |
| `s_pready_i`  |   Input   |       `NUM_SLAVES`        | Ready handshake signals from all slaves. |
| `s_pslverr_i` |   Input   |       `NUM_SLAVES`        | Slave error response flags.              |
