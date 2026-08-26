# APB Peripheral Subsystem Top Specification

## 1. Architectural Overview

The `apb_subsystem_top` module serves as the complete hardware integration wrapper for Project 2 (`apb-peripheral-suite`). It connects an external APB Master to **9 internal memory-mapped slave peripherals** through the `apb_interconnect`.

```text
                         +-------------------------------------------------------+
                         |                  apb_subsystem_top                    |
                         |                                                       |
                         |  +------------------+     +------------------------+  |
APB Host Master          |  |                  |     |                        |  |
(pclk, presetn,          |  | apb_interconnect |---->| UART, SPI, I2C         |  |
paddr, psel, etc.) ------|->| (apb_decoder)    |---->| GPIO, Timer, PWM, WDT  |  |
                         |  +------------------+     | APB Memory Controller  |  |
                         |             |             +-----------+------------+  |
                         |             |                         |               |
                         |             | IRQ lines               |               |
                         |             v                         |               |
                         |  +------------------------+           |               |
                         |  |   apb_ictr (Interrupt) |-----------+--> irq_top_o  |
                         |  +------------------------+                           |
                         |                                                       |
                         +-------------------------------------------------------+
                                           |
                                           v
                                    External Pads
                              (TX, RX, SCLK, MOSI,
                               MISO, GPIOs, etc.)
```

The top-level subsystem is responsible for:

- APB bus integration.
- Address-based slave selection.
- APB request and response routing.
- Integration of all peripheral IP blocks.
- Interrupt aggregation and routing.
- External peripheral I/O connectivity.
- Providing a single top-level interface to the system APB master.

---

## 2. Integrated Slaves & Address Map

All peripherals occupy **4 KB (`0x1000`) address windows**.

| Base Address  | Peripheral     | Address Range               |
| :-----------: | :------------- | :-------------------------- |
| `0x4000_0000` | `apb_uart`     | `0x4000_0000 - 0x4000_0FFF` |
| `0x4000_1000` | `apb_spi`      | `0x4000_1000 - 0x4000_1FFF` |
| `0x4000_2000` | `apb_i2c`      | `0x4000_2000 - 0x4000_2FFF` |
| `0x4000_3000` | `apb_gpio`     | `0x4000_3000 - 0x4000_3FFF` |
| `0x4000_4000` | `apb_timer`    | `0x4000_4000 - 0x4000_4FFF` |
| `0x4000_5000` | `apb_pwm`      | `0x4000_5000 - 0x4000_5FFF` |
| `0x4000_6000` | `apb_wdt`      | `0x4000_6000 - 0x4000_6FFF` |
| `0x4000_7000` | `apb_mem_ctrl` | `0x4000_7000 - 0x4000_7FFF` |
| `0x4000_8000` | `apb_ictr`     | `0x4000_8000 - 0x4000_8FFF` |

### Address Decode

The `apb_interconnect` decodes the APB master's `PADDR` and generates the appropriate peripheral select signal.

For example:

```text
PADDR = 0x4000_0120
         |
         v
   Address Decoder
         |
         v
   0x4000_0000 region
         |
         v
     apb_uart
```

Similarly:

```text
PADDR = 0x4000_2340
         |
         v
   Address Decoder
         |
         v
   0x4000_2000 region
         |
         v
      apb_i2c
```

Only the peripheral corresponding to the decoded address range should receive an active APB select signal.

---

## 3. Peripheral Interrupt Channel Assignment

The interrupt controller uses an **8-bit interrupt source vector**.

| IRQ Bit | Peripheral Source | Description                   |
| :-----: | :---------------- | :---------------------------- |
|   `0`   | `apb_uart`        | TX Empty / RX Valid IRQ       |
|   `1`   | `apb_spi`         | SPI Transfer Done IRQ         |
|   `2`   | `apb_i2c`         | I2C Byte Done / Error IRQ     |
|   `3`   | `apb_gpio`        | Pin Edge Triggered IRQ        |
|   `4`   | `apb_timer`       | Timer Terminal Count IRQ      |
|   `5`   | `apb_wdt`         | Watchdog Expiration Alert IRQ |
|   `6`   | Reserved          | Tied to `0`                   |
|   `7`   | Reserved          | Tied to `0`                   |

### Interrupt Flow

```text
             Peripheral IRQ Sources
                     |
                     v
        +--------------------------+
        |      IRQ Source Vector   |
        |                          |
        | [0] UART IRQ             |
        | [1] SPI IRQ              |
        | [2] I2C IRQ              |
        | [3] GPIO IRQ             |
        | [4] TIMER IRQ            |
        | [5] WDT IRQ              |
        | [6] RESERVED = 0         |
        | [7] RESERVED = 0         |
        +------------+-------------+
                     |
                     v
              +-------------+
              |  apb_ictr   |
              |  Interrupt  |
              |  Controller |
              +------+------+
                     |
                     v
                 irq_top_o
```

