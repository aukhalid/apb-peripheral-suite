# APB GPIO & Timer Peripheral Specifications

## 1. APB GPIO (`apb_gpio`)

Base Address: `0x4000_3000` | Window: `4 KB`

### Register Map

| Offset | Name         | Type |     Reset     | Description                                                 |
| :----: | :----------- | :--: | :-----------: | :---------------------------------------------------------- |
| `0x00` | `DATA_IN`    |  RO  | `0x0000_0000` | Samples external pin state `gpio_pin_i`.                    |
| `0x04` | `DATA_OUT`   |  RW  | `0x0000_0000` | Value driven to `gpio_pin_o`.                               |
| `0x08` | `DIR`        |  RW  | `0x0000_0000` | Pin direction (1 = Output, 0 = Input). Drives `gpio_dir_o`. |
| `0x0C` | `INT_EN`     |  RW  | `0x0000_0000` | Per-pin interrupt enable mask.                              |
| `0x10` | `INT_STATUS` | W1C  | `0x0000_0000` | Per-pin interrupt flag (Write-1-to-Clear).                  |

---

## 2. APB Timer (`apb_timer`)

Base Address: `0x4000_4000` | Window: `4 KB`

### Register Map

| Offset | Name         | Type |     Reset     | Description                                                       |
| :----: | :----------- | :--: | :-----------: | :---------------------------------------------------------------- |
| `0x00` | `CTRL`       |  RW  | `0x0000_0000` | Control: `[0]` Enable, `[1]` Auto-reload, `[2]` Interrupt Enable. |
| `0x04` | `LOAD`       |  RW  | `0x0000_0000` | Counter reload/start value.                                       |
| `0x08` | `VALUE`      |  RO  | `0x0000_0000` | Current real-time 32-bit counter value.                           |
| `0x0C` | `PRESCALE`   |  RW  | `0x0000_0000` | Clock prescaler division threshold.                               |
| `0x10` | `INT_STATUS` | W1C  | `0x0000_0000` | `[0]` Timer elapsed interrupt flag (Write 1 to clear).            |
