# APB3/APB4 SystemVerilog Interface Specification (`apb_if`)

## 1. Architectural Overview

The `apb_if` interface encapsulates all AMBA APB3 and APB4 bus protocol signals. It serves as the physical pin bundle and timing boundary connecting the UVM Testbench (Drivers, Monitors) and the Subsystem RTL (`apb_subsystem_top`).

## 2. Interface Pinout & Signals

| Signal Name | Direction (Master perspective) |    Width    | Description                        |
| :---------- | :----------------------------: | :---------: | :--------------------------------- |
| `pclk`      |             Input              |      1      | Global APB system clock.           |
| `presetn`   |             Input              |      1      | Active-low system reset.           |
| `paddr`     |             Output             | `AddrWidth` | Address bus driven by master.      |
| `psel`      |             Output             |      1      | Slave select strobe.               |
| `penable`   |             Output             |      1      | Access phase enable strobe.        |
| `pwrite`    |             Output             |      1      | High = Write, Low = Read.          |
| `pwdata`    |             Output             | `DataWidth` | Write payload bus.                 |
| `pstrb`     |             Output             | `StrbWidth` | Byte strobe mask (APB4).           |
| `pprot`     |             Output             | `ProtWidth` | Protection descriptor (APB4).      |
| `prdata`    |             Input              | `DataWidth` | Read response data from slave.     |
| `pready`    |             Input              |      1      | Slave transfer complete handshake. |
| `pslverr`   |             Input              |      1      | Slave transfer error indicator.    |

---

## 3. Protocol SystemVerilog Assertions (SVA) Enforced

1. **`p_enable_follows_sel`**: `PENABLE` must assert exactly one cycle after `PSEL` asserts.
2. **`p_addr_stable_during_access`**: `PADDR` must remain constant throughout the `SETUP` and `ACCESS` phases until `PREADY` is asserted.
3. **`p_control_stable_during_access`**: `PWRITE`, `PSTRB`, and `PPROT` must remain unchanged across setup/access transitions.
4. **`p_wdata_stable_during_write`**: `PWDATA` must remain stable during active write access.
5. **`p_no_x_on_control`**: Control lines (`PSEL`, `PENABLE`, `PWRITE`) must never resolve to an unknown `X` or `Z` state when out of reset.
