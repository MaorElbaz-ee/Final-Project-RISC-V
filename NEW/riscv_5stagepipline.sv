// riscvsingle.sv

// RISC-V single-cycle processor
// From Section 7.6 of Digital Design & Computer Architecture
// 27 April 2020
// David_Harris@hmc.edu 
// Sarah.Harris@unlv.edu

// run 210
// Expect simulator to print "Simulation succeeded"
// when the value 25 (0x19) is written to address 100 (0x64)

// Single-cycle implementation of RISC-V (RV32I)
// User-level Instruction Set Architecture V2.2 (May 7, 2017)
// Implements a subset of the base integer instructions:
//    lw, sw
//    add, sub, and, or, slt, 
//    addi, andi, ori, slti
//    beq
//    jal
// Exceptions, traps, and interrupts not implemented
// little-endian memory

// 31 32-bit registers x1-x31, x0 hardwired to 0
// R-Type instructions
//   add, sub, and, or, slt
//   INSTR rd, rs1, rs2
//   Instr[31:25] = funct7 (funct7b5 & opb5 = 1 for sub, 0 for others)
//   Instr[24:20] = rs2
//   Instr[19:15] = rs1
//   Instr[14:12] = funct3
//   Instr[11:7]  = rd
//   Instr[6:0]   = opcode
// I-Type Instructions
//   lw, I-type ALU (addi, andi, ori, slti)
//   lw:         INSTR rd, imm(rs1)
//   I-type ALU: INSTR rd, rs1, imm (12-bit signed)
//   Instr[31:20] = imm[11:0]
//   Instr[24:20] = rs2
//   Instr[19:15] = rs1
//   Instr[14:12] = funct3
//   Instr[11:7]  = rd
//   Instr[6:0]   = opcode
// S-Type Instruction
//   sw rs2, imm(rs1) (store rs2 into address specified by rs1 + immm)
//   Instr[31:25] = imm[11:5] (offset[11:5])
//   Instr[24:20] = rs2 (src)
//   Instr[19:15] = rs1 (base)
//   Instr[14:12] = funct3
//   Instr[11:7]  = imm[4:0]  (offset[4:0])
//   Instr[6:0]   = opcode
// B-Type Instruction
//   beq rs1, rs2, imm (PCTarget = PC + (signed imm x 2))
//   Instr[31:25] = imm[12], imm[10:5]
//   Instr[24:20] = rs2
//   Instr[19:15] = rs1
//   Instr[14:12] = funct3
//   Instr[11:7]  = imm[4:1], imm[11]
//   Instr[6:0]   = opcode
// J-Type Instruction
//   jal rd, imm  (signed imm is multiplied by 2 and added to PC, rd = PC+4)
//   Instr[31:12] = imm[20], imm[10:1], imm[11], imm[19:12]
//   Instr[11:7]  = rd
//   Instr[6:0]   = opcode

//   Instruction  opcode    funct3    funct7
//   add          0110011   000       0000000
//   sub          0110011   000       0100000
//   and          0110011   111       0000000
//   or           0110011   110       0000000
//   slt          0110011   010       0000000
//   addi         0010011   000       immediate
//   andi         0010011   111       immediate
//   ori          0010011   110       immediate
//   slti         0010011   010       immediate
//   beq          1100011   000       immediate
//   lw	          0000011   010       immediate
//   sw           0100011   010       immediate
//   jal          1101111   immediate immediate

module testbench();

  logic        clk;
  logic        reset;

  logic [31:0] WriteData, DataAdr;
  logic        MemWrite;
  logic [31:0]  hash;

  // instantiate device to be tested
  top dut(clk, reset, WriteData, DataAdr, MemWrite);
  
  // initialize test
  initial
    begin
      hash <= 0;
      reset <= 1; # 22; reset <= 0;
    end

  // generate clock to sequence tests
  always
    begin
      clk <= 1; # 5; clk <= 0; # 5;
    end

  // check results
  always @(negedge clk)
    begin
      if(MemWrite) begin
        if(DataAdr === 100 & WriteData === 50) begin
          $display("Simulation succeeded");
          #1; // wait to be sure hash is ready
 	   	  $display("hash = %h", hash);
          $stop;
        end else if (DataAdr !== 96) begin
          $display("Simulation failed");
          $stop;
        end
      end
    end
    
  // Make 32-bit hash of instruction, PC, ALU
  always @(negedge clk)
    if (~reset) begin
      hash = hash ^ dut.Instr ^ dut.PC;
      if (MemWrite) hash = hash ^ WriteData;
      hash = {hash[30:0], hash[9] ^ hash[29] ^ hash[30] ^ hash[31]};
    end

