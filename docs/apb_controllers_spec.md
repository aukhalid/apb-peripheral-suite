# APB Memory Controller & Interrupt Controller Specifications

## 1. APB Memory Controller (`apb_mem_ctrl`)

Base Address: `0x4000_7000` | Window: `4 KB`

### Internal Hardware Submodules

Instantiates `single_port_ram` from `sv-common-ip-library` as an internal, parameterizable scratchpad SRAM buffer.

### Operation

Translates standard APB read/write bus handshakes into single-cycle synchronous memory access transactions with zero wait-states.

---

## 2. APB Interrupt Controller (`apb_ictr`)

Base Address: `0x4000_8000` | Window: `4 KB`

### Internal Hardware Submodules

Instantiates `fixed_arbiter` from `sv-common-ip-library` to prioritize active interrupt lines (Bit 0 has highest priority).

### Register Map

| Offset | Name         | Type |     Reset     | Description                                                       |
| :----: | :----------- | :--: | :-----------: | :---------------------------------------------------------------- |
| `0x00` | `ENABLE`     |  RW  | `0x0000_0000` | Per-channel interrupt enable mask.                                |
| `0x04` | `RAW_STATUS` |  RO  | `0x0000_0000` | Live unmasked interrupt source signals.                           |
| `0x08` | `PENDING`    |  RO  | `0x0000_0000` | Active enabled interrupts waiting for service (`RAW & ENABLE`).   |
| `0x0C` | `SERVICED`   |  RO  | `0x0000_0000` | One-hot ID of the currently highest-priority granted IRQ channel. |
| `0x10` | `CLEAR`      |  WO  | `0x0000_0000` | Write 1 to clear the corresponding latched interrupt flag.        |
