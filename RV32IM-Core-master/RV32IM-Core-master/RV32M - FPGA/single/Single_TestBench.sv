module testbench();

  logic        clk;
  logic        reset;

  logic [31:0] WriteData, DataAdr;
  logic        MemWrite;
  logic [31:0]  hash;
  logic [7:0]  an;
  logic [6:0]  seg;
  logic        dp;

  // instantiate device to be tested
  top dut(clk, reset, an, seg, dp);
  
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
      if(dut.MemWrite) begin
        if(dut.DataAdr === 100 & dut.WriteData === 50) begin
          $display("Simulation succeeded");
          #1; // wait to be sure hash is ready
 	   	  $display("hash = %h", hash);
          $stop;
        end 
	else if (dut.DataAdr !== 96) begin
          $display("Simulation failed");
          $stop;
        end
      end
    end
    
  // Make 32-bit hash of instruction, PC, ALU
  always @(negedge clk)
    if (~reset) begin
      hash = hash ^ dut.Instr ^ dut.PC;
      if (dut.MemWrite) hash = hash ^ dut.WriteData;
      hash = {hash[30:0], hash[9] ^ hash[29] ^ hash[30] ^ hash[31]};
    end

endmodule
