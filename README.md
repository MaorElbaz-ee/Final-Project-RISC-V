
# RISC-V CPU Core Project

Here you will find all the information needed for creating a RISC-V CPU core.  
You can find the .tlv file and the final diagram of the RISC-V core in the reposetory.  
The project was coded on the [MakerChip IDE by by Redwood EDA, LLC](https://www.makerchip.com)

## What I learned
As part of course: [LinuxFoundationX: Building a RISC-V CPU Core](https://www.edx.org/learn/design/the-linux-foundation-building-a-risc-v-cpu-core?index=product&queryId=3bb6d06bc63ec3feadaba0c9b3e1fe3d&position=1&correlationId=8718e6dc-c2fc-477f-babd-8de18aefee40), I had to implement a RISC-V CPU core using TL-Verilog.  
As the course progressed I learned about the the RV32I and the different parts of the RISC-V core.  

for any question you can conact me on: maorelbaz90@gmail.com

## RISC-V base instruction formats showing immediate variants
RISC-V instructions may provide the following fields:

<ins>**opcode**</ins> - Provides a general classification of the instruction and determines which of the remaining fields are needed, and how they are laid out, or encoded, in the remaining instruction bits.  

<ins>**function field (funct3/funct7)**</ins> - Specifies the exact function performed by the instruction, if not fully specified by the opcode.  

<ins>**rs1/rs2**</ins> - The indices (0-31) identifying the register(s) in the register file containing the source operand values on which the instruction operates.  

<ins>**rd**</ins> - The index (0-31) of the register into which the instruction’s result is written.  

<ins>**immediate**</ins> - A value contained within the instruction bits themselves. This value may provide an offset for indexing into memory or a value upon which to operate (in place of the register value indexed by rs2).  

![RISC-V base instruction formats](RISC-V-CPU-Core-main/RISC-V-CPU-Core-main/Images/RISC-V%20base%20instruction%20formats%20showing%20immediate%20variants.png)


## RISC-V CPU Block Diagram

<ins>1. PC Logic</ins> - This logic is responsible for the program counter (PC). The PC identifies the instruction our CPU will execute next. Most instructions execute sequentially, meaning the default behavior of the PC is to increment to the following instruction each clock cycle. Branch and jump instructions, however, are non-sequential. They specify a target instruction to execute next, and the PC logic must update the PC accordingly.


<ins>2. Fetch</ins> - The instruction memory (IMem) holds the instructions to execute. To read the IMem, or "fetch", we simply pull out the instruction pointed to by the PC.


<ins>3. Decode Logic</ins> - Now that we have an instruction to execute, we must interpret, or decode, it. We must break it into fields based on its type. These fields would tell us which registers to read, which operation to perform, etc.


<ins>4. Register File Read</ins> - The register file is a small local storage of values the program is actively working with. We decoded the instruction to determine which registers we need to operate on. Now, we need to read those registers from the register file.


<ins>5. Arithmetic Logic Unit (ALU)</ins> - Now that we have the register values, it’s time to operate on them. This is the job of the ALU. It will add, subtract, multiply, shift, etc, based on the operation specified in the instruction.


<ins>6. Register File Write</ins> - Now the result value from the ALU can be written back to the destination register specified in the instruction.


<ins>7. DMem</ins> -Our test program executes entirely out of the register file and does not require a data memory (DMem). But no CPU is complete without one. The DMem is written to by store instructions and read from by load instructions.

![RISC-V CPU Block Diagram](RISC-V-CPU-Core-main/RISC-V-CPU-Core-main/Images/RISC-V%20CPU%20Block%20Diagram.png)

## Image of the core

![RISC-V Core](RISC-V-CPU-Core-main/RISC-V-CPU-Core-main/Images/RISCV%20-%20project.png)
