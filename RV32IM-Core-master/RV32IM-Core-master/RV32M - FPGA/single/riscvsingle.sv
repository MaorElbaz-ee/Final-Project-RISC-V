

module top(input  logic        clk, reset, 
           output logic [7:0]  an,
           output logic [6:0]  seg,
           output logic        dp);

  logic [31:0] PC, Instr, ReadData;
  logic [31:0] WriteData, DataAdr, hash, hash_xor, next_hash, hash_if; 
  logic        MemWrite, tick_0p5s;
  
  
  
  // sync + invert to active-high inside the  design
  logic rst1, rst2, reset_n;
  always_ff @(posedge clk or negedge reset) begin
    if (!reset) {rst2,rst1} <= 2'b11;
    else        {rst2,rst1} <= {rst1,1'b0};
  end
  assign reset_n = rst2;
  
  slow_clock_0p5s half_sec_clk(clk, reset_n, tick_0p5s);
  
  // instantiate processor and memories
  riscvsingle rvsingle(tick_0p5s, reset_n, PC, Instr, MemWrite, DataAdr, 
                       WriteData, ReadData);
  //imem imem(PC, Instr);
  imem_FPGA imem(tick_0p5s, PC, Instr);
  dmem dmem(tick_0p5s, MemWrite, DataAdr, WriteData, ReadData);
  
  logic [31:0] PC_q, PC_d1, Instr_q, ALU_q, WriteData_q;
  logic        MemWrite_q;
  always_ff @(negedge tick_0p5s) begin
  if (reset_n) begin
    PC_q    <= 32'd0;
    PC_d1   <= 32'd0;
    Instr_q <= 32'd0;
    MemWrite_q <= 32'd0;
    WriteData_q <= 32'd0;
  end else begin
    PC_q    <= PC;        // current PC
    PC_d1   <= PC_q;
    Instr_q <= Instr;     // instruction fetched with PC_(n-1)
    MemWrite_q <= MemWrite;
    WriteData_q <= WriteData;
  end
end
  always_comb begin
  // combine sources (include WriteData only when MemWrite)
    hash_xor  = hash ^ Instr_q ^ PC_d1;
    if (MemWrite_q) 
        hash_if = hash_xor ^ WriteData_q;
    else
        hash_if = hash_xor;
  // LFSR-like next state from the *combined* value
    next_hash = {hash_if[30:0], hash_if[9] ^ hash_if[29] ^ hash_if[30] ^ hash_if[31]};
  end
  
 // Make 32-bit hash of instruction, PC
  always_ff @(negedge tick_0p5s) begin
    if (reset_n) 
      hash <= 32'h0000_0000;
    else 
      hash <= next_hash;
   end
  logic [31:0] value = 32'hFEDC_BA98;
  logic [7:0] an_drv;
  logic       dp_drv;
  seven_Seg_Driver sevenSeg(clk, reset_n, hash, seg, dp_drv, an_drv);
  
  /*logic [27:0] hb;
  always_ff @(posedge tick_0p5s) begin
    if (reset) hb <= '0;
    else     hb <= hb + 1;
  end*/
  assign an =  an_drv; //| {7'b0000000, hb[27]};
  assign dp =  dp_drv; //| hb[27]; 
endmodule

module riscvsingle(input  logic        clk, reset,
                   output logic [31:0] PC,
                   input  logic [31:0] Instr,
                   output logic        MemWrite,
                   output logic [31:0] ALUResult, WriteData,
                   input  logic [31:0] ReadData);

  logic       ALUSrc, RegWrite, Jump, Jalr, Zero, LT, LTU;
  logic [1:0] ResultSrc;
  logic [2:0] ImmSrc;
  logic [4:0] ALUControl;

  controller c(Instr[6:0], Instr[14:12], Instr[31:25], Zero, LT, LTU,
               ResultSrc, MemWrite, PCSrc,
               ALUSrc, RegWrite, Jump, Jalr, Lui,
               ImmSrc, ALUControl);
  datapath dp(clk, reset, ResultSrc, PCSrc,
              ALUSrc, RegWrite,
              ImmSrc, ALUControl,
              Zero, LT, LTU, PC, Instr,
              ALUResult, WriteData, ReadData, Jalr, Lui);
endmodule

module controller(input  logic [6:0] op,
                  input  logic [2:0] funct3,
                  input  logic [6:0]  funct7,
                  input  logic       Zero, LT, LTU,
                  output logic [1:0] ResultSrc,
                  output logic       MemWrite,
                  output logic       PCSrc, ALUSrc,
                  output logic       RegWrite, Jump, Jalr, Lui,
                  output logic [2:0] ImmSrc,
                  output logic [4:0] ALUControl);

  logic [1:0] ALUOp;
  logic       Branch, Take;

  maindec md(op, ResultSrc, MemWrite, Branch,
             ALUSrc, RegWrite, Jump, Jalr, Lui, ImmSrc, ALUOp);
  aludec  ad(op[5], funct3, funct7, ALUOp, ALUControl);

  always_comb
    case (funct3)
	3'b000: Take = Zero;	// beq
	3'b001: Take = ~Zero;   // bne
	3'b100: Take = LT;	// blt
	3'b101: Take = ~LT;	// bge
	3'b110: Take = LTU;	// bltu
	3'b111: Take = ~LTU;	// bgeu
	default: Take = 1'b0;
    endcase;

  assign PCSrc = Branch & Take | Jump | Jalr;
endmodule

module maindec(input  logic [6:0] op,
               output logic [1:0] ResultSrc,
               output logic       MemWrite,
               output logic       Branch, ALUSrc,
               output logic       RegWrite, Jump, Jalr, Lui,
               output logic [2:0] ImmSrc,
               output logic [1:0] ALUOp);

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
      default:    controls = 14'b0_000_0_0_0_0_0_0_0_0; // non-implemented instruction
    endcase
endmodule

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

module datapath(input  logic        clk, reset,
                input  logic [1:0]  ResultSrc, 
                input  logic        PCSrc, ALUSrc,
                input  logic        RegWrite,
                input  logic [2:0]  ImmSrc,
                input  logic [4:0]  ALUControl,
                output logic        Zero, LT, LTU,
                output logic [31:0] PC,
                input  logic [31:0] Instr,
                output logic [31:0] ALUResult, WriteData,
                input  logic [31:0] ReadData,
		input  logic	    Jalr, Lui);

  logic [31:0] PCNext, PCPlus4, PCTarget, JalrTarget, Temp_JalrTarget, JTarget;
  logic [31:0] ImmExt;
  logic [31:0] SrcA, SrcB, tempA;
  logic [31:0] Result;

  // next PC logic
  flopr #(32) pcreg(clk, reset, PCNext, PC); 
  adder       pcadd4(PC, 32'd4, PCPlus4);
  adder       pcaddbranch(PC, ImmExt, PCTarget);
  adder	      rd1addjalr(SrcA, ImmExt, JalrTarget);
  assign Temp_JalrTarget = {JalrTarget[31:1], 1'b0};
  mux2 #(32)  targetmux(PCTarget, Temp_JalrTarget, Jalr, JTarget);
  mux2 #(32)  pcmux(PCPlus4, JTarget, PCSrc, PCNext);
  // register file logic
  regfile     rf(clk, RegWrite, Instr[19:15], Instr[24:20], 
                 Instr[11:7], Result, tempA, WriteData);
  extend      ext(Instr[31:7], ImmSrc, ImmExt);
  
  assign SrcA = Lui ? 32'b0 : tempA;
  // ALU logic
  mux2 #(32)  srcbmux(WriteData, ImmExt, ALUSrc, SrcB);
  alu         alu(SrcA, SrcB, ALUControl, ALUResult, Zero, LT, LTU);
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
      default: immext = 32'b0; // undefined
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
      $readmemh("branch_test.txt",RAM);

  assign rd = RAM[a[31:2]]; // word aligned
endmodule

module imem_FPGA #(parameter AW = 10)
                (input  logic clk,
                 input  logic [31:0] a,
                 output logic [31:0] rd);

  (* ram_style="block" *) logic [31:0] ROM[0:(1<<AW)-1]; // Forcing block RAM

  initial $readmemh("prog.mem",ROM); // Preload the Program
  
  // Synchronus read
  always_ff @(posedge clk)
    rd <= ROM[a[AW+1:2]]; // word aligned
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

// ======================================================
// 8×7-segment display driver (common-anode, active-LOW)
// Board: Nexys A7 (100 MHz clk)
// seg[0]..seg[6] = a..g (active-LOW), dp active-LOW
// an[0]..an[7] = digit enables (active-LOW)
// ======================================================
module seven_Seg_Driver (
    input  logic        clk,     // 100 MHz
    input  logic        rst,     // async or sync (משמש כאן כסינכרוני)
    input  logic [31:0] hex32,   // 8 ניבלים להצגה: [31:28] ... [3:0]

    output logic [6:0]  seg,     // a..g (active-LOW)
    output logic        dp,      // decimal point (active-LOW)
    output logic [7:0]  an       // digit enables (active-LOW)
);

    // --------------------------------------------------
    // מחלק שעון: נשתמש בביטים [16:14] לבחירת ספרה
    // 100 MHz / 2^(14) ≈ 6103 Hz "טיקט ספרה"  ⇒ ~763 Hz לכל ספרה (8 ספרות)
    // --------------------------------------------------
    logic [23:0] cnt;
    always_ff @(posedge clk) begin
        if (rst) cnt <= '0;
        else     cnt <= cnt + 24'd1;
    end

    logic [2:0] digit_sel;
    assign digit_sel = cnt[16:14];

    // --------------------------------------------------
    // בחירת הניבל המתאים לפי הספרה הפעילה
    // --------------------------------------------------
    logic [3:0] nibble;
    always_comb begin
        unique case (digit_sel)
            3'd0: nibble = hex32[ 3: 0];
            3'd1: nibble = hex32[ 7: 4];
            3'd2: nibble = hex32[11: 8];
            3'd3: nibble = hex32[15:12];
            3'd4: nibble = hex32[19:16];
            3'd5: nibble = hex32[23:20];
            3'd6: nibble = hex32[27:24];
            default: nibble = hex32[31:28];
        endcase
    end

    // --------------------------------------------------
    // מקודד HEX -> 7-SEG (a..g), אקטיבי-נמוך
    //              g f e d c b a  (לנוחות מוצג כשמאל→ימין)
    // seg = {a..g} לפי המיפוי שלך: seg[0]=a, ... seg[6]=g
    // כאן נחזיר בפועל וקטור a..g בסדר seg[6:0] = {g,f,e,d,c,b,a}
    // --------------------------------------------------
    function automatic logic [6:0] hex_to_7seg_n (input logic [3:0] h);
        // "דלוק" = 0, "כבוי" = 1
        // תבניות מסונכרנות לגרסאות אקטיביות-נמוכות
        unique case (h)
             4'h0: hex_to_7seg_n = 7'b1000000; // 0
             4'h1: hex_to_7seg_n = 7'b1111001; // 1
             4'h2: hex_to_7seg_n = 7'b0100100; // 2
             4'h3: hex_to_7seg_n = 7'b0110000; // 3
             4'h4: hex_to_7seg_n = 7'b0011001; // 4
             4'h5: hex_to_7seg_n = 7'b0010010; // 5
             4'h6: hex_to_7seg_n = 7'b0000010; // 6
             4'h7: hex_to_7seg_n = 7'b1111000; // 7
             4'h8: hex_to_7seg_n = 7'b0000000; // 8
             4'h9: hex_to_7seg_n = 7'b0010000; // 9
             4'hA: hex_to_7seg_n = 7'b0001000; // A
             4'hB: hex_to_7seg_n = 7'b0000011; // b
             4'hC: hex_to_7seg_n = 7'b1000110; // C
             4'hD: hex_to_7seg_n = 7'b0100001; // d
             4'hE: hex_to_7seg_n = 7'b0000110; // E
             default: hex_to_7seg_n = 7'b0001110; // F
        endcase
    endfunction

    // פלטי הסגמנטים (a..g) אקטיבי-נמוך
    always_comb begin
        seg = hex_to_7seg_n(nibble);
    end

    // נקודה עשרונית כבויה כברירת מחדל (אקטיבי-נמוך)
    // אם תרצה להדליק נקודה בספרה מסוימת, החלף לפי digit_sel
    always_comb begin
        dp = 1'b1;
        // דוגמה: להדליק dp רק בספרה 3
        // dp = (digit_sel == 3'd3) ? 1'b0 : 1'b1;
    end

    // --------------------------------------------------
    // אנודות (active-LOW): מפעילים ספרה אחת בכל רגע
    // --------------------------------------------------
    always_comb begin
        unique case (digit_sel)
            3'd0: an = 8'b1111_1110; // ספרה 0 פעילה
            3'd1: an = 8'b1111_1101;
            3'd2: an = 8'b1111_1011;
            3'd3: an = 8'b1111_0111;
            3'd4: an = 8'b1110_1111;
            3'd5: an = 8'b1101_1111;
            3'd6: an = 8'b1011_1111;
            default: an = 8'b0111_1111; // ספרה 7 פעילה
        endcase
    end

endmodule

module slow_clock_0p5s(
    input  logic clk_100mhz,
    input  logic reset,
    output logic tick_0p5s
);
    localparam int DIV_MAX = 50_000_000 - 1; // 0.5 s at 100 MHz
    logic [25:0] counter;

    always_ff @(posedge clk_100mhz or posedge reset) begin
        if (reset) begin
            counter   <= 0;
            tick_0p5s <= 0;
        end else if (counter == DIV_MAX) begin
            counter   <= 0;
            tick_0p5s <= 1;
        end else begin
            counter   <= counter + 1;
            tick_0p5s <= 0;
        end
    end
endmodule