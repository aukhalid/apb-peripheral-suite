# APB I2C, PWM, & Watchdog Timer Peripheral Specifications

## 1. APB I2C Master/Slave Controller (`apb_i2c`)

Base Address: `0x4000_2000` | Window: `4 KB`

### Internal Hardware Queuing

Instantiates two 8-bit `sync_fifo` blocks from `sv-common-ip-library` for buffering transmit and receive payloads.

### Register Map

| Offset | Name      | Type |     Reset     | Description                                                                                 |
| :----: | :-------- | :--: | :-----------: | :------------------------------------------------------------------------------------------ |
| `0x00` | `DATA`    |  RW  | `0x0000_0000` | Write: Push byte to TX FIFO. Read: Pop byte from RX FIFO.                                   |
| `0x04` | `STATUS`  |  RO  | `0x0000_000A` | `[0]` Busy, `[1]` TX Empty, `[2]` TX Full, `[3]` RX Empty, `[4]` RX Full, `[5]` NACK Error. |
| `0x08` | `CTRL`    |  RW  | `0x0000_0000` | `[0]` Enable, `[1]` Start Gen, `[2]` Stop Gen, `[3]` Int Enable.                            |
| `0x0C` | `CLK_DIV` |  RW  | `0x0000_0064` | SCL clock prescaler division factor.                                                        |

---

## 2. APB Pulse-Width Modulation Generator (`apb_pwm`)

Base Address: `0x4000_5000` | Window: `4 KB`

### Register Map

| Offset | Name       | Type |     Reset     | Description                                             |
| :----: | :--------- | :--: | :-----------: | :------------------------------------------------------ |
| `0x00` | `CTRL`     |  RW  | `0x0000_0000` | `[0]` PWM Channel Enable, `[1]` Invert Output Polarity. |
| `0x04` | `PERIOD`   |  RW  | `0x0000_00FF` | 32-bit counter period threshold ($T$).                  |
| `0x08` | `DUTY`     |  RW  | `0x0000_007F` | 32-bit high-duration threshold ($D$).                   |
| `0x0C` | `PRESCALE` |  RW  | `0x0000_0000` | Clock prescaler division threshold.                     |

---

## 3. APB Watchdog Recovery Timer (`apb_wdt`)

Base Address: `0x4000_6000` | Window: `4 KB`

### Register Map

| Offset | Name     | Type |     Reset     | Description                                                    |
| :----: | :------- | :--: | :-----------: | :------------------------------------------------------------- |
| `0x00` | `CTRL`   |  RW  | `0x0000_0000` | `[0]` WDT Enable, `[1]` Reset Action Enable, `[2]` Int Enable. |
| `0x04` | `RELOAD` |  RW  | `0x0000_FFFF` | Watchdog countdown initial timer value.                        |
| `0x08` | `VALUE`  |  RO  | `0x0000_FFFF` | Current live countdown value.                                  |
| `0x0C` | `KICK`   |  WO  | `0x0000_0000` | Write `0xA5A5` to reload/service the watchdog counter.         |
| `0x10` | `STATUS` | W1C  | `0x0000_0000` | `[0]` Timeout Flag (Write 1 to clear).                         |
