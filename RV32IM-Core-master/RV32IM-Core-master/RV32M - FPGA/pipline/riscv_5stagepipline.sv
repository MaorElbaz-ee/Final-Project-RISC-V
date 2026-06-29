
///////////////////////////////////////////////////////////////
// Top Level Module
///////////////////////////////////////////////////////////////

module top(input  logic  clk, reset, 
           output logic [31:0] WriteData, DataAdr, 
           output logic MemWriteM);

  logic [31:0] PC, InstrF, ReadDataM;
  //logic MemWriteM;
  
  // instantiate processor and memories
  riscv_pipline riscvpipline(clk, reset, InstrF, ReadDataM, MemWriteM,
                         PC, DataAdr, WriteData);
  imem imem(PC, InstrF);
  dmem dmem(clk, MemWriteM, DataAdr, WriteData, ReadDataM);
endmodule

///////////////////////////////////////////////////////////////
// RISC-V 5 Stage Pipline
///////////////////////////////////////////////////////////////

module riscv_pipline(input  logic        clk, reset,
                     input  logic [31:0] InstrF, ReadData,
                     output logic        MemWriteM,
                     output logic [31:0] PC, ALUResult, WriteData);

  logic       ALUSrcD, RegWriteD, JumpD, JalrD, LuiD, BranchD;
  logic [1:0] ResultSrcD;
  logic [2:0] ImmSrcD;
  logic [4:0] ALUControlD;
  logic  MemWriteD;
  logic [31:0] InstrD;
  
  controller c(InstrD[31:25],
               InstrD[14:12],
               InstrD[6:0],
               MemWriteD, ALUSrcD, RegWriteD, JumpD, BranchD, JalrD, LuiD,
               ResultSrcD,
               ImmSrcD, 
               ALUControlD);
  
  datapath dp(clk, reset, 
              ALUSrcD, RegWriteD, MemWriteD, JumpD, BranchD, JalrD, LuiD,
              ResultSrcD, 
              ImmSrcD,
              ALUControlD,
              InstrF, ReadData,
              MemWriteM,
              PC, InstrD, ALUResult, WriteData);
              
endmodule

///////////////////////////////////////////////////////////////
// Controller
///////////////////////////////////////////////////////////////

module controller(input  logic [6:0] funct7,
                  input  logic [2:0] funct3,
                  input  logic [6:0] op,                  
                  output logic       MemWriteD, ALUSrcD, RegWriteD, JumpD, BranchD, JalrD, LuiD,
                  output logic [1:0] ResultSrcD,         
                  output logic [2:0] ImmSrcD,
                  output logic [4:0] ALUControlD);

  logic [1:0] ALUOp;

  maindec md(op, 
             MemWriteD, BranchD, ALUSrcD, RegWriteD, JumpD, JalrD, LuiD,
             ResultSrcD , ALUOp,
             ImmSrcD);
  aludec  ad(op[5], funct3, funct7, 
             ALUOp,  
             ALUControlD);

endmodule

///////////////////////////////////////////////////////////////
// Main Decoder
///////////////////////////////////////////////////////////////

module maindec(input  logic [6:0] op,
               output logic       MemWrite, Branch, ALUSrc, RegWrite, Jump, Jalr, Lui,
               output logic [1:0] ResultSrc, ALUOp,
               output logic [2:0] ImmSrc);

  logic [13:0] controls;

  assign {RegWrite, ImmSrc, ALUSrc, MemWrite,
          ResultSrc, Branch, ALUOp, Jump, Jalr, Lui} = controls;

  always_comb
    case(op)
    // RegWrite_ImmSrc_ALUSrc_MemWrite_ResultSrc_Branch_ALUOp_Jump_Jalr_Lui
      7'b0110011: controls = 14'b1_000_0_0_00_0_10_0_0_0; // R-type
      7'b0010011: controls = 14'b1_000_1_0_00_0_10_0_0_0; // I-type ALU
      7'b0000011: controls = 14'b1_000_1_0_01_0_00_0_0_0; // lw
      7'b0100011: controls = 14'b0_001_1_1_00_0_00_0_0_0; // sw
      7'b1100011: controls = 14'b0_010_0_0_00_1_01_0_0_0; // B-type
      7'b1101111: controls = 14'b1_011_0_0_10_0_00_1_0_0; // jal
      7'b1100111: controls = 14'b1_000_0_0_10_0_00_1_1_0; // jalr
      7'b0110111: controls = 14'b1_100_1_0_00_0_00_0_0_1; // lui
      7'b0010111: controls = 14'b1_100_0_0_11_0_00_0_0_0; // auipc
      default:    controls = 14'b0_000_0_0_00_0_00_0_0_0; // non-implemented instruction
    endcase
