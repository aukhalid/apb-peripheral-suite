# APB Peripheral Subsystem & UVM Verification Environment

A complete, production-ready APB3/4 subsystem integrating standard microcontroller peripherals with a full UVM testbench architecture. Demonstrates modular SystemVerilog design, IP reuse, protocol checking, and constrained-random verification.

## Key Features
* **Interconnect & Controllers:** APB Decoder, Memory Controller, and Interrupt Controller.
* **Peripherals:** UART, SPI, I²C, GPIO, Timer, PWM, and Watchdog Timer.
* **IP Reuse:** Built using generic primitives (FIFOs, arbiters, registers) from [`sv-common-ip-library`](submodule/sv-common-ip-library).
* **UVM Verification Suite:** Modular UVM architecture with drivers, monitors, scoreboards, SVA protocol checkers, and functional coverage models.

## Project Structure

```
apb-peripheral-suite/
├── docs/
│   └── verification_plan.md
├── rtl/
│   ├── pkg/
│   │   └── apb_pkg.sv
│   ├── interconnect/
│   │   ├── apb_decoder.sv
│   │   └── apb_interconnect.sv
│   ├── peripherals/
│   │   ├── apb_uart.sv
│   │   ├── apb_spi.sv
│   │   ├── apb_i2c.sv
│   │   ├── apb_gpio.sv
│   │   ├── apb_timer.sv
│   │   ├── apb_pwm.sv
│   │   └── apb_wdt.sv
│   ├── controllers/
│   │   ├── apb_mem_ctrl.sv
│   │   └── apb_ictr.sv
│   └── top/
│       └── apb_subsystem_top.sv 
├── tb/
│   ├── if/
│   │   └── apb_if.sv
│   └── uvm/
│       ├── apb_agent/
│       │   ├── apb_seq_item.sv
│       │   ├── apb_driver.sv
│       │   ├── apb_monitor.sv
│       │   ├── apb_sequencer.sv
│       │   └── apb_agent.sv
│       ├── env/
│       │   ├── apb_env.sv
│       │   ├── apb_scoreboard.sv
│       │   └── apb_coverage.sv
│       ├── tests/
│       │   ├── base_test.sv
│       │   └── apb_reg_test.sv
│       └── tb_top.sv
└── Makefile 
├── submodule/
│   └── sv-common-ip-library/
└── README.md

```
