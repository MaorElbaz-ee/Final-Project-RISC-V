// lab10_starter.sv

typedef enum logic[6:0] {r_type_op=7'b0110011, i_type_alu_op=7'b0010011, lw_op=7'b0000011, sw_op=7'b0100011, beq_op=7'b1100011, jal_op=7'b1101111} opcodetype;
typedef enum logic [3:0] {s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10} statetype;


///////////////////////////////////////////////////////////////
// testbench
//
// Expect simulator to print "Simulation succeeded"
// when the value 25 (0x19) is written to address 100 (0x64)
///////////////////////////////////////////////////////////////

module testbench();

  logic        clk;
  logic        reset;

  logic [31:0] WriteData, DataAdr;
  logic        MemWrite;
  logic [31:0] hash;

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
        if(DataAdr === 44 & WriteData === 8) begin
          $display("Simulation succeeded");
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
      hash = hash ^ dut.rvmulti.dp.Instr ^ dut.rvmulti.dp.PC;
      if (MemWrite) hash = hash ^ WriteData;
      hash = {hash[30:0], hash[9] ^ hash[29] ^ hash[30] ^ hash[31]};
    end

endmodule

///////////////////////////////////////////////////////////////
// top
//
// Instantiates multicycle RISC-V processor and memory
///////////////////////////////////////////////////////////////

module top(input  logic        clk, reset, 
           output logic [31:0] WriteData, DataAdr, 
           output logic        MemWrite);

  logic [31:0] ReadData;
  
  // instantiate processor and memories
  riscvmulti rvmulti(clk, reset, MemWrite, DataAdr, 
                     WriteData, ReadData);
  mem mem(clk, MemWrite, DataAdr, WriteData, ReadData);
endmodule

///////////////////////////////////////////////////////////////
// mem
//
// Single-ported RAM with read and write ports
// Initialized with machine language program
///////////////////////////////////////////////////////////////

module mem(input  logic        clk, we,
           input  logic [31:0] a, wd,
           output logic [31:0] rd);

  logic [31:0] RAM[63:0];
  
  initial
      $readmemh("riscvtest.txt",RAM);

  assign rd = RAM[a[31:2]]; // word aligned

  always_ff @(posedge clk)
    if (we) RAM[a[31:2]] <= wd;
endmodule

///////////////////////////////////////////////////////////////
// riscvmulti
//
// Multicycle RISC-V microprocessor
///////////////////////////////////////////////////////////////

module riscvmulti(input  logic        clk, reset,
                  output logic        MemWrite,
                  output logic [31:0] Adr, WriteData,
                  input  logic [31:0] ReadData);

  // Your code goes here
  // Instantiate controller (from lab 5) and datapath (new for this lab)
	
	// internal variables
	logic AdrSrc, IRWrite, PCWrite, RegWrite, Zero, MemWriteIn;
	logic [1:0] ImmSrc, ALUSrcA, ALUSrcB, ResultSrc;
	logic [2:0] ALUControl;
	logic [31:0] Instr;
	opcodetype  op;
	assign op = opcodetype'(Instr[6:0]);
	logic [6:0] op2;
	assign op2 = Instr[6:0];

	controller c(clk, reset, op, Instr[14:12], Instr[30], Zero, ImmSrc, ALUSrcA, ALUSrcB, 
		     ResultSrc, AdrSrc, ALUControl, IRWrite, PCWrite, RegWrite, MemWriteIn);
	datapath   dp(clk, reset, ImmSrc, ALUSrcA, ALUSrcB, ResultSrc, AdrSrc, ALUControl, IRWrite, PCWrite, RegWrite, MemWriteIn, ReadData, Zero, Adr, WriteData, Instr);
	
	
	assign MemWrite = MemWriteIn;
endmodule

///////////////////////////////////////////////////////////////
// Your modules go here
///////////////////////////////////////////////////////////////

// Describe your non-leaf cells structurally
// Describe your lef cells (mux, flop, alu, etc.) behaviorally
// Exactly follow the multicycle processor diagram
// Feel free to cut and paste from riscvsingle.sv where applicable
// Remember to declare internal signals
// Be consistent with spelling and capitalization
// Be consistent with order of signals in module declarations and instantiations
// Have fun!


