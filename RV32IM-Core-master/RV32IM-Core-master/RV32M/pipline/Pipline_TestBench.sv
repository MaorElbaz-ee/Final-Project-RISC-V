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
    begin      clk <= 1; # 5; clk <= 0; # 5;
    end

  wire [31:0]  pc_com = dut.riscvpipline.dp.PCPlus4W - 32'd4;
  
  wire [31:0] instrW = dut.imem.RAM[pc_com[31:2]];

  // delay M-stage signals to W-stage 
  logic memwrite_w;
  logic [31:0] dataadr_w, writedata_w;
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      memwrite_w   <= 1'b0;
      dataadr_w    <= '0;
      writedata_w  <= '0;
    end 
    else begin
      memwrite_w   <= MemWrite;          // MemWriteM -> WB-aligned
      dataadr_w    <= DataAdr;
      writedata_w  <= WriteData;
    end
  end

  wire com_valid = dut.riscvpipline.dp.RegWriteW | memwrite_w;

  // --- retire detection: new PC at WB
  logic [31:0] last_pc_w;
  logic        retire_w;

  always @(posedge clk or posedge reset) begin
    if (reset) last_pc_w <= 32'hFFFF_FFFF;   // impossible PC
    else       last_pc_w <= pc_com;          // pc_com = PCPlus4W - 4
  end

  assign retire_w = ~reset && !$isunknown(instrW) && (pc_com != last_pc_w);


  // check results
  always @(negedge clk)
    begin
      if(memwrite_w) begin
        if(dataadr_w === 100 & writedata_w === 50) begin
          $display("Simulation succeeded");
          #1; // wait to be sure hash is ready
 	   	  $display("hash = %h", hash);
          $stop;
        end 
	else if (dataadr_w !== 96) begin
          $display("Simulation failed");
          $stop;
        end
      end
    end
    
  // Make 32-bit hash of instruction, PC, ALU
  always @(negedge clk)
    if (retire_w) begin
      //if (dut.InstrF === {32{1'bx}})
      	//hash = hash;
      //else begin
      	hash = hash ^ instrW ^ pc_com;
      	if (memwrite_w) hash = hash ^ writedata_w;
      	hash = {hash[30:0], hash[9] ^ hash[29] ^ hash[30] ^ hash[31]};
      //end
    end

endmodule