endmodule

module top(input  logic        clk, reset, 
           output logic [31:0] WriteData, DataAdr, 
           output logic        MemWrite);

  logic [31:0] PC, Instr, ReadData;
  
  // instantiate processor and memories
  riscvsingle rvsingle(clk, reset, PC, Instr, MemWrite, DataAdr, 
                       WriteData, ReadData);
  imem imem(PC, Instr);
  dmem dmem(clk, MemWrite, DataAdr, WriteData, ReadData);
endmodule

module riscvsingle(input  logic        clk, reset,
                   output logic [31:0] PC,
                   input  logic [31:0] Instr,
                   output logic        MemWrite,
                   output logic [31:0] ALUResult, WriteData,
                   input  logic [31:0] ReadData);

  logic       ALUSrc, RegWrite, Jump, Zero;
  logic [1:0] ResultSrc;
  logic [2:0] ImmSrc;
  logic [3:0] ALUControl;

  controller c(Instr[6:0], Instr[14:12], Instr[30], Zero,
               ResultSrc, MemWrite, PCSrc,
               ALUSrc, RegWrite, Jump,
               ImmSrc, ALUControl);
  datapath dp(clk, reset, ResultSrc, PCSrc,
              ALUSrc, RegWrite,
              ImmSrc, ALUControl,
              Zero, PC, Instr,
              ALUResult, WriteData, ReadData);
endmodule

module controller(input  logic [6:0] op,
                  input  logic [2:0] funct3,
                  input  logic       funct7b5,
                  input  logic       Zero,
                  output logic [1:0] ResultSrc,
                  output logic       MemWrite,
                  output logic       PCSrc, ALUSrc,
                  output logic       RegWrite, Jump,
                  output logic [2:0] ImmSrc,
                  output logic [3:0] ALUControl);

  logic [1:0] ALUOp;
  logic       Branch;

  maindec md(op, ResultSrc, MemWrite, Branch,
             ALUSrc, RegWrite, Jump, ImmSrc, ALUOp);
  aludec  ad(op[5], funct3, funct7b5, ALUOp, ALUControl);

  assign PCSrc = Branch & Zero | Jump;
endmodule

module maindec(input  logic [6:0] op,
               output logic [1:0] ResultSrc,
               output logic       MemWrite,
               output logic       Branch, ALUSrc,
               output logic       RegWrite, Jump,
               output logic [2:0] ImmSrc,
               output logic [1:0] ALUOp);

  logic [11:0] controls;

  assign {RegWrite, ImmSrc, ALUSrc, MemWrite,
          ResultSrc, Branch, ALUOp, Jump} = controls;

  always_comb
    case(op)
    // RegWrite_ImmSrc_ALUSrc_MemWrite_ResultSrc_Branch_ALUOp_Jump
      7'b0110011: controls = 12'b1_xxx_0_0_00_0_10_0; // R-type
      7'b0010011: controls = 12'b1_000_1_0_00_0_10_0; // I-type ALU
      7'b0000011: controls = 12'b1_000_1_0_01_0_00_0; // lw
      7'b0100011: controls = 12'b0_001_1_1_xx_0_00_0; // sw
      7'b1100011: controls = 12'b0_010_0_0_xx_1_01_0; // B-type
      7'b1101111: controls = 12'b1_011_x_0_10_0_xx_1; // jal
      7'b1100111: controls = 12'b1_000_1_0_10_0_10_1; // jalr
      7'b0110111: controls = 12'b1_100_1_0_00_0_00_0; // lui
      7'b0010111: controls = 12'b1_100_x_0_11_0_xx_0; // auipc
      default:    controls = 12'bx_xxx_x_x_xx_x_xx_x; // non-implemented instruction
    endcase
endmodule