endmodule

///////////////////////////////////////////////////////////////
// ALU Decoder
///////////////////////////////////////////////////////////////

module aludec(input  logic       opb5,
              input  logic [2:0] funct3,
              input  logic [6:0] funct7, 
              input  logic [1:0] ALUOp,
              output logic [4:0] ALUControl);

  logic  RtypeSub, RtypeMul;
  assign RtypeSub = funct7[5] & opb5;  // TRUE for R-type subtract instruction
  assign RtypeMul = (funct7 == 7'b0000001) & opb5;  // TRUE for R-type mul/div instruction
  always_comb
    case(ALUOp)
      2'b00:                ALUControl = 5'b00000; // lw, sw, lui -> add
      2'b01:   case(funct3) // Branch 
 				 3'b000, 3'b001: ALUControl = 5'b00001; // beq, bne -> sub
				 3'b100, 3'b101: ALUControl = 5'b01000; // blt, bge -> slt
				 3'b110, 3'b111: ALUControl = 5'b01001; // bltu, bbgeu -> sltu
				 default: ALUControl = 5'b00001;
			   endcase
      default: case(funct3) // R-type or I-type ALU
                 3'b000:  if (RtypeSub) 
                            ALUControl = 5'b00001; // sub
                          else if (RtypeMul)
			    ALUControl = 5'b01010; // mul 
			  else        
                            ALUControl = 5'b00000; // add, addi
                 3'b001:  if (RtypeMul)
			    ALUControl = 5'b01011; // mulh	
			  else
			    ALUControl = 5'b00101; // sll, slli	
                 3'b010:  if (RtypeMul)
			    ALUControl = 5'b01100; // mulhsu
			  else 			     
			    ALUControl = 5'b01000; // slt, slti
                 3'b011:  if (RtypeMul)
			    ALUControl = 5'b01101; // mulhu
			  else 
			    ALUControl = 5'b01001; // sltu, sltiu
                 3'b100:  if (RtypeMul)
			    ALUControl = 5'b01110; // div
			  else 
			    ALUControl = 5'b00010; // xor, xori
                 3'b101:  if (funct7[5]) 
                            ALUControl = 5'b00111; // sra, srai
			  else if (RtypeMul)
			    ALUControl = 5'b01111; // divu
                          else          
                            ALUControl = 5'b00110; // srl, srli
                 3'b110:  if (RtypeMul)
			    ALUControl = 5'b10000; // rem
			  else 
			    ALUControl = 5'b00011; // or, ori
                 3'b111:  if (RtypeMul)
			    ALUControl = 5'b10001; // remu
			  else 
			    ALUControl = 5'b00100; // and, andi
                 default:   ALUControl = 5'b00000; // ???
               endcase
    endcase
endmodule

///////////////////////////////////////////////////////////////
// DataPath
///////////////////////////////////////////////////////////////

module datapath(input  logic        clk, reset,
                input  logic        ALUSrcD, RegWriteD, MemWriteD, JumpD, BranchD, JalrD, LuiD,
                input  logic [1:0]  ResultSrcD, 
                input  logic [2:0]  ImmSrcD,
                input  logic [4:0]  ALUControlD,
                input  logic [31:0] InstrF, ReadDataM,     
                output logic        MemWriteM,
                output logic [31:0] PCF, InstrD, ALUResultM, WriteDataM);
  
  // -------- IF Stage --------
  logic StallF;
  logic [31:0] PCNextE, PCPlus4F;
  flopre #(32) pcreg(clk, reset, StallF, PCNextE, PCF); 
  adder       pcadd4(PCF, 32'd4, PCPlus4F);
  
  // -------- IF/ID Register --------
  logic StallD, FlushD;
  logic [31:0] PCD, PCPlus4D, TempInstrD;
  if_id_stage_register if_id(clk, reset, StallD, FlushD, 
                             InstrF, PCF, PCPlus4F, 
                             TempInstrD, PCD, PCPlus4D);

  // -------- ID Stage --------
  logic [31:0] RD1D, RD2D, ImmExtD, ResultW;
  logic [2:0] Funct3D;
  logic        RegWriteW;
  logic [4:0]  RdW, RdD, Rs1D, Rs2D, Rs1D_temp, Rs2D_temp;
  regfile     rf(clk, RegWriteW, TempInstrD[19:15], TempInstrD[24:20], 
                 RdW, ResultW, RD1D, RD2D);
  extend      ext(TempInstrD[31:7], ImmSrcD, ImmExtD); 
  assign RdD = TempInstrD[11:7];
  assign Rs1D_temp = TempInstrD[19:15];
  assign Rs2D_temp = TempInstrD[24:20];
  assign InstrD = TempInstrD; 
  assign Funct3D = TempInstrD[14:12];
  
  // -------- ID/EX Register --------
  logic RegWriteE, MemWriteE, JumpE, BranchE, JalrE, LuiE, ALUSrcE, FlushE;
  logic [1:0] ResultSrcE;
  logic [2:0] Funct3E, ImmSrcE;
  logic [31:0] RD1E, RD2E, PCE, ImmExtE, PCPlus4E;
  logic [4:0] ALUControlE, RdE, Rs1E, Rs2E, Rs1E_temp, Rs2E_temp;
  id_ex_stage_register id_ex(clk, reset, FlushE,
                             RegWriteD, ResultSrcD, MemWriteD, JumpD, BranchD, JalrD, LuiD, ALUControlD, ALUSrcD,
                             RD1D, RD2D, PCD, RdD, Rs1D_temp, Rs2D_temp, ImmExtD, PCPlus4D, Funct3D, ImmSrcD,
                             RegWriteE, ResultSrcE, MemWriteE, JumpE, BranchE, JalrE, LuiE, ALUControlE, ALUSrcE,
                             RD1E, RD2E, PCE, RdE, Rs1E_temp, Rs2E_temp, ImmExtE, PCPlus4E, Funct3E, ImmSrcE); 
  // Hazard LUI/AUIPC handaling
  assign Rs1D = (ImmSrcD === 3'b100) ? 5'd0 : Rs1D_temp;
  assign Rs2D = (ImmSrcD === 3'b100) ? 5'd0 : Rs2D_temp;
  assign Rs1E = (ImmSrcE === 3'b100) ? 5'd0 : Rs1E_temp;
  assign Rs2E = (ImmSrcE === 3'b100) ? 5'd0 : Rs2E_temp;

  // Hazard Unit
  logic        RegWriteM, PCSrcE;
  logic [1:0] ForwardAE, ForwardBE;
  logic [4:0]  RdM;
  hazard_unit hz(RegWriteM, RegWriteW, ResultSrcE[0], PCSrcE, RdE, RdM, RdW, Rs1D, Rs2D, Rs1E, Rs2E,
                 StallF, StallD, FlushD, FlushE, ForwardAE, ForwardBE);
  
  // -------- EX Stage --------
  logic [31:0] SrcAE, SrcBE, WriteDataE, ALUResultE, PCTargetE, JalTargetE, JalrTargetE, Temp_JalrTargetE, SrcAE_temp, ResultM_f;
  logic ZeroE, LTE, LTUE, TakeE;

  mux3 #(32)  fMuxA(RD1E, ResultW, ResultM_f, ForwardAE, SrcAE_temp);
  assign SrcAE = LuiE ? 32'b0 : SrcAE_temp;
  mux3 #(32)  fMuxB(RD2E, ResultW, ResultM_f, ForwardBE, WriteDataE); 
  mux2 #(32)  srcbmux(WriteDataE, ImmExtE, ALUSrcE, SrcBE);
  alu         alu(SrcAE, SrcBE, ALUControlE, ALUResultE, ZeroE, LTE, LTUE);                                                      
  adder       pcaddbranch(PCE, ImmExtE, JalTargetE);
  adder       rd1addjalr(SrcAE, ImmExtE, JalrTargetE);
  assign Temp_JalrTargetE = {JalrTargetE[31:1], 1'b0};
  mux2 #(32)  targetmux(JalTargetE, Temp_JalrTargetE, JalrE, PCTargetE);
  always_comb
    case (Funct3E)
	3'b000: TakeE = ZeroE;	// beq
	3'b001: TakeE = ~ZeroE;   // bne
	3'b100: TakeE = LTE;	// blt
	3'b101: TakeE = ~LTE;	// bge
	3'b110: TakeE = LTUE;	// bltu
	3'b111: TakeE = ~LTUE;	// bgeu
	default: TakeE = 1'b0;
    endcase
  assign      PCSrcE = (BranchE & TakeE) | JumpE | JalrE;
  mux2 #(32)  pcmux(PCPlus4F, PCTargetE, PCSrcE, PCNextE);
  
  // -------- EX/MEM Register --------
  logic [1:0]  ResultSrcM;
  logic [31:0] PCPlus4M, PCTargetM;
  ex_mem_stage_register ex_mem(clk, reset,
                             RegWriteE, ResultSrcE, MemWriteE,
                             ALUResultE, WriteDataE, RdE, PCPlus4E, PCTargetE,
                             RegWriteM, ResultSrcM, MemWriteM,
                             ALUResultM, WriteDataM, RdM, PCPlus4M, PCTargetM); 
                             
  // -------- MEM Stage --------
  // externaly using dmem
     always_comb
	case (ResultSrcM)
		2'b00: ResultM_f = ALUResultM;
		2'b01: ResultM_f = ReadDataM;
		2'b10: ResultM_f = PCPlus4M;
		2'b11: ResultM_f = PCTargetM; 
		default: ResultM_f = ALUResultM;
	endcase

  // -------- MEM/WB Register --------
  
  logic [1:0]  ResultSrcW;
  logic [31:0] PCPlus4W, ReadDataW, ALUResultW, PCTargetW;
  
  mem_wb_stage_register mem_wb(clk, reset,
                             RegWriteM, ResultSrcM,
                             ALUResultM, ReadDataM, RdM, PCPlus4M, PCTargetM,
                             RegWriteW, ResultSrcW,
                             ALUResultW, ReadDataW, RdW, PCPlus4W, PCTargetW);  
 
 // -------- WB Stage --------
  mux4 #(32)  resultmux(ALUResultW, ReadDataW, PCPlus4W, PCTargetW, ResultSrcW, ResultW);
 
endmodule

///////////////////////////////////////////////////////////////
// Register File
///////////////////////////////////////////////////////////////

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

  assign rd1 = (a1 == 5'd0) ? 32'd0 :
		(we3 && (a1 == a3)) ? wd3 : rf[a1];
  assign rd2 = (a2 == 5'd0) ? 32'd0 :
		(we3 && (a2 == a3)) ? wd3 : rf[a2];
endmodule

///////////////////////////////////////////////////////////////
// Adder
///////////////////////////////////////////////////////////////

module adder(input  [31:0] a, b,
             output [31:0] y);

  assign y = a + b;
endmodule

///////////////////////////////////////////////////////////////
// Extend
///////////////////////////////////////////////////////////////

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
      default: immext = 32'b0; // undefined
    endcase             
endmodule

///////////////////////////////////////////////////////////////
// Asynchronous reset Register
///////////////////////////////////////////////////////////////

module flopr #(parameter WIDTH = 8)
              (input  logic             clk, reset,
               input  logic [WIDTH-1:0] d, 
               output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, posedge reset)
    if (reset) q <= 0;
    else       q <= d;
endmodule

///////////////////////////////////////////////////////////////
// Asynchronous reset and Synchronous enable
///////////////////////////////////////////////////////////////

module flopre #(parameter WIDTH = 8)
              (input  logic             clk, reset, en,
               input  logic [WIDTH-1:0] d, 
               output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, posedge reset)
    if (reset) q <= 0;
    else if (en) q <= q;
    else       q <= d;
endmodule

///////////////////////////////////////////////////////////////
// Asynchronous reset and Synchronous enable and Synchronous Flush Register
///////////////////////////////////////////////////////////////

module floprf #(parameter WIDTH = 8)
              (input  logic             clk, reset, flush,
               input  logic [WIDTH-1:0] d, 
               output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, posedge reset)
    if (reset) q <= 0;
    else if (flush) q <= 0;
    else       q <= d;
endmodule
///////////////////////////////////////////////////////////////
// Asynchronous reset and Synchronous enable and Synchronous Flush Register
///////////////////////////////////////////////////////////////

module flopref #(parameter WIDTH = 8)
              (input  logic             clk, reset, en, flush,
               input  logic [WIDTH-1:0] d, 
               output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, posedge reset)
    if (reset) q <= 0;
    else if (flush) q <= 0;
    else if (en) q <= q;
    else       q <= d;
endmodule

///////////////////////////////////////////////////////////////
// MUX2_1
///////////////////////////////////////////////////////////////

module mux2 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, 
              input  logic             s, 
              output logic [WIDTH-1:0] y);

  assign y = s ? d1 : d0; 
endmodule

///////////////////////////////////////////////////////////////
// MUX3_1
///////////////////////////////////////////////////////////////

module mux3 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, d2,
              input  logic [1:0]       s, 
              output logic [WIDTH-1:0] y);

  assign y = s[1] ? d2 : (s[0] ? d1 : d0); 
endmodule

///////////////////////////////////////////////////////////////
// MUX4_1
///////////////////////////////////////////////////////////////

module mux4 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, d2, d3,
              input  logic [1:0]       s, 
              output logic [WIDTH-1:0] y);

  assign y = (s == 2'b11) ? d3 :
             (s == 2'b10) ? d2 :
             (s == 2'b01) ? d1 : d0;
endmodule

///////////////////////////////////////////////////////////////
// IMEM
///////////////////////////////////////////////////////////////

module imem(input  logic [31:0] a,
            output logic [31:0] rd);

  logic [31:0] RAM[63:0];

  initial
      $readmemh("branch_test.txt",RAM);

  assign rd = RAM[a[31:2]]; // word aligned
endmodule

///////////////////////////////////////////////////////////////
// DMEM
///////////////////////////////////////////////////////////////

module dmem(input  logic        clk, we,
            input  logic [31:0] a, wd,
            output logic [31:0] rd);

  logic [31:0] RAM[63:0];

  assign rd = RAM[a[31:2]]; // word aligned

  always_ff @(posedge clk)
    if (we) RAM[a[31:2]] <= wd;
endmodule

///////////////////////////////////////////////////////////////
// ALU
///////////////////////////////////////////////////////////////

module alu(input  logic [31:0] a, b,
           input  logic [4:0]  alucontrol,
           output logic [31:0] result,
           output logic        zero, lt, ltu);

  logic [31:0] condinvb, sum;
  logic muxControl;
  logic [63:0] p_uu;
  logic signed [63:0] p_ss, p_su;
  assign muxControl = (alucontrol == 5'b01000) ? 1'b1 : alucontrol[0];
  assign condinvb = muxControl ? ~b : b;
  assign sum = a + condinvb + muxControl;
  assign p_uu = {32'b0,a}*{32'b0,b};
  assign p_ss = $signed({{32{a[31]}},a})*$signed({{32{b[31]}},b});
  assign p_su = $signed({{32{a[31]}},a})*$signed({32'b0,b});
  

  // DIV/REM functions
  // Signed DIV with corner cases
  function automatic logic [31:0] div32s(input logic signed [31:0] a,
					 input logic signed [31:0] b);

  	if (b == 0)
		div32s = 32'hffffffff;
	else if (a == 32'h80000000 && b == 32'hffffffff)
		div32s = 32'h80000000;
	else
		div32s = a / b;
  endfunction

  // UnSigned DIV
  function automatic logic [31:0] div32u(input logic  [31:0] a,
					 input logic  [31:0] b);

	div32u = (b == 0) ? 32'hffffffff : a/b;
  endfunction

  // Signed REM with corner cases
  function automatic logic [31:0] rem32s(input logic signed [31:0] a,
					 input logic signed [31:0] b);

  	if (b == 0)
		rem32s = a;
	else if (a == 32'h80000000 && b == 32'hffffffff)
		rem32s = 32'h00000000;
	else
		rem32s = a % b;
  endfunction

  // UnSigned REM
  function automatic logic [31:0] rem32u(input logic  [31:0] a,
					 input logic  [31:0] b);

	rem32u = (b == 0) ? a : a%b;
  endfunction

  always_comb
    case (alucontrol)
      5'b00000:  result = sum;       		// add
      5'b00001:  result = sum;       		// subtract
      5'b00010:  result = a ^ b;     		// xor
      5'b00011:  result = a | b;     		// or
      5'b00100:  result = a & b;     		// and
      5'b00101:  result = a << b[4:0];    	// sll
      5'b00110:  result = a >> b[4:0];    	// srl
      5'b00111:  result = $signed(a) >>> b[4:0];   	// sra
      5'b01000:  result = lt ? 32'd1 : 32'd0;   // slt
      5'b01001:  result = ltu ? 32'd1 : 32'd0;  // sltu
      5'b01010:  result = p_uu[31:0];     // mul
      5'b01011:  result = p_ss[63:32];    // mulh
      5'b01100:  result = p_su[63:32];    // mulhsu
      5'b01101:  result = p_uu[63:32];   // mulhu
      5'b01110:  result = div32s ($signed(a), $signed(b));   // div
      5'b01111:  result = div32u (a, b); // divu
      5'b10000:  result = rem32s ($signed(a), $signed(b));   // rem
      5'b10001:  result = rem32u (a, b); // remu
      default: result = 32'b0;
    endcase

  assign zero = (result == 32'b0);
  assign lt = ($signed(a) < $signed(b));
  assign ltu = (a < b);
endmodule

///////////////////////////////////////////////////////////////
// Fetch Decode Stage Register
///////////////////////////////////////////////////////////////

module if_id_stage_register #(parameter WIDTH = 32) 
		                (input  logic       clk,
    	            	 input  logic       reset,
    	            	 input  logic       StallD,
    	            	 input  logic       FlushD,
  		                 input  logic [WIDTH-1:0] InstrF,
  		                 input  logic [WIDTH-1:0] PCF,
  		                 input  logic [WIDTH-1:0] PCPlus4F,
    		             output logic [WIDTH-1:0] InstrD,
    		             output logic [WIDTH-1:0] PCD,
    		             output logic [WIDTH-1:0] PCPlus4D);		 

	flopref #(WIDTH) instr(clk, reset, StallD, FlushD, InstrF, InstrD);
	flopref #(WIDTH) pc(clk, reset, StallD, FlushD, PCF, PCD);
	flopref #(WIDTH) pcPlus4(clk, reset, StallD, FlushD, PCPlus4F, PCPlus4D);
endmodule

///////////////////////////////////////////////////////////////
// Decode Execute Stage Register
///////////////////////////////////////////////////////////////

module id_ex_stage_register #(parameter WIDTH = 32) 
		                (input  logic       clk,
    	            	 	input  logic       reset,
    	            	 	input  logic       FlushE,
    	        	    	input  logic       RegWriteD,
    	       	     		input  logic [1:0] ResultSrcD,
    	            		input  logic       MemWriteD,
    	            		input  logic       JumpD,
    	            		input  logic       BranchD,
    	            		input  logic       JalrD,
				input  logic	    LuiD,
    	            		input  logic [4:0] ALUControlD,
    	            		input  logic       ALUSrcD,
  		                input  logic [WIDTH-1:0] RD1D,
  		                input  logic [WIDTH-1:0] RD2D,
  		                input  logic [WIDTH-1:0] PCD,
  		                input  logic [4:0] RdD,
  		                input  logic [4:0] Rs1D,
  		                input  logic [4:0] Rs2D,
  		                input  logic [WIDTH-1:0] ImmExtD,
  		                input  logic [WIDTH-1:0] PCPlus4D,
  		                input  logic [2:0] Funct3D,
				input  logic [2:0] ImmSrcD,
  		                output  logic       RegWriteE,
    	            		output  logic [1:0] ResultSrcE,
    	            		output  logic       MemWriteE,
    	            		output  logic       JumpE,
    	            		output  logic       BranchE,
    	            		output  logic       JalrE,
				output  logic	     LuiE,
    	            		output  logic [4:0] ALUControlE,
    	            		output  logic       ALUSrcE,
  		       	        output  logic [WIDTH-1:0] RD1E,
  		                output  logic [WIDTH-1:0] RD2E,
  		                output  logic [WIDTH-1:0] PCE,
  		                output  logic [4:0] RdE,
  		                output  logic [4:0] Rs1E,
  		                output  logic [4:0] Rs2E,
  		                output  logic [WIDTH-1:0] ImmExtE,
  		                output  logic [WIDTH-1:0] PCPlus4E,
  		                output  logic [2:0] Funct3E,
				output  logic [2:0] ImmSrcE);		 

    // Control registers
    floprf #(1) regWrite(clk, reset, FlushE, RegWriteD, RegWriteE);
    floprf #(2) resultSrc(clk, reset, FlushE, ResultSrcD, ResultSrcE);
    floprf #(1) memWrite(clk, reset, FlushE, MemWriteD, MemWriteE);
    floprf #(1) jump(clk, reset, FlushE, JumpD, JumpE);
    floprf #(1) branch(clk, reset, FlushE, BranchD, BranchE);
    floprf #(1) jalr(clk, reset, FlushE, JalrD, JalrE);
    floprf #(1) lui(clk, reset, FlushE, LuiD, LuiE);
    floprf #(5) aluControl(clk, reset, FlushE, ALUControlD, ALUControlE);
    floprf #(1) aluSrc(clk, reset, FlushE, ALUSrcD, ALUSrcE);
    floprf #(3) immSrc(clk, reset, FlushE, ImmSrcD, ImmSrcE);
    // Datapath registers
    floprf #(WIDTH) rd1(clk, reset, FlushE, RD1D, RD1E);
    floprf #(WIDTH) rd2(clk, reset, FlushE, RD2D, RD2E);
    floprf #(WIDTH) pc(clk, reset, FlushE, PCD, PCE);
    floprf #(5) rd(clk, reset, FlushE, RdD, RdE);
    floprf #(5) rs1(clk, reset, FlushE, Rs1D, Rs1E);
    floprf #(5) rs2(clk, reset, FlushE, Rs2D, Rs2E);
    floprf #(WIDTH) immExt(clk, reset, FlushE, ImmExtD, ImmExtE);
    floprf #(WIDTH) pcPlus4(clk, reset, FlushE, PCPlus4D, PCPlus4E);
    floprf #(3) funct3(clk, reset, FlushE, Funct3D, Funct3E);
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
  		                 input  logic [WIDTH-1:0] PCTargetE,
  		                 output  logic       RegWriteM,
    	            	 output  logic [1:0] ResultSrcM,
    	            	 output  logic       MemWriteM,
  		                 output  logic [WIDTH-1:0] ALUResultM,
  		                 output  logic [WIDTH-1:0] WriteDataM,
  		                 output  logic [4:0] RdM,
  		                 output  logic [WIDTH-1:0] PCPlus4M,
  		                 output   logic [WIDTH-1:0] PCTargetM);		 
    // Control registers
    flopr #(1) regWrite(clk, reset, RegWriteE, RegWriteM);
    flopr #(2) resultSrc(clk, reset, ResultSrcE, ResultSrcM);
    flopr #(1) memWrite(clk, reset, MemWriteE, MemWriteM);
    // Datapath registers
	flopr #(WIDTH) aluResult(clk, reset, ALUResultE, ALUResultM);
	flopr #(WIDTH) writeData(clk, reset, WriteDataE, WriteDataM);
	flopr #(5) rd(clk, reset, RdE, RdM);
	flopr #(WIDTH) pcPlus4(clk, reset, PCPlus4E, PCPlus4M);
	flopr #(WIDTH) pcTarget(clk, reset, PCTargetE, PCTargetM);
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
  		                 input  logic [WIDTH-1:0] PCTargetM,
  		                 output  logic       RegWriteW,
    	            	 output  logic [1:0] ResultSrcW,
  		                 output  logic [WIDTH-1:0] ALUResultW,
  		                 output  logic [WIDTH-1:0] ReadDataW,
  		                 output  logic [4:0] RdW,
  		                 output  logic [WIDTH-1:0] PCPlus4W,
  		                 output   logic [WIDTH-1:0] PCTargetW);		 
    // Control registers
    flopr #(1) regWrite(clk, reset, RegWriteM, RegWriteW);
    flopr #(2) resultSrc(clk, reset, ResultSrcM, ResultSrcW);
    // Datapath registers
	flopr #(WIDTH) aluResult(clk, reset, ALUResultM, ALUResultW);
	flopr #(WIDTH) readData(clk, reset, ReadDataM, ReadDataW);
	flopr #(5) rd(clk, reset, RdM, RdW);
	flopr #(WIDTH) pcPlus4(clk, reset, PCPlus4M, PCPlus4W);
	flopr #(WIDTH) pcTarget(clk, reset, PCTargetM, PCTargetW);
endmodule

///////////////////////////////////////////////////////////////
// Hazard Unit
///////////////////////////////////////////////////////////////

module hazard_unit (input  logic       RegWriteM,
    	            input  logic       RegWriteW,
    	            input  logic       ResultSrcE0,
    	            input  logic       PCSrcE,
    	            input  logic [4:0] RdE,
  		            input  logic [4:0] RdM,    	            	 
   		            input  logic [4:0] RdW,
   		            input  logic [4:0] Rs1D,
                    input  logic [4:0] Rs2D,
                    input  logic [4:0] Rs1E,
                    input  logic [4:0] Rs2E,
                    output logic StallF,
                    output logic StallD,
                    output logic FlushD,
                    output logic FlushE,
   		            output logic [1:0] ForwardAE,
   		            output logic [1:0] ForwardBE);		 
    logic lwStall, dep1, dep2;   
    
    // Data and control Hazard Handaling
    always_comb begin
        // ForwardAE logic
        if ((Rs1E == RdM) && RegWriteM && (Rs1E != 5'd0))  
            ForwardAE = 2'b10;
        else if ((Rs1E == RdW) && RegWriteW && (Rs1E != 5'd0))
            ForwardAE = 2'b01;
        else
            ForwardAE = 2'b00;
        
        // ForwardBE logic
        if ((Rs2E == RdM) && RegWriteM && (Rs2E != 5'd0))
            ForwardBE = 2'b10;
        else if ((Rs2E == RdW) && RegWriteW && (Rs2E != 5'd0))
            ForwardBE = 2'b01;
        else
            ForwardBE = 2'b00;
        
        // Stalling logic (lw data dependency) + Control logic (on FlushE)
	dep1 = (Rs1D != 5'd0) && ((&(~(Rs1D ^ RdE)) == 1'b1));
	dep2 = (Rs2D != 5'd0) && ((&(~(Rs2D ^ RdE)) == 1'b1));
        lwStall = (dep1 || dep2) && (ResultSrcE0 == 1'b1);
        StallF = lwStall;
        StallD = lwStall;
        FlushE = lwStall || PCSrcE; // Check stalling (lwStall) and control (PCSrcE)
        
        // Control logic
        FlushD = PCSrcE;
    end

endmodule