///////////////////////////////////////////////////////////////
// controller
///////////////////////////////////////////////////////////////
module controller(input  logic       clk,
                  input  logic       reset,  
                  input  opcodetype  op,
                  input  logic [2:0] funct3,
                  input  logic       funct7b5,
                  input  logic       Zero,
                  output logic [1:0] ImmSrc,
                  output logic [1:0] ALUSrcA, ALUSrcB,
                  output logic [1:0] ResultSrc, 
                  output logic       AdrSrc,
                  output logic [2:0] ALUControl,
                  output logic       IRWrite, PCWrite, 
                  output logic       RegWrite, MemWrite);
	
	// internal variables
	logic PCUpdate, Branch;
	logic [1:0] ALUOp;

	// instantiate Main FSM
	mainfsm mfsm(clk, reset, op, ALUSrcA, ALUSrcB, ResultSrc, AdrSrc, IRWrite, RegWrite, MemWrite, PCUpdate, Branch, ALUOp);

	// instantiate ALU Decoder
	aludecoder aludec(ALUOp, funct3, op[5], funct7b5, ALUControl);

	//output logic
	//assign PCWrite = (Zero&Branch)|PCUpdate;
	assign PCWrite =  ((op == beq_op && Zero) || (op == beq_op && funct3 == 3'b001 && !Zero)) || PCUpdate;
	always_comb
		case(op)
			r_type_op: ImmSrc = 2'b00;
			i_type_alu_op: ImmSrc = 2'b00;
			lw_op: ImmSrc = 2'b00;
			sw_op: ImmSrc = 2'b01;
			beq_op: ImmSrc = 2'b10;
			jal_op: ImmSrc = 2'b11;
		endcase

endmodule

module mainfsm(input logic clk, reset, 
	       input opcodetype op,
               output logic [1:0] ALUSrcA, ALUSrcB,
               output logic [1:0] ResultSrc, 
               output logic       AdrSrc,
               output logic       IRWrite, 
               output logic       RegWrite, MemWrite,
	       output logic PCUpdate, Branch,
	       output logic [1:0] ALUOp);
	
	// internal variables  
	statetype state,nextstate;

	// instantiate resettable flip-flops
	flopr ff(clk, reset, nextstate, state);
	
	// next state logic
	always_comb
		case(state)
			s0:					      nextstate = s1;
			s1:	if (op == lw_op) 		      nextstate = s2;
				else if (op ==  lw_op || op == sw_op) nextstate = s2;
				else if (op == r_type_op) 	      nextstate = s6;
				else if (op == i_type_alu_op) 	      nextstate = s8;
				else if (op == jal_op)		      nextstate = s9;
				else if (op == beq_op)		      nextstate = s10;
			s2:	if (op == lw_op) 		      nextstate = s3;
				else if (op == sw_op) 		      nextstate = s5;
			s3:					      nextstate = s4;
			s4:					      nextstate = s0;
			s5:					      nextstate = s0;
			s6:					      nextstate = s7;
			s7:					      nextstate = s0;
			s8:					      nextstate = s7;
			s9:					      nextstate = s7;
			s10:					      nextstate = s0;
			default:				      nextstate = s0;
		endcase

	// output logic
	always_comb begin
                ALUSrcA = 2'b00;
	 	ALUSrcB = 2'b00;                  		 
		ResultSrc = 2'b00; 
       		AdrSrc = 1'b0;
		ALUOp = 2'b00;
                IRWrite = 1'b0;
                RegWrite = 1'b0; 
		MemWrite = 1'b0;
		PCUpdate =  1'b0;
		Branch = 1'b0;
		case(state)
			s0: begin
			 	ALUSrcB = 2'b10;                  		 
				ResultSrc = 2'b10; 
                  		IRWrite = 1'b1;
				PCUpdate =  1'b1;
			end
			s1: begin
                  		ALUSrcA = 2'b01;
			 	ALUSrcB = 2'b01; 
                 	end
			s2: begin
                  		ALUSrcA = 2'b10;
			 	ALUSrcB = 2'b01;
			end
			s3: begin 
                  		AdrSrc = 1'b1;
			end
			s4: begin                		 
				ResultSrc = 2'b01; 
                  		RegWrite = 1'b1;
			end
			s5: begin
                  		AdrSrc = 1'b1;
				MemWrite = 1'b1;
			end
			s6: begin
                  		ALUSrcA = 2'b10;
				ALUOp = 2'b10;
			end
			s7: begin
                  		RegWrite = 1'b1; 
			end 
			s8: begin
                  		ALUSrcA = 2'b10;
			 	ALUSrcB = 2'b01;                  		 
				ALUOp = 2'b10;
			end
			s9: begin
                  		ALUSrcA = 2'b01;
			 	ALUSrcB = 2'b10;                  		 
				PCUpdate =  1'b1;
			end
			s10: begin
                  		ALUSrcA = 2'b10;
				ALUOp = 2'b01;
				Branch = 1'b1;
			end
			default: begin
                  		ALUSrcA = 2'b00;
			 	ALUSrcB = 2'b10;                  		 
				ResultSrc = 2'b10; 
                  		AdrSrc = 1'b0;
				ALUOp = 2'b00;
                  		IRWrite = 1'b1;
                  		RegWrite = 1'b0; 
				MemWrite = 1'b0;
				PCUpdate =  1'b1;
				Branch = 1'b0;
			end
		endcase
	end
endmodule

module aludecoder(input  logic [1:0] ALUOp,
                  input  logic [2:0] funct3,
                  input  logic op_5, funct7_5,
                  output logic [2:0] ALUControl);

	// internal variables  
	logic a1, a2, a3, o1;
	logic notA1, notA0, notF2, notF1, notF0;

	not nA1(notA1, ALUOp[1]);
	not nA0(notA0, ALUOp[0]);
	not nF2(notF2, funct3[2]);
	not nF1(notF1, funct3[1]);
	not nF0(notF0, funct3[0]);
	
	// output logic
	and c2(ALUControl[2], ALUOp[1], notA0, notF2, funct3[1], notF0);
	and c1(ALUControl[1], ALUOp[1], notA0, funct3[2], funct3[1]);
	and a11(a1, notF2, notF1, op_5, funct7_5);
	or o11(o1 ,a1, funct3[1]);
	and a22(a2, ALUOp[1], notA0, notF0, o1);
	and a33(a3, notA1, ALUOp[0]);
	or c0(ALUControl[0], a3, a2);

endmodule


///////////////////////////////////////////////////////////////
// datapath
///////////////////////////////////////////////////////////////
module datapath(input  logic        clk, reset,
		input logic [1:0]   ImmSrc,
                input logic [1:0]   ALUSrcA, ALUSrcB,
                input logic [1:0]   ResultSrc, 
                input logic         AdrSrc,
                input logic [2:0]   ALUControl,
                input logic         IRWrite, PCWrite, 
                input logic         RegWrite, MemWrite,
		input  logic [31:0] ReadData,
                output logic        Zero,
                output logic [31:0] Adr, WriteData,
		output logic [31:0] Instr);
	
	// internal variables
	logic [31:0] Result, PC, OldPC, RD1, RD2, A, SrcA, SrcB, ALUResult, ALUOut, ImmExt, Data, InstrIn, WriteDataIn;

	//  pre instr/data memory logic
	//floprr #(32) pcreg(clk, reset, Result, PC);
	flopenr #(32) pcreg(clk, reset, PCWrite, Result, PC);
	mux2   #(32) adrmux(PC, Result, AdrSrc, Adr);

	//pre register file logic
	flopenr_2 #(32) mulbit_enr1(clk, reset, IRWrite, PC, ReadData, OldPC, InstrIn);
	floprr 	  #(32) datareg(clk, reset, ReadData, Data);
	regfile   rf(clk, RegWrite, InstrIn[19:15], InstrIn[24:20], 
                 InstrIn[11:7], Result, RD1, RD2);
  	extend    ext(InstrIn[31:7], ImmSrc, ImmExt);
	assign 	  Instr = InstrIn;
	
	// pre ALU logic
	floprr_2 #(32) nulbit_rr1(clk, reset, RD1, RD2, A, WriteDataIn);
	mux3 	 #(32) srcamux(PC, OldPC, A, ALUSrcA, SrcA);
	mux3	 #(32) srcbmux(WriteDataIn, ImmExt, 32'b100, ALUSrcB, SrcB);
	alu      alu(SrcA, SrcB, ALUControl, ALUResult, Zero);
	assign   WriteData = WriteDataIn;

	// post ALU logic
	floprr #(32) aluoutreg(clk, reset, ALUResult, ALUOut);
	mux3   #(32) resultmux(ALUOut, Data, ALUResult, ResultSrc, Result);
endmodule

///////////////////////////////////////////////////////////////
// register file
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

  assign rd1 = (a1 != 0) ? rf[a1] : 0;
  assign rd2 = (a2 != 0) ? rf[a2] : 0;
endmodule

///////////////////////////////////////////////////////////////
// extand
///////////////////////////////////////////////////////////////
module extend(input  logic [31:7] instr,
              input  logic [1:0]  immsrc,
              output logic [31:0] immext);
 
  always_comb
    case(immsrc) 
      // I-type 
      2'b00:   immext = {{20{instr[31]}}, instr[31:20]};  
      // S-type (stores)
      2'b01:   immext = {{20{instr[31]}}, instr[31:25], instr[11:7]}; 
      // B-type (branches)
      2'b10:   immext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; 
      // J-type (jal)
      2'b11:   immext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}; 
      default: immext = 32'bx; // undefined
    endcase             
endmodule

///////////////////////////////////////////////////////////////
// ALU
///////////////////////////////////////////////////////////////
module alu(input  logic [31:0] a, b,
           input  logic [2:0]  alucontrol,
           output logic [31:0] result,
           output logic        zero);

  logic [31:0] condinvb, sum;

  assign condinvb = alucontrol[0] ? ~b : b;
  assign sum = a + condinvb + alucontrol[0];

  always_comb
    case (alucontrol)
      3'b000:  result = sum;       // add
      3'b001:  result = sum;       // subtract
      3'b010:  result = a & b;     // and
      3'b011:  result = a | b;     // or
      3'b100:  result = a << b;    // sll
      3'b101:  result = sum[31];   // slt
      default: result = 32'bx;
    endcase

  assign zero = (result == 32'b0);
endmodule

// asynchronously resettable flip-flop for FSM
module flopr(input  logic clk, reset,
	     input statetype nextstate,
             output statetype state);
            
  always_ff @(posedge clk or posedge reset)
    if (reset) state <= s0; // resets state to 0 on reset
    else       state <= nextstate;

endmodule

// asynchronously resettable flip-flop, defult size 8
module floprr #(parameter WIDTH = 8)
              (input  logic             clk, reset,
               input  logic [WIDTH-1:0] d, 
               output logic [WIDTH-1:0] q);

  always_ff @(posedge clk, posedge reset)
    if (reset) q <= 0;
    else       q <= d;
endmodule

// asynchronously resettable, enabled flip-flop
module flopenr #(parameter WIDTH = 8)
		(input  logic       clk,
    		 input  logic       reset,
   		 input  logic       enable,
  		 input  logic [WIDTH-1:0] d,
    		 output logic [WIDTH-1:0] q);

  always_ff @(posedge clk or posedge reset)
    if (reset)
      q <= 0;            // asynchronous reset
    else if (enable)
      q <= d;     // state updates only when enabled

endmodule

// multi bit asynchronously resettable, enabled flip-flop
module flopenr_2 #(parameter WIDTH = 8) 
		  (input  logic       clk,
    		   input  logic       reset,
   		   input  logic       enable,
  		   input  logic [WIDTH-1:0] in1,
  		   input  logic [WIDTH-1:0] in2,
    		   output logic [WIDTH-1:0] out1,
    		   output logic [WIDTH-1:0] out2);		 

	flopenr #(WIDTH) ffen1(clk, reset, enable, in1, out1);
	flopenr #(WIDTH) ffen2(clk, reset, enable, in2, out2);
endmodule

// multi bit asynchronously resettable flip-flop
module floprr_2 #(parameter WIDTH = 8) 
		 (input  logic       clk,
    		  input  logic       reset,
  		  input  logic [WIDTH-1:0] in1,
  		  input  logic [WIDTH-1:0] in2,
    		  output logic [WIDTH-1:0] out1,
    		  output logic [WIDTH-1:0] out2);		 

	floprr #(WIDTH) ffrr1(clk, reset, in1, out1);
	floprr #(WIDTH) ffrr2(clk, reset, in2, out2);
endmodule

// mux2 deafult size 8
module mux2 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, 
              input  logic             s, 
              output logic [WIDTH-1:0] y);

  assign y = s ? d1 : d0; 
endmodule

// mux3 deafult size 8
module mux3 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, d2,
              input  logic [1:0]       s, 
              output logic [WIDTH-1:0] y);

  assign y = s[1] ? d2 : (s[0] ? d1 : d0); 
endmodule