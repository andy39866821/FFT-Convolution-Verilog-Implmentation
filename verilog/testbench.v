
`define OUTPUT_LOG      "out_log.txt"
`define FSDB_FILE       "filter.fsdb"
`define FSDB_SYN_FILE   "filter_syn.fsdb"
`timescale 1ns/1ps


`define INPUT_SOURCE    "data/input.csv"
`define WEIGHT_SOURCE   "data/weight.csv"
`define OUTPUT_GOLDEN   "data/golden.csv"


// Input
`define input_H 64
`define input_W 64
// Output
`define output_H 62
`define output_W 62

// FFT Input
`define FFT_input_H 8
`define FFT_input_W 8
// FFT Output
`define FFT_output_H 6
`define FFT_output_W 6
// Kernel
`define kernel_H 3
`define kernel_W 3


module testbench (
    output reg clk,
    output reg rst_n,
    output reg valid,
    input wire Ready,
    input [15:0] input_addr,
    output signed [31:0] input_rdata,
    input [15:0] weight_addr,
    output signed [31:0] weight_rdata,
    input output_wen,
    input [15:0] output_addr,
    input signed [31:0] output_rdata,
    input signed [31:0] output_wdata
);


integer output_file, golden_file;
integer i,j,k,l, index;

reg signed [7:0] temp_data[0:65535];
reg signed [31:0] golden[0:65535];

parameter period = 40;
parameter delay = 10;

reg allow_error = 1;
reg signed [31:0]error_val = 3;

`ifdef SYNTHESIS
    input_sram  #(.delay(`MEM_DELAY)) input_ram(.clk(clk),.wen(1'b0),.addr(input_addr),.d(32'h0),.q(input_rdata));
    weight_sram #(.delay(`MEM_DELAY)) weight_ram(.clk(clk),.wen(1'b0),.addr(weight_addr),.d(32'h0),.q(weight_rdata));
    output_sram #(.delay(`MEM_DELAY)) output_ram(.clk(clk),.wen(output_wen),.addr(output_addr),.d(output_wdata),.q(output_rdata));
`else
    input_sram  #(.delay(0)) input_ram(.clk(clk),.wen(1'b0),.addr(input_addr),.d(32'h0),.q(input_rdata));
    weight_sram #(.delay(0)) weight_ram(.clk(clk),.wen(1'b0),.addr(weight_addr),.d(32'h0),.q(weight_rdata));
    output_sram #(.delay(0)) output_ram(.clk(clk),.wen(output_wen),.addr(output_addr),.d(output_wdata),.q(output_rdata));
`endif


top top01(
    .clk(clk),
    .rst_n(rst_n),
    .valid(valid),
    .Ready(Ready),
    .input_addr(input_addr),
    .input_rdata(input_rdata),
    .weight_addr(weight_addr),
    .weight_rdata(weight_rdata),
    .output_wen(output_wen),
    .output_addr(output_addr),
    .output_rdata(output_rdata),
    .output_wdata(output_wdata)
);

// debug flag
integer debug, correct;
integer start_time, end_time;

    initial begin
        `ifdef SYNTHESIS
            $sdf_annotate("./top_syn.sdf", top01);
            $fsdbDumpfile(`FSDB_SYN_FILE);
        `else
            $fsdbDumpfile(`FSDB_FILE);
        `endif
            $fsdbDumpvars;
    end

    initial begin
        // setting the debug level
        if ($value$plusargs("debug=%d", debug)) begin
            $display(">> Debug level =%d", debug);
        end else begin
            debug = 0;
        end

        golden_file = $fopen(`OUTPUT_GOLDEN, "r");
        output_file = $fopen(`OUTPUT_LOG, "w");

        // Read the golden csv
        $display(">> Reading the golden file: %s", `OUTPUT_GOLDEN);
        for(i=0; i< `output_H; i= i+1) begin
            for(j=0; j< `output_W; j= j+1) begin
        
                index = ((i * `output_W) + j);
                $fscanf(golden_file,"%d", golden[index]);
            end
        end
        $fclose(golden_file);

    end
    integer success_cnt;
    // create the clock
    always #(period/2) clk = ~clk;

    // test pattern
    initial begin
        clk = 0;
        rst_n = 1;
        valid = 0;
        
        #(delay) rst_n = 0;
        #(period) rst_n = 1;
        #(period) valid = 1;
        start_time = $time;

        @(posedge Ready)
        end_time = $time;
        valid = 0;

        // Read and check the output with golden data
        $display(">> Check the output data");
        if(allow_error)
            $display("Allow Error value: %d\n", error_val);
        correct = 1;
        success_cnt = 0;
        for(i=0; i< `output_H; i= i+1) begin
            for(j=0; j< `output_W; j= j+1) begin
                index = ((i*`output_W) + j);
                $fwrite(output_file, "%d\n", output_ram.ram[index]);
                if (debug >= 3) begin
                    if(allow_error) begin
                        if (!(golden[index] - error_val <= output_ram.ram[index] && output_ram.ram[index] <= golden[index] + error_val)) begin
                            correct = 0;
                            $display("[Error  ] golden[%d, %d]=%d | data[%d]=%d", i, j, golden[index], index, output_ram.ram[index]);
                        end else begin
                            success_cnt = success_cnt + 1;
                            $display("[Success] golden[%d, %d]=%d | data[%d]=%d", i, j, golden[index], index, output_ram.ram[index]);
                    
                        end          
                    end
                    else begin
                        if (!(golden[index] === output_ram.ram[index])) begin
                            correct = 0;
                            $display("[Error  ] golden[%d, %d]=%d | data[%d]=%d", i, j, golden[index], index, output_ram.ram[index]);
                        end else begin
                            success_cnt = success_cnt + 1;
                            $display("[Success] golden[%d, %d]=%d | data[%d]=%d", i, j, golden[index], index, output_ram.ram[index]);
                    
                        end                        
                    end

                end
                    
            end
        end
            
        if (correct)
            $display("[\033[0;32mCongratulation!\033[0m] all value are correct!");
        else
            $display("[\033[0;31mWrong\033[0m] debug and try it again!");
        $display("Error value set to : %d\n", error_val);
        $display("[\033[0;34mTime usage\033[0m] %d ns", end_time - start_time);
        #(period*100)
        $finish;
    end
endmodule
