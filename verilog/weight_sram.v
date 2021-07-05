module weight_sram(
  input clk,
  input wen,
  input [15:0] addr,
  input signed [31:0] d,
  output [31:0] q
);

parameter delay = 0;
reg signed [7:0] ram [0:65535];
reg [15:0] read_addr;

integer i, j, k, l;
integer weight_file;
integer index;

  initial begin
    // Read the input weight csv and load the weight
    weight_file = $fopen(`WEIGHT_SOURCE, "r");
    $display(">> Reading the kernel file: %s", `WEIGHT_SOURCE);
      	for(i=0; i < `kernel_H ; i= i+1) begin
          	for(j=0; j < `kernel_W ; j= j+1) begin
				index = ((i*`kernel_W) + j);
				$fscanf(weight_file,"%d", ram[index]);
				//$display("READING Weight: [%d]: %d\n", index, ram[index]);
          	end
      	end
    $fclose(weight_file);
  end

  always @(posedge clk) begin
    if (wen == 1)
      ram[addr] <= d;
    read_addr <= addr;
  end

  assign #delay q = {ram[read_addr+3], ram[read_addr+2], ram[read_addr+1], ram[read_addr]};

endmodule
