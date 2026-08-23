# APB UART & SPI Peripheral Specifications (IP Reuse Layer)

## 1. APB UART (`apb_uart`)

Base Address: `0x4000_0000` | Window: `4 KB`

### Internal Hardware Queuing

Instantiates two 8-bit `sync_fifo` blocks from `sv-common-ip-library`:

- **TX FIFO:** Queues bytes written via APB until the serial transmitter baud generator shifts them out.
- **RX FIFO:** Collects validated bytes received over the serial RX line until read by the APB master.

### Register Map

| Offset | Name       | Type |     Reset     | Description                                                                                      |
| :----: | :--------- | :--: | :-----------: | :----------------------------------------------------------------------------------------------- |
| `0x00` | `DATA`     |  RW  | `0x0000_0000` | Write: Push to TX FIFO (`[7:0]`). Read: Pop from RX FIFO (`[7:0]`).                              |
| `0x04` | `STATUS`   |  RO  | `0x0000_0002` | Status: `[0]` TX Full, `[1]` TX Empty, `[2]` RX Full, `[3]` RX Empty, `[4]` TX Busy.             |
| `0x08` | `CTRL`     |  RW  | `0x0000_0000` | Control: `[0]` TX Enable, `[1]` RX Enable, `[2]` TX Interrupt Enable, `[3]` RX Interrupt Enable. |
| `0x0C` | `BAUD_DIV` |  RW  | `0x0000_001B` | Baud rate clock divider counter threshold.                                                       |

---

## 2. APB SPI Master (`apb_spi`)

Base Address: `0x4000_1000` | Window: `4 KB`

### Internal Hardware Queuing

Instantiates two 8-bit `sync_fifo` blocks from `sv-common-ip-library`:

- **TX FIFO:** Holds bytes waiting for SPI serialized transmission on `mosi_o`.
- **RX FIFO:** Captures serialized data sampled from `miso_i`.

### Register Map

| Offset | Name      | Type |     Reset     | Description                                                                           |
| :----: | :-------- | :--: | :-----------: | :------------------------------------------------------------------------------------ |
| `0x00` | `DATA`    |  RW  | `0x0000_0000` | Write: Push to TX FIFO (`[7:0]`). Read: Pop from RX FIFO (`[7:0]`).                   |
| `0x04` | `STATUS`  |  RO  | `0x0000_0002` | Status: `[0]` TX Full, `[1]` TX Empty, `[2]` RX Full, `[3]` RX Empty, `[4]` SPI Busy. |
| `0x08` | `CTRL`    |  RW  | `0x0000_0000` | Control: `[0]` SPI Enable, `[1]` CPOL, `[2]` CPHA, `[3]` TX Int En, `[4]` RX Int En.  |
| `0x0C` | `CLK_DIV` |  RW  | `0x0000_0004` | SCK frequency divider threshold.                                                      |
| `0x10` | `SS_CTRL` |  RW  | `0x0000_0001` | Active-low Slave Select lines (`ss_n_o`).                                             |
