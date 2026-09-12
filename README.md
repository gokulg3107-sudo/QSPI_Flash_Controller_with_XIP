# QSPI Flash Controller with Execute-In-Place (XIP)

A SystemVerilog/Verilog RTL implementation of a QSPI NOR Flash Controller supporting both **Indirect/APB access** and **Execute-In-Place (XIP) through AHB-Lite**.

The design targets the **Macronix MX25U6432FM2I02 QSPI NOR Flash** behavioral model and includes clock-domain crossing, asynchronous FIFOs, QSPI transaction sequencing, an XIP prefetch buffer, and a self-checking verification environment.

---

## Features

- APB3-based indirect flash access
- AHB-Lite based Execute-In-Place (XIP) access
- QSPI 1/2/4-wire transaction support
- Generic opcode-blind QSPI phase sequencer
- Configurable opcode, address, dummy cycles, mode and data phases
- PCLK-to-SCLK clock-domain crossing
- Toggle-based request synchronizer
- Dual-clock asynchronous FIFOs
- 256-byte TX FIFO
- 32-byte RX FIFO
- 16-byte XIP prefetch/cache line
- Cache invalidation following overlapping APB program/erase operations
- Autonomous XIP RDSR polling
- Autonomous QIOR line refill
- APB priority over XIP when both paths contend for the QSPI engine
- Self-checking simulation testbench
- Macronix MX25U6432FM2I02 behavioral flash model

---

## Architecture

The controller provides two independent software/hardware access paths to the flash.

### 1. Indirect / APB Path

The APB interface provides a programmer-visible register bank.

Firmware programs:

- Command/opcode
- Flash address
- Dummy-cycle configuration
- Transfer length
- Transfer configuration
- Mode byte
- TX FIFO data

The firmware then asserts the start control bit.

The command/configuration crosses from the AMBA clock domain into the QSPI SCLK domain through `domain_crossing.v`.

The QSPI controller then generates the required serial transaction and communicates with the behavioral flash model.

Supported indirect operations include:

- WREN
- Page Program
- Sector Erase
- Block Erase
- Write Status Register
- Read Status Register
- Read JEDEC ID
- FAST READ
- Dual Output Read
- Dual I/O Read
- Quad Output Read
- Quad I/O Read
- Quad Input Page Program

---

### 2. XIP / AHB-Lite Path

The XIP path allows an AHB-Lite master to access flash contents using memory-mapped addresses.

Only the requested address is presented to the XIP path.

The AHB slave first checks the 16-byte prefetch buffer.

#### Cache hit

If the requested address is present in the cache line:

```text
AHB Master
    |
    v
AHB Slave
    |
    v
Prefetch Buffer
    |
    v
AHB Read Data
