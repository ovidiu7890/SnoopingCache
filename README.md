# MMU-Based Cache Control Architecture for Multi-Core Processors

[cite_start]An advanced Memory Management Unit (MMU) designed in VHDL to manage cache coherence in multi-core environments using the **MESI Protocol** and a **Snooping** architecture[cite: 1, 9, 15]. [cite_start]This project was developed at the **Technical University of Cluj-Napoca**[cite: 4].

## 🚀 Overview

[cite_start]The system provides a robust framework for managing data exchange between main memory and local caches across three processor cores[cite: 9, 196]. [cite_start]By utilizing a special-purpose MMU, the architecture reduces latency and ensures data consistency through a hardware-level snooping agent[cite: 13, 16].

### Key Features
* [cite_start]**Protocol**: Full implementation of the **MESI** (Modified, Exclusive, Shared, Invalid) coherence protocol[cite: 15, 58].
* [cite_start]**Architecture**: 3-core system with a shared bus and a centralized Bus Arbiter[cite: 196, 396].
* [cite_start]**Coherence**: Bus snooping with an "Abort" mechanism to prevent stale data reads during Modified (M) state conflicts[cite: 16, 21, 22].
* [cite_start]**Replacement Policy**: Least Recently Used (LRU) implemented via a physical shift-register array[cite: 153, 157].
* [cite_start]**Hardware Ready**: Optimized for the **Basys 3 FPGA** and verified using **Vivado**[cite: 490, 549].

---

## 🏗️ System Architecture

[cite_start]The project consists of several modular VHDL components synchronized to manage memory traffic efficiently[cite: 429].


### Core Components
1.  [cite_start]**Cores (CPUs)**: Deterministic traffic generators controlled by an FSM to issue Read/Write requests[cite: 335].
2.  [cite_start]**L1 Cache**: Fully associative cache with 16 lines[cite: 37, 196]. [cite_start]Each line includes a 14-bit tag, 2 MESI bits, and 32 bits of data[cite: 197].
3.  [cite_start]**Cache Controller**: The "Snooping Agent" that monitors bus traffic and enforces state transitions[cite: 16, 270].
4.  [cite_start]**Bus Arbiter**: Resolves contention using a **Fixed Priority Scheme** (Core 0 > Core 1 > Core 2)[cite: 396, 400].
5.  [cite_start]**Main Memory (RAM)**: Synchronous 1-byte addressable memory with a size of $2^{16}$[cite: 183, 191].

---

## 📋 MESI State Machine & Coherence

[cite_start]The system maintains consistency by tracking four distinct states for every cache line[cite: 58]:

| State | Description |
| :--- | :--- |
| **Modified (00)** | [cite_start]Line is dirty and exists only in the current cache[cite: 60, 61, 70]. |
| **Exclusive (01)** | [cite_start]Line is clean and exists only in the current cache[cite: 63, 64, 70]. |
| **Shared (10)** | [cite_start]Line is clean and may exist in multiple caches[cite: 66, 67, 70]. |
| **Invalid (11)** | [cite_start]Line is invalid/empty[cite: 68, 69, 70]. |

### The Abort Mechanism
[cite_start]If a core requests data held by another cache in the **Modified** state, the controller asserts `o_bus_abort`[cite: 22]. [cite_start]This stops the RAM from serving stale data and forces the owner to "Flush" (write-back) the modified data to RAM first[cite: 23, 318].

---

## 🧠 Cache Management

### LRU Replacement Policy
[cite_start]To minimize conflict misses, the system uses a physical shift-register array of 16 lines[cite: 38, 158]. 
* [cite_start]**On a Hit**: The accessed line at index $k$ is saved, lines $0$ to $k-1$ shift down, and the saved line moves to Index 0 (MRU)[cite: 163, 164, 166].
* [cite_start]**On a Miss**: The entire array shifts down ($j$ moves to $j+1$), and the new data is placed at Index 0[cite: 161, 162].
* **Eviction**: If the cache is full, the line at Index 15 is pushed out. [cite_start]If it was "Modified," it is automatically written back to RAM[cite: 168, 170, 171].

---

## 🧪 Testing & Verification

### Simulation (Vivado)
[cite_start]The design was verified through 9 specific scenarios, including[cite: 490, 491]:
* [cite_start]**Cold Read Misses**[cite: 493].
* [cite_start]**Write Invalidations** (Shared $\to$ Modified)[cite: 508].
* [cite_start]**Silent Upgrades** (Exclusive $\to$ Modified)[cite: 521].
* [cite_start]**Capacity Evictions**[cite: 540].

### Hardware Emulation (Basys 3)
[cite_start]The project includes a hardware testing suite triggered by the FPGA buttons[cite: 549, 550]:
* [cite_start]**BtnU**: System Reset[cite: 553].
* [cite_start]**BtnC**: Step through the test ROM[cite: 552].
* [cite_start]**LD15**: Error Indicator (Data Mismatch)[cite: 554].
* [cite_start]**LD13-LD6**: 8-bit Data Display[cite: 555].

---

## 🛠️ Requirements
* [cite_start]**Software**: Xilinx Vivado (2019.1 or newer recommended)[cite: 490].
* [cite_start]**Hardware**: Basys 3 FPGA (Artix-7)[cite: 549].

## ✍️ Author
* [cite_start]**Ovidiu-Alexandru Lates**[cite: 2].
* [cite_start]Project for **Structure of Computers System**[cite: 3].
