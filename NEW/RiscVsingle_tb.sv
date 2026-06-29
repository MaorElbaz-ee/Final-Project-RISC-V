
`timescale 1ns/1ps

//============================================================
// TB for ALU
//============================================================
module tb_alu;
  logic [31:0] a, b, result;
  logic [3:0]  alucontrol;
  logic zero;

  alu dut(a, b, alucontrol, result, zero);

  initial begin
    // ADD
    a=10; b=5; alucontrol=4'b0000; #1;
    assert(result==15) else $fatal("ALU ADD failed");

    // SUB
    alucontrol=4'b0001; #1;
    assert(result==5) else $fatal("ALU SUB failed");

    // AND
    alucontrol=4'b0100; #1;
    assert(result==(10&5)) else $fatal("ALU AND failed");

    // OR
    alucontrol=4'b0011; #1;
    assert(result==(10|5)) else $fatal("ALU OR failed");

    // XOR
    alucontrol=4'b0010; #1;
    assert(result==(10^5)) else $fatal("ALU XOR failed");

    // SLL
    a=1; b=3; alucontrol=4'b0101; #1;
    assert(result==8) else $fatal("ALU SLL failed");

    // SRL
    a=32'h80; b=4; alucontrol=4'b0110; #1;
    assert(result==8) else $fatal("ALU SRL failed");

    // SRA
    a=32'hFFFF_FF80; b=4; alucontrol=4'b0111; #1;
    assert(result==32'hFFFF_FFF8) else $fatal("ALU SRA failed");

    // SLT
    a=-5; b=3; alucontrol=4'b1000; #1;
    assert(result==1) else $fatal("ALU SLT failed");

    // SLTU
    a=32'hFFFF_FFFF; b=1; alucontrol=4'b1001; #1;
    assert(result==0) else $fatal("ALU SLTU failed");

    $display("ALU tests passed");
    $finish;
  end
endmodule

//============================================================
// TB for Register File
//============================================================
module tb_regfile;
  logic clk;
  logic we3;
  logic [4:0] a1,a2,a3;
  logic [31:0] wd3, rd1, rd2;

  regfile dut(clk, we3, a1, a2, a3, wd3, rd1, rd2);

  always #5 clk = ~clk;

  initial begin
    clk=0; we3=0; wd3=0; a1=0; a2=0; a3=0;
    #10;

    // Write x1=123
    we3=1; a3=5'd1; wd3=32'd123; @(posedge clk);
    we3=0;

    // Read x1
    a1=5'd1; #1;
    assert(rd1==123) else $fatal("Regfile write/read failed");

    // Check x0 always zero
    a1=5'd0; #1;
    assert(rd1==0) else $fatal("Regfile x0 check failed");

    $display("Register file tests passed");
    $finish;
  end
endmodule

//============================================================
// TB for Immediate Extension
//============================================================
module tb_extend;
  logic [31:7] instr;
  logic [2:0] immsrc;
  logic [31:0] immext;

  extend dut(instr, immsrc, immext);

  initial begin
    // I-type: imm = -1
    instr = 25'hFFF000; immsrc=3'b000; #1;
    assert(immext==32'hFFFFF000) else $fatal("Extend I-type failed");

    // S-type
    instr = {7'b1010101,5'd0,5'd0,3'b010,5'b10101}; immsrc=3'b001; #1;
    assert(immext[11:0]==12'b101010110101) else $fatal("Extend S-type failed");

    $display("Immediate extension tests passed");
    $finish;
  end
endmodule

//============================================================
// TB for Adder
//============================================================
module tb_adder;
  logic [31:0] a, b, y;

  adder dut(a, b, y);

  initial begin
    a=10; b=5; #1;
    assert(y==15) else $fatal("Adder failed");
    $display("Adder test passed");
    $finish;
  end
endmodule

//============================================================
// TB for Multiplexers
//============================================================
module tb_muxes;
  logic [31:0] d0,d1,d2,d3,y;
  logic s;
  logic [1:0] sel;

  mux2 #(32) m2(d0,d1,s,y);
  mux3 #(32) m3(d0,d1,d2,sel,y);
  mux4 #(32) m4(d0,d1,d2,d3,sel,y);

  initial begin
    d0=1; d1=2; d2=3; d3=4;

    // mux2
    s=0; #1; assert(y==1) else $fatal("mux2 failed sel=0");
    s=1; #1; assert(y==2) else $fatal("mux2 failed sel=1");

    // mux3
    sel=0; #1; assert(y==1);
    sel=1; #1; assert(y==2);
    sel=2; #1; assert(y==3);

    // mux4
    sel=0; #1; assert(y==1);
    sel=1; #1; assert(y==2);
    sel=2; #1; assert(y==3);
    sel=3; #1; assert(y==4);

    $display("Mux tests passed");
    $finish;
  end
endmodule

//============================================================
// TB for Controller (maindec + aludec)
//============================================================
module tb_controller;
  logic [6:0] op;
  logic [2:0] funct3;
  logic funct7b5;
  logic Zero;
  logic [1:0] ResultSrc;
  logic MemWrite, PCSrc, ALUSrc, RegWrite, Jump;
  logic [2:0] ImmSrc;
  logic [3:0] ALUControl;

  controller dut(op,funct3,funct7b5,Zero,
                 ResultSrc,MemWrite,PCSrc,
                 ALUSrc,RegWrite,Jump,
                 ImmSrc,ALUControl);

  initial begin
    // Example: ADD (R-type)
    op=7'b0110011; funct3=3'b000; funct7b5=0; Zero=0; #1;
    assert(RegWrite==1) else $fatal("Controller R-type RegWrite failed");
    assert(ALUControl==4'b0000) else $fatal("Controller ADD decode failed");

    // Example: SUB (R-type)
    funct7b5=1; #1;
    assert(ALUControl==4'b0001) else $fatal("Controller SUB decode failed");

    // Example: LW
    op=7'b0000011; funct3=3'b010; funct7b5=0; #1;
    assert(ResultSrc==2'b01) else $fatal("Controller LW decode failed");

    // Example: SW
    op=7'b0100011; funct3=3'b010; #1;
    assert(MemWrite==1) else $fatal("Controller SW decode failed");

    $display("Controller tests passed");
    $finish;
  end
endmodule

//============================================================
// TB for Full CPU Integration
//============================================================
module tb_cpu_full;
  logic clk, reset;
  logic [31:0] WriteData, DataAdr;
  logic MemWrite;

  top dut(clk, reset, WriteData, DataAdr, MemWrite);

  always #5 clk = ~clk;

  initial begin
    clk=0; reset=1;

    // preload program into instruction memory
    // Example program covering several instructions
    dut.imem.RAM[0] = 32'h00500093; // addi x1,x0,5
    dut.imem.RAM[1] = 32'h00a00113; // addi x2,x0,10
    dut.imem.RAM[2] = 32'h002081b3; // add  x3,x1,x2
    dut.imem.RAM[3] = 32'h00302023; // sw   x3,0(x0)
    dut.imem.RAM[4] = 32'h00002583; // lw   x11,0(x0)
    dut.imem.RAM[5] = 32'h0000006f; // jal x0,0 (loop)

    #10 reset=0;
    repeat(30) @(posedge clk);

    // check expected results
    assert(dut.dmem.RAM[0]==15) else $fatal("SW/LW failed");
    assert(dut.dp.rf.rf[11]==15) else $fatal("LW result wrong");

    $display("Full CPU integration test passed");
    $finish;
  end
endmodule