module aludec(input  logic       opb5,
              input  logic [2:0] funct3,
              input  logic       funct7b5, 
              input  logic [1:0] ALUOp,
              output logic [3:0] ALUControl);

  logic  RtypeSub;
  assign RtypeSub = funct7b5 & opb5;  // TRUE for R-type subtract instruction

  always_comb
    case(ALUOp)
      2'b00:                ALUControl = 4'b0000; // lw, sw, lui
      2'b01:                ALUControl = 4'b0001; // B-Type sub
      default: case(funct3) // R-type or I-type ALU
                 3'b000:  if (RtypeSub) 
                            ALUControl = 4'b0001; // sub
                          else          
                            ALUControl = 4'b0000; // add, addi
                 3'b001:    ALUControl = 4'b0101; // sll, slli
                 3'b010:    ALUControl = 4'b1000; // slt, slti
                 3'b011:    ALUControl = 4'b1001; // sltu, sltiu
                 3'b100:    ALUControl = 4'b0010; // xor, xori
                 3'b101:  if (RtypeSub) 
                            ALUControl = 4'b0111; // sra, srai
                          else          
                            ALUControl = 4'b0110; // srl, srli
                 3'b110:    ALUControl = 4'b0011; // or, ori
                 3'b111:    ALUControl = 4'b0100; // and, andi
                 default:   ALUControl = 4'bxxxx; // ???
               endcase
    endcase
endmodule

module datapath(input  logic        clk, reset,
                input  logic [1:0]  ResultSrc, 
                input  logic        PCSrc, ALUSrc,
                input  logic        RegWrite,
                input  logic [2:0]  ImmSrc,
                input  logic [3:0]  ALUControl,
                output logic        Zero,
                output logic [31:0] PCF,
                input  logic [31:0] Instr,
                output logic [31:0] ALUResult, WriteData,
                input  logic [31:0] ReadData);

  logic [31:0] PCNext, PCPlus4, PCTarget;
  logic [31:0] ImmExt;
  logic [31:0] SrcA, SrcB;
  logic [31:0] Result;
  
  // -------- IF Stage --------
  // next PC logic
  logic [31:0] PCNext, PCPlus4;
  flopr #(32) pcreg(clk, reset, PCNext, PCF); 
  adder       pcadd4(PCF, 32'd4, PCPlus4);
  
  // -------- IF/ID Register --------
  
  if_id_stage_register if_id(clk, reset, Instr, PCF, PCPlus4);

  adder       pcaddbranch(PC, ImmExt, PCTarget);
  mux2 #(32)  pcmux(PCPlus4, PCTarget, PCSrc, PCNext);
 
  // register file logic
  regfile     rf(clk, RegWrite, Instr[19:15], Instr[24:20], 
                 Instr[11:7], Result, SrcA, WriteData);
  extend      ext(Instr[31:7], ImmSrc, ImmExt);

  // ALU logic
  mux2 #(32)  srcbmux(WriteData, ImmExt, ALUSrc, SrcB);
  alu         alu(SrcA, SrcB, ALUControl, ALUResult, Zero);
  mux4 #(32)  resultmux(ALUResult, ReadData, PCPlus4, PCTarget, ResultSrc, Result);
endmodule

module regfile(input  logic        clk, 
               input  logic        we3, 
               input  logic [ 4:0] a1, a2, a3, 
               input  logic [31:0] wd3, 
               output logic [31:0] rd1, rd2);

  logic [31:0] rf[31:0];

  // three ported register file
  // read two ports combinationally (A1/RD1, A2/RD2)
  // write third port on rising edge of clock (A3/WD3/WE3)
  // register 0 hardwired to 0

  always_ff @(posedge clk)
    if (we3) rf[a3] <= wd3;	

  assign rd1 = (a1 != 0) ? rf[a1] : 0;
  assign rd2 = (a2 != 0) ? rf[a2] : 0;
endmodule

module adder(input  [31:0] a, b,
             output [31:0] y);

  assign y = a + b;
endmodule

module extend(input  logic [31:7] instr,
              input  logic [2:0]  immsrc,
              output logic [31:0] immext);
 
  always_comb
    case(immsrc) 
               // I-type 
      3'b000:   immext = {{20{instr[31]}}, instr[31:20]};  
               // S-type (stores)
      3'b001:   immext = {{20{instr[31]}}, instr[31:25], instr[11:7]}; 
               // B-type (branches)
      3'b010:   immext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; 
               // J-type (jal)
      3'b011:   immext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
               // lui, auipc
      3'b100:   immext = {instr[31:12], 12'b0};
      default: immext = 32'bx; // undefined
    endcase             
endmodule

module flopr #(parameter WIDTH = 8)
              (input  logic             clk, reset,
               input  logic [WIDTH-1:0] d, 
               output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, posedge reset)
    if (reset) q <= 0;
    else       q <= d;
endmodule

module mux2 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, 
              input  logic             s, 
              output logic [WIDTH-1:0] y);

  assign y = s ? d1 : d0; 
endmodule