The `apb_ictr` receives the individual peripheral interrupt sources, applies the configured interrupt enable/mask and status logic, and produces the top-level `irq_top_o` signal.

---

## 4. Top-Level Integration Structure

The `apb_subsystem_top` should conceptually contain the following major blocks:

```text
                        apb_subsystem_top
                               |
          +--------------------+--------------------+
          |                    |                    |
          v                    v                    v
   APB Interconnect       Peripheral IPs       Interrupt System
          |                    |                    |
          |          +---------+---------+          |
          |          |         |         |          |
          v          v         v         v          v
      Address     UART       SPI       I2C      apb_ictr
      Decoder      GPIO      TIMER     PWM
                   WDT       MEM_CTRL
```

### Main Responsibilities

#### `apb_interconnect`

Responsible for:

- Address decoding.
- Peripheral selection.
- APB control signal distribution.
- Write-data routing.
- Read-data multiplexing.
- `PREADY` routing.
- `PSLVERR` routing.

#### Peripheral Blocks

Each peripheral implements its own functionality and register map:

- `apb_uart`
- `apb_spi`
- `apb_i2c`
- `apb_gpio`
- `apb_timer`
- `apb_pwm`
- `apb_wdt`
- `apb_mem_ctrl`
- `apb_ictr`

#### `apb_ictr`

Responsible for:

- Receiving peripheral interrupt sources.
- Maintaining interrupt status.
- Applying interrupt enable/mask configuration.
- Generating the top-level interrupt output.

---

## 5. APB Transaction Flow

A typical APB transaction follows this path:

```text
APB Master
    |
    | PADDR, PWRITE, PWDATA, PSEL
    v
apb_subsystem_top
    |
    v
apb_interconnect
    |
    | Address Decode
    v
Selected Peripheral
    |
    | PRDATA / PREADY / PSLVERR
    v
apb_interconnect
    |
    v
APB Master
```

### Write Transaction

For an APB write:

```text
1. Master places address on PADDR.
2. Master asserts PSEL.
3. Master asserts PWRITE = 1.
4. Master places write data on PWDATA.
5. Interconnect decodes PADDR.
6. Corresponding peripheral is selected.
7. Peripheral accepts PWDATA.
8. Peripheral completes the transfer using PREADY.
```

### Read Transaction

For an APB read:

```text
1. Master places address on PADDR.
2. Master asserts PSEL.
3. Master drives PWRITE = 0.
4. Interconnect decodes PADDR.
5. Corresponding peripheral is selected.
6. Peripheral places data on PRDATA.
7. Interconnect routes PRDATA back to the master.
8. Peripheral completes the transfer using PREADY.
```

---

## 6. External I/O Connectivity

The subsystem exposes peripheral signals to external pads.

Typical external interfaces include:

```text
UART
 ├── uart_tx_o
 └── uart_rx_i

SPI
 ├── spi_sclk_o
 ├── spi_mosi_o
 ├── spi_miso_i
 └── spi_cs_o

I2C
 ├── i2c_scl
 └── i2c_sda

GPIO
 ├── gpio_o
 └── gpio_i

PWM
 └── pwm_o

Interrupt
 └── irq_top_o
```

The exact signal naming and direction should follow the individual peripheral module specifications.

---

## 7. Overall System Architecture

```text
                              APB SYSTEM
                                  |
                                  v
                    +---------------------------+
                    |     apb_subsystem_top     |
                    |                           |
                    |  +---------------------+  |
                    |  |  APB Interconnect   |  |
                    |  |                     |  |
                    |  |  Address Decoder    |  |
                    |  |  APB Router         |  |
                    |  +----------+----------+  |
                    |             |             |
                    |     +-------+-------+     |
                    |     |       |       |     |
                    |     v       v       v     |
                    |    UART    SPI     I2C    |
                    |     |       |       |     |
                    |     +-------+-------+     |
                    |             |             |
                    |     +-------+-------+     |
                    |     |       |       |     |
                    |     v       v       v     |
                    |    GPIO   TIMER    PWM    |
                    |                           |
                    |     +-------+-------+     |
                    |     |       |       |     |
                    |     v       v       v     |
                    |    WDT   MEM_CTRL  ICTR   |
                    |                           |
                    |             |             |
                    |        IRQ Aggregation    |
                    |             |             |
                    +-------------+-------------+
                                  |
                                  v
                              irq_top_o
```

This architecture provides a centralized APB integration layer while keeping each peripheral independently reusable and memory-mapped. The `apb_interconnect` handles bus routing, while `apb_ictr` provides centralized interrupt management for the subsystem.