module mux3 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, d2,
              input  logic [1:0]       s, 
              output logic [WIDTH-1:0] y);

  assign y = s[1] ? d2 : (s[0] ? d1 : d0); 
endmodule

module mux4 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, d2, d3,
              input  logic [1:0]       s, 
              output logic [WIDTH-1:0] y);

  assign y = (s == 2'b11) ? d3 :
             (s == 2'b10) ? d2 :
             (s == 2'b01) ? d1 : d0;
endmodule

module imem(input  logic [31:0] a,
            output logic [31:0] rd);

  logic [31:0] RAM[63:0];

  initial
      $readmemh("riscvtest_sll.txt",RAM);

  assign rd = RAM[a[31:2]]; // word aligned
endmodule

module dmem(input  logic        clk, we,
            input  logic [31:0] a, wd,
            output logic [31:0] rd);

  logic [31:0] RAM[63:0];

  assign rd = RAM[a[31:2]]; // word aligned

  always_ff @(posedge clk)
    if (we) RAM[a[31:2]] <= wd;
endmodule

module alu(input  logic [31:0] a, b,
           input  logic [3:0]  alucontrol,
           output logic [31:0] result,
           output logic        zero);

  logic [31:0] condinvb, sum;

  assign condinvb = alucontrol[0] ? ~b : b;
  assign sum = a + condinvb + alucontrol[0];

  always_comb
    case (alucontrol)
      4'b0000:  result = sum;       // add
      4'b0001:  result = sum;       // subtract
      4'b0010:  result = a ^ b;     // xor
      4'b0011:  result = a | b;     // or
      4'b0100:  result = a & b;     // and
      4'b0101:  result = a << b[4:0];    // sll
      4'b0110:  result = a >> b[4:0];    // srl
      4'b0111:  result = a >>> b[4:0];   // sra
      4'b1000:  result = sum[31];   // slt
      4'b1001:  result = (a < b) ? 32'd1 : 32'd0; //sltu
      default: result = 32'bx;
    endcase

  assign zero = (result == 32'b0);
endmodule

///////////////////////////////////////////////////////////////
// Fetch Decode Stage Register
///////////////////////////////////////////////////////////////
module if_id_stage_register #(parameter WIDTH = 32) 
		                (input  logic       clk,
    	            	 input  logic       reset,
  		                 input  logic [WIDTH-1:0] InstrF,
  		                 input  logic [WIDTH-1:0] PCF,
  		                 input  logic [WIDTH-1:0] PCPlus4F,
    		             output logic [WIDTH-1:0] InstrD,
    		             output logic [WIDTH-1:0] PCD,
    		             output logic [WIDTH-1:0] PCPlus4D);		 

	flopr #(WIDTH) instr(clk, reset, InstrF, InstrD);
	flopr #(WIDTH) pc(clk, reset, PCF, PCD);
	flopr #(WIDTH) pcPlus4(clk, reset, PCPlus4F, PCPlus4D);
endmodule

///////////////////////////////////////////////////////////////
// Decode Execute Stage Register
///////////////////////////////////////////////////////////////
module id_ex_stage_register #(parameter WIDTH = 32) 
		                (input  logic       clk,
    	            	 input  logic       reset,
    	            	 input  logic       RegWriteD,
    	            	 input  logic [1:0] ResultSrcD,
    	            	 input  logic       MemWriteD,
    	            	 input  logic       JumpD,
    	            	 input  logic       BranchD,
    	            	 input  logic [3:0] ALUControlD,
    	            	 input  logic       ALUSrcD,
  		                 input  logic [WIDTH-1:0] RD1D,
  		                 input  logic [WIDTH-1:0] RD2D,
  		                 input  logic [WIDTH-1:0] PCD,
  		                 input  logic [4:0] RdD,
  		                 input  logic [WIDTH-1:0] ImmExtD,
  		                 input  logic [WIDTH-1:0] PCPlus4D,
  		                 output  logic       RegWriteE,
    	            	 output  logic [1:0] ResultSrcE,
    	            	 output  logic       MemWriteE,
    	            	 output  logic       JumpE,
    	            	 output  logic       BranchE,
    	            	 output  logic [3:0] ALUControlE,
    	            	 output  logic       ALUSrcE,
  		                 output  logic [WIDTH-1:0] RD1E,
  		                 output  logic [WIDTH-1:0] RD2E,
  		                 output  logic [WIDTH-1:0] PCE,
  		                 output  logic [4:0] RdE,
  		                 output  logic [WIDTH-1:0] ImmExtE,
  		                 output  logic [WIDTH-1:0] PCPlus4E);		 

    // Control registers
    flopr #(1) regWrite(clk, reset, RegWriteD, RegWriteE);
    flopr #(2) resultSrc(clk, reset, ResultSrcD, ResultSrcE);
    flopr #(1) memWrite(clk, reset, MemWriteD, MemWriteE);
    flopr #(1) jump(clk, reset, JumpD, JumpE);
    flopr #(1) branch(clk, reset, BranchD, BranchE);
    flopr #(4) aluControl(clk, reset, ALUControlD, ALUControlE);
    flopr #(1) aluSrc(clk, reset, ALUSrcD, ALUSrcE);
    // Datapath registers
	flopr #(WIDTH) rd1(clk, reset, RD1D, RD1E);
	flopr #(WIDTH) rd2(clk, reset, RD2D, RD2E);
	flopr #(WIDTH) pc(clk, reset, PCD, PCE);
	flopr #(5) rd(clk, reset, RdD, RdE);
	flopr #(WIDTH) immExt(clk, reset, ImmExtD, ImmExtE);
	flopr #(WIDTH) pcPlus4(clk, reset, PCPlus4D, PCPlus4E);
endmodule

///////////////////////////////////////////////////////////////
// Execute Memory Stage Register
///////////////////////////////////////////////////////////////
module ex_mem_stage_register #(parameter WIDTH = 32) 
		                (input  logic       clk,
    	            	 input  logic       reset,
    	            	 input  logic       RegWriteE,
    	            	 input  logic [1:0] ResultSrcE,
    	            	 input  logic       MemWriteE,
  		                 input  logic [WIDTH-1:0] ALUResultE,
  		                 input  logic [WIDTH-1:0] WriteDataE,
  		                 input  logic [4:0] RdE,
  		                 input  logic [WIDTH-1:0] PCPlus4E,
  		                 output  logic       RegWriteM,
    	            	 output  logic [1:0] ResultSrcM,
    	            	 output  logic       MemWriteM,
  		                 output  logic [WIDTH-1:0] ALUResultM,
  		                 output  logic [WIDTH-1:0] WriteDataM,
  		                 output  logic [4:0] RdM,
  		                 output  logic [WIDTH-1:0] PCPlus4M);		 
    // Control registers
    flopr #(1) regWrite(clk, reset, RegWriteE, RegWriteM);
    flopr #(2) resultSrc(clk, reset, ResultSrcE, ResultSrcM);
    flopr #(1) memWrite(clk, reset, MemWriteE, MemWriteM);
    // Datapath registers
	flopr #(WIDTH) aluResult(clk, reset, ALUResultE, ALUResultM);
	flopr #(WIDTH) writeData(clk, reset, WriteDataE, WriteDataM);
	flopr #(5) rd(clk, reset, RdE, RdM);
	flopr #(WIDTH) pcPlus4(clk, reset, PCPlus4E, PCPlus4M);
endmodule

///////////////////////////////////////////////////////////////
// Memory Write Stage Register
///////////////////////////////////////////////////////////////
module mem_wb_stage_register #(parameter WIDTH = 32) 
		                (input  logic       clk,
    	            	 input  logic       reset,
    	            	 input  logic       RegWriteM,
    	            	 input  logic [1:0] ResultSrcM,
  		                 input  logic [WIDTH-1:0] ALUResultM,
  		                 input  logic [WIDTH-1:0] ReadDataM,
  		                 input  logic [4:0] RdM,
  		                 input  logic [WIDTH-1:0] PCPlus4M,
  		                 output  logic       RegWriteW,
    	            	 output  logic [1:0] ResultSrcW,
  		                 output  logic [WIDTH-1:0] ALUResultW,
  		                 output  logic [WIDTH-1:0] ReadDataW,
  		                 output  logic [4:0] RdW,
  		                 output  logic [WIDTH-1:0] PCPlus4W);		 
    // Control registers
    flopr #(1) regWrite(clk, reset, RegWriteM, RegWriteW);
    flopr #(2) resultSrc(clk, reset, ResultSrcM, ResultSrcW);
    // Datapath registers
	flopr #(WIDTH) aluResult(clk, reset, ALUResultM, ALUResultW);
	flopr #(WIDTH) readData(clk, reset, ReadDataM, ReadDataW);
	flopr #(5) rd(clk, reset, RdM, RdW);
	flopr #(WIDTH) pcPlus4(clk, reset, PCPlus4M, PCPlus4W);
endmodule