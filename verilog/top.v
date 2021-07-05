`define BITS 65
// FFT 
`define FFT_H 8
`define FFT_W 8
`define FFT_len 128    
`define input_H  64
`define input_W  64
`define output_H  62
`define output_W  62
//FFT
`define FFT_input_H  8
`define FFT_input_W  8
`define FFT_output_H  6
`define FFT_output_W  6
`define kernel_H  3
`define kernel_W  3

module top (
    input clk,
    input rst_n,
    input valid,
    output Ready,
    output reg [15:0] input_addr,
    input [31:0] input_rdata,
    output reg [15:0] weight_addr,
    input [31:0] weight_rdata,
    output output_wen,
    output reg [15:0] output_addr,
    input signed[31:0] output_rdata,
    output signed [31:0] output_wdata
);

    parameter INITIAL = 0;
    parameter RESET = 1;
    parameter CALCULATING = 2;
    parameter FINISH = 3;
    
    parameter input_H = `input_H;
    parameter input_W = `input_W;
    parameter output_H = `output_H;
    parameter output_W = `output_W;
    parameter FFT_input_H = `FFT_input_H;
    parameter FFT_input_W = `FFT_input_W;
    parameter FFT_output_H = `FFT_output_H;
    parameter FFT_output_W = `FFT_output_W;
    parameter kernel_H = `kernel_H;
    parameter kernel_W = `kernel_W;

    // FSM
    reg [3:0] state, next_state;
    // CONV current address
    reg [15:0] base_i, base_j;
    reg [15:0] fixed_row_i, fixed_row_j;
    reg [15:0] fixed_col_i, fixed_col_j;
    reg [15:0] corner_i, corner_j;
    reg [15:0] addr_base_i, addr_base_j;

    reg [1:0] data_tiling_state;
    reg fixed_row_flag, fixed_col_flag, corner_flag, only_one_debug_flag;
    // FFT wire
    wire FFT_ready;
    wire [15:0] FFT_input_addr_i, FFT_input_addr_j;
    wire [15:0] FFT_weight_addr_i, FFT_weight_addr_j;
    wire [15:0] FFT_output_addr_i, FFT_output_addr_j; 


    always @(negedge clk or negedge rst_n) begin
        if(!rst_n)
            state <= INITIAL;
        else
            state <= next_state;
    end

    always @(*) begin
        if(state == INITIAL) begin
            if(valid)
                next_state = RESET;
            else
                next_state = state;
        end
        else if(state == RESET) begin
            if(corner_flag)
                next_state = FINISH;
            else 
                next_state = CALCULATING;

        end
        else if(state == CALCULATING) begin
            if(FFT_ready)
                next_state = RESET;
            else
                next_state = state;
    
        end
        else if(state == FINISH) begin
            next_state = state;
        end
        else begin
            next_state = INITIAL;
        end
    end

    always @(negedge clk ) begin
        if(state == INITIAL) begin
            base_i <= 0;
            base_j <= 0;
            fixed_row_i <= 0;
            fixed_row_j <= 0;
            fixed_col_i <= 0;
            fixed_col_j <= 0;
            corner_i <= 0;
            corner_j <= 0;
            fixed_row_flag <= 0;
            fixed_col_flag <= 0;
            corner_flag <= 0;
            only_one_debug_flag <= 0;
        end
        else if(state == CALCULATING && FFT_ready) begin
            if(data_tiling_state == 0) begin
                base_i <= (base_j + FFT_output_W + FFT_input_W > output_W ? base_i + FFT_output_H : base_i);
                base_j <= (base_j + FFT_output_W + FFT_input_W > output_W ? 0 : base_j + FFT_output_W);
                only_one_debug_flag <= 1;
            end
            else begin
                base_i <= 0;
                base_j <= 0;
            end

            if(data_tiling_state == 1) begin
                if(fixed_row_flag) begin
                    fixed_row_i <= input_H - FFT_input_H;
                    fixed_row_j <= fixed_row_j + FFT_output_W;
                end
                fixed_row_flag <= 1;
            end
            else begin
                fixed_row_i <= input_H - FFT_input_H;
                fixed_row_j <= 0;
                fixed_row_flag <= 0;
            end
            
            if(data_tiling_state == 2) begin
                if(fixed_col_flag) begin
                    fixed_col_i <= fixed_col_i + FFT_output_H;
                    fixed_col_j <= input_H - FFT_input_H;
                end
                fixed_col_flag <= 1;
            end
            else begin
                fixed_col_i <= 0;
                fixed_col_j <= input_H - FFT_input_H;
                fixed_col_flag <= 0;
            end

            if(data_tiling_state == 3) begin  
                corner_i <=  input_H - FFT_input_H;
                corner_j <=  input_W - FFT_input_W;
                corner_flag <= 1;
            end
            else begin
                corner_i <= input_H - FFT_input_H;
                corner_j <= input_W - FFT_input_W;
                corner_flag <= 0;
            end
            
        end
        
    end

    always @(negedge clk) begin
        if(state == INITIAL) begin
            data_tiling_state <= 0;
        end
        else if(state == RESET) begin
            if(data_tiling_state == 0) begin
                if(base_i + FFT_input_H > input_H)
                    data_tiling_state <= 1;
            end
            else if(data_tiling_state == 1) begin
                if(fixed_row_j + FFT_input_W > input_W)
                    data_tiling_state <= 2;
            end
            else if(data_tiling_state == 2) begin
                if(fixed_col_i + FFT_input_H > input_H)
                    data_tiling_state <= 3;
            end
        end
    end

    FFT_CONV fft_conv(
        .clk(clk),
        .reset(state == RESET),
        .Ready(FFT_ready),
        .input_addr_i(FFT_input_addr_i),
        .input_addr_j(FFT_input_addr_j),
        .input_rdata(input_rdata),
        .weight_addr_i(FFT_weight_addr_i),
        .weight_addr_j(FFT_weight_addr_j),
        .weight_rdata(weight_rdata),
        .output_wen(output_wen),
        .output_addr_i(FFT_output_addr_i),
        .output_addr_j(FFT_output_addr_j),
        .output_rdata(output_rdata),
        .output_wdata(output_wdata)
    );

    always @(*) begin
        if(data_tiling_state == 0) begin
            addr_base_i = base_i;
            addr_base_j = base_j;
        end
        else if(data_tiling_state == 1) begin
            addr_base_i = fixed_row_i;
            addr_base_j = fixed_row_j;
        end
        else if(data_tiling_state == 2) begin
            addr_base_i = fixed_col_i;
            addr_base_j = fixed_col_j;
        end
        else if(data_tiling_state == 3) begin
            addr_base_i = corner_i;
            addr_base_j = corner_j;
        end
    end

    always @(*) begin

        input_addr = (FFT_input_addr_i + addr_base_i) * input_W + addr_base_j + FFT_input_addr_j;
        weight_addr = FFT_weight_addr_i* kernel_W + FFT_weight_addr_j;
        output_addr = (FFT_output_addr_i + addr_base_i) * output_W + addr_base_j + FFT_output_addr_j;

    end

    assign Ready = (state == FINISH);
endmodule

module FFT_CONV(
    input clk,
    input reset,
    output Ready,
    output reg [15:0] input_addr_i,
    output reg [15:0] input_addr_j,
    input [31:0] input_rdata,
    output reg [15:0] weight_addr_i,
    output reg [15:0] weight_addr_j,
    input [31:0] weight_rdata,
    output reg output_wen,
    output reg [15:0] output_addr_i,
    output reg [15:0] output_addr_j,
    input signed[31:0] output_rdata,
    output reg signed [31:0] output_wdata
);
    parameter FFT_len = `FFT_len;
    parameter FFT_H= `FFT_H;
    parameter FFT_W = `FFT_W;
    parameter FFT_input_H = `FFT_input_H;
    parameter FFT_input_W = `FFT_input_W;
    parameter FFT_output_H = `FFT_output_H;
    parameter FFT_output_W = `FFT_output_W;
    parameter kernel_H = `kernel_H;
    parameter kernel_W = `kernel_W;

    parameter quantized_bits = 21;

    parameter INITIAL = 0;
    parameter RESET = 1;
    parameter READING = 2;
    parameter RADER = 3;
    parameter TRANSFORMING = 4;
    parameter CALCULATING = 5;
    parameter INVTRANSFORMING = 6;
    parameter WRITE = 7;
    parameter FINISH = 8;

    parameter RADER_RESET = 0;
    parameter RADER_SWAP = 1;
    parameter RADER_K_SHIFT = 2;
    parameter RADER_J_ADD = 3;
    parameter RADER_FINISH = 4;

    parameter BF_RESET = 0;
    parameter BF_TRIG = 1;
    parameter BF_MERGE = 2;
    parameter BF_ROTATE = 3;
    parameter BF_J_ADD = 4;
    parameter BF_H_ADD = 5;
    parameter BF_INV_RESET = 6;
    parameter BF_INV_DIV = 7;
    parameter BF_FINISH = 8;

    integer i, j;
    reg [3:0] state, next_state;
    reg [3:0] rader_A_state, rader_A_next_state;
    reg [3:0] rader_B_state, rader_B_next_state;
    reg [3:0] bf_A_state, bf_A_next_state;
    reg [3:0] bf_B_state, bf_B_next_state;
    reg [31:0] reading_input_i, reading_input_j, reading_weight_i, reading_weight_j;
    reg [31:0] write_counter_i, write_counter_j, reset_counter;
    reg signed [`BITS-1:0] A_r [0:128-1];
    reg signed [`BITS-1:0] B_r [0:128-1];
    reg signed [`BITS-1:0] A_i [0:128-1];
    reg signed [`BITS-1:0] B_i [0:128-1];
    reg signed [`BITS-1:0] kernel [0:8];

    reg signed [20:0] rader_A_i, rader_B_i;
    reg signed [20:0] rader_A_j, rader_B_j;
    reg signed [20:0] rader_A_k, rader_B_k;
    
    reg signed [10:0] bf_A_h, bf_A_i, bf_A_j, bf_A_k;
    reg signed [10:0] bf_B_h, bf_B_i, bf_B_j,  bf_B_k;
    reg signed [`BITS-1:0] bf_A_wn_r, bf_B_wn_r;
    reg signed [`BITS-1:0] bf_A_wn_i, bf_B_wn_i;
    reg signed [`BITS-1:0] bf_A_w_r, bf_B_w_r;
    reg signed [`BITS-1:0] bf_A_w_i, bf_B_w_i;
    wire signed [`BITS-1:0] bf_A_cos, bf_B_cos;
    wire signed [`BITS-1:0] bf_A_sin, bf_B_sin;
    reg bf_A_on, bf_B_on;

    reg [9:0] conv_count;
    reg [9:0] c_i, c_j;

    COS cos_A(
        .h(bf_A_h),
        .on(bf_A_on),
        .value(bf_A_cos)
    );

    SIN sin_A(
        .h(bf_A_h),
        .on(bf_A_on),
        .value(bf_A_sin)
    );
    COS cos_B(
        .h(bf_B_h),
        .on(bf_B_on),
        .value(bf_B_cos)
    );

    SIN sin_B(
        .h(bf_B_h),
        .on(bf_B_on),
        .value(bf_B_sin)
    );

    always @(negedge clk) begin
        if(reset)
            state <= INITIAL;
        else
            state <= next_state;
    end

    always @(*) begin
        if(state == INITIAL) begin
            next_state = RESET;
        end
        else if(state == RESET) begin
            if(reset_counter >= FFT_len)
                next_state = READING;
            else
                next_state = state;
        end
        else if(state == READING) begin
            if(reading_input_i >= FFT_H) begin
                
                next_state = RADER;
            end
            else
                next_state = state;
        end
        else if(state == RADER) begin
            if(rader_A_state == RADER_FINISH && rader_B_state == RADER_FINISH)
                next_state = TRANSFORMING;
            else
                next_state = state;
        end
        else if(state == TRANSFORMING) begin
            if(bf_A_state == BF_FINISH && bf_B_state == BF_FINISH)
                if(bf_A_on == 0)
                    next_state = WRITE;
                else
                    next_state = CALCULATING;
            else
                next_state = state;
        end
        else if(state == CALCULATING) begin
            if(conv_count + 1 < FFT_len)
                next_state = CALCULATING;
            else
                next_state = INVTRANSFORMING;
        end
        else if(state == INVTRANSFORMING) begin
                next_state = RADER;
        end
        else if(state == WRITE) begin
            if(output_addr_i == FFT_output_H - 1 && output_addr_j == FFT_output_W - 1)
                next_state = FINISH;
            else
                next_state = state;
        end
        else if(state == FINISH) begin
            
            next_state = FINISH;
        end
        else begin
            next_state = INITIAL;
        end
    end


    always @(negedge clk) begin
        if(state == INITIAL) begin
            reset_counter <= 0;
        end
        else if(state == RESET)
            reset_counter <= reset_counter + 1;
        else
            reset_counter <= 0;
    end

    always @(negedge clk ) begin
        if(state != WRITE) begin
            write_counter_i <= 0;
            write_counter_j <= 0;
        end
        else begin
            write_counter_i <= (write_counter_j == FFT_output_W -1 ? write_counter_i + 1 : write_counter_i);
            write_counter_j <= (write_counter_j == FFT_output_W -1 ? 0 : write_counter_j + 1);
        end
        
    end

    always @(negedge clk ) begin
        if(state == READING) begin
            if(reading_input_j + 4 >= FFT_W)
                reading_input_i <= reading_input_i + 1;
            if(reading_input_j + 4 >= FFT_W)
                reading_input_j <= reading_input_j + 4 - FFT_W;
            else
                reading_input_j <= reading_input_j + 4;
                
            if(reading_weight_j + 4 >= kernel_W)
                reading_weight_i <= reading_weight_i + 1;

            if(reading_weight_j + 4 >= kernel_W)
                reading_weight_j <= reading_weight_j + 4 - kernel_W;
            else
                reading_weight_j <= reading_weight_j + 4;
        
        end
        else begin
            reading_input_i <= 0;
            reading_input_j <= 0;
            reading_weight_i <= 0;
            reading_weight_j <= 0;
        end
    end


    wire [9:0] a_1D_index = reading_input_i * FFT_W + reading_input_j;
    wire [9:0] b_1D_index = reading_weight_i * kernel_W + reading_weight_j;
    

    wire [20:0] bf_A_merge_index = bf_A_k + bf_A_h/2; 
    wire [20:0] bf_B_merge_index = bf_B_k + bf_B_h/2; 

    always @(*) begin // READING SOURCE/WEIGHT
        input_addr_i = reading_input_i;
        input_addr_j = reading_input_j;
        weight_addr_i = reading_weight_i;
        weight_addr_j = reading_weight_j;
    end
    wire signed [`BITS-1:0] A_temp0 = {{(`BITS-8){input_rdata[7]}}, input_rdata[7:0]};
    wire signed [`BITS-1:0] A_temp1 = {{(`BITS-8){input_rdata[15]}}, input_rdata[15:8]};
    wire signed [`BITS-1:0] A_temp2 = {{(`BITS-8){input_rdata[23]}}, input_rdata[23:16]};
    wire signed [`BITS-1:0] A_temp3 = {{(`BITS-8){input_rdata[31]}}, input_rdata[31:24]};
    wire signed [`BITS-1:0] B_temp0 = {{(`BITS-8){weight_rdata[7]}}, weight_rdata[7:0]};
    wire signed [`BITS-1:0] B_temp1 = {{(`BITS-8){weight_rdata[15]}}, weight_rdata[15:8]};
    wire signed [`BITS-1:0] B_temp2 = {{(`BITS-8){weight_rdata[23]}}, weight_rdata[23:16]};
    wire signed [`BITS-1:0] B_temp3 = {{(`BITS-8){weight_rdata[31]}}, weight_rdata[31:24]};
    always @(negedge clk) begin
        if(state == READING) begin
            if(a_1D_index < FFT_input_H * FFT_input_W) begin
                if(a_1D_index + 0 < FFT_input_H * FFT_input_W)
                    A_r[a_1D_index+0] <= (A_temp0 <<< quantized_bits);
                if(a_1D_index + 1 < FFT_input_H * FFT_input_W)
                    A_r[a_1D_index+1] <= (A_temp1 <<< quantized_bits);
                if(a_1D_index + 2 < FFT_input_H * FFT_input_W)
                    A_r[a_1D_index+2] <= (A_temp2 <<< quantized_bits);
                if(a_1D_index + 3 < FFT_input_H * FFT_input_W)
                    A_r[a_1D_index+3] <= (A_temp3 <<< quantized_bits);
                    
            end
            if(b_1D_index < kernel_H * kernel_W) begin
                if(b_1D_index + 0 < kernel_H * kernel_W)
                    kernel[b_1D_index] <= B_temp0;
                if(b_1D_index + 1 < kernel_H * kernel_W)
                    kernel[b_1D_index + 1] <= B_temp1;
                if(b_1D_index + 2 < kernel_H * kernel_W)
                    kernel[b_1D_index + 2] <= B_temp2;
                if(b_1D_index + 3 < kernel_H * kernel_W)
                    kernel[b_1D_index + 3] <= B_temp3;

            end
            
            for(i = 0 ; i < 3 ; i = i + 1) begin
                for(j = 0 ; j < 3 ; j = j + 1) begin
                    B_r[i * FFT_input_W + j] <= ((kernel[(kernel_H - i - 1) * kernel_W + kernel_W - 1 - j]) <<< quantized_bits);
                end
            end
        end
        else if(state == RESET) begin
            A_r[reset_counter] <= 0;
            B_r[reset_counter] <= 0;
            A_i[reset_counter] <= 0;
            B_i[reset_counter] <= 0;
        end
        else if(state == RADER) begin
            // A part
            if(rader_A_state == RADER_RESET) begin
                rader_A_i <= 1;
                rader_A_j <= (FFT_len >> 1);

            end
            else if(rader_A_state == RADER_SWAP) begin
                    
                if(rader_A_i < rader_A_j) begin
                    A_r[rader_A_i] <= A_r[rader_A_j];
                    A_r[rader_A_j] <= A_r[rader_A_i];
                    A_i[rader_A_i] <= A_i[rader_A_j];
                    A_i[rader_A_j] <= A_i[rader_A_i];
                end
                rader_A_k <= (FFT_len >> 1);
            end
            else if(rader_A_state == RADER_K_SHIFT) begin
                rader_A_j <= rader_A_j - rader_A_k;
                rader_A_k <= rader_A_k >> 1;
            end
            else if(rader_A_state == RADER_J_ADD) begin
                if(rader_A_j < rader_A_k)
                    rader_A_j <= rader_A_j + rader_A_k;
                rader_A_i <= rader_A_i + 1;
            end

            // B part
            if(rader_B_state == RADER_RESET) begin
                rader_B_i <= 1;
                rader_B_j <= (FFT_len >> 1);

            end
            else if(rader_B_state == RADER_SWAP) begin
                    
                if(rader_B_i < rader_B_j) begin
                    B_r[rader_B_i] <= B_r[rader_B_j];
                    B_r[rader_B_j] <= B_r[rader_B_i];
                    B_i[rader_B_i] <= B_i[rader_B_j];
                    B_i[rader_B_j] <= B_i[rader_B_i];
                end
                rader_B_k <= (FFT_len >> 1);
            end
            else if(rader_B_state == RADER_K_SHIFT) begin
                rader_B_j <= rader_B_j - rader_B_k;
                rader_B_k <= rader_B_k >> 1;
            end
            else if(rader_B_state == RADER_J_ADD) begin
                if(rader_B_j < rader_B_k)
                    rader_B_j <= rader_B_j + rader_B_k;
                rader_B_i <= rader_B_i + 1;
            end            
        end
        else if(state == TRANSFORMING || state == INVTRANSFORMING) begin
            // A part
            if(bf_A_state == BF_RESET) begin
                bf_A_h <= 2;
            end
            else if(bf_A_state == BF_TRIG) begin
                bf_A_wn_r <= bf_A_cos;
                bf_A_wn_i <= bf_A_sin;
                bf_A_j <= 0;
            end
            else if(bf_A_state == BF_ROTATE) begin
                bf_A_w_r <= (64'b1 <<< quantized_bits);
                bf_A_w_i <= 0;
                bf_A_k <= bf_A_j;
            end
            else if(bf_A_state == BF_MERGE) begin
                A_r[bf_A_k] <= A_r[bf_A_k] 
                    + ((A_r[bf_A_merge_index]*bf_A_w_r - A_i[bf_A_merge_index]*bf_A_w_i) >>> quantized_bits);
                A_i[bf_A_k] <= A_i[bf_A_k] 
                    + ((A_r[bf_A_merge_index]*bf_A_w_i + A_i[bf_A_merge_index]*bf_A_w_r) >>> quantized_bits);
                A_r[bf_A_merge_index] <= A_r[bf_A_k] 
                    - ((A_r[bf_A_merge_index]*bf_A_w_r - A_i[bf_A_merge_index]*bf_A_w_i) >>> quantized_bits);
                A_i[bf_A_merge_index] <= A_i[bf_A_k] 
                    - ((A_r[bf_A_merge_index]*bf_A_w_i + A_i[bf_A_merge_index]*bf_A_w_r) >>> quantized_bits);
                bf_A_w_r <= ((bf_A_w_r*bf_A_wn_r-bf_A_w_i*bf_A_wn_i) >>> quantized_bits);
                bf_A_w_i <= ((bf_A_w_r*bf_A_wn_i+bf_A_w_i*bf_A_wn_r) >>> quantized_bits);

                bf_A_k <= bf_A_k + 1;
            end
            else if(bf_A_state == BF_J_ADD) begin
                bf_A_j <= bf_A_j + bf_A_h;
            end
            else if(bf_A_state == BF_H_ADD) begin
                bf_A_h <= bf_A_h <<< 1;
            end
            else if(bf_A_state == BF_INV_RESET) begin
                bf_A_i <= 0;
            end
            else if(bf_A_state == BF_INV_DIV) begin
                A_r[bf_A_i] <= A_r[bf_A_i] / FFT_len;
                bf_A_i <= bf_A_i + 1;
            end
            // B part
            if(bf_B_state == BF_RESET) begin
                bf_B_h <= 2;
            end
            else if(bf_B_state == BF_TRIG) begin
                bf_B_wn_r <= bf_B_cos;
                bf_B_wn_i <= bf_B_sin;
                bf_B_j <= 0;
            end
            else if(bf_B_state == BF_ROTATE) begin
                bf_B_w_r <= (64'b1 <<< quantized_bits);
                bf_B_w_i <= 0;
                bf_B_k <= bf_B_j;
            end
            else if(bf_B_state == BF_MERGE) begin
                B_r[bf_B_k] <= B_r[bf_B_k] 
                    + ((B_r[bf_B_merge_index]*bf_B_w_r - B_i[bf_B_merge_index]*bf_B_w_i) >>> quantized_bits);
                B_i[bf_B_k] <= B_i[bf_B_k] 
                    + ((B_r[bf_B_merge_index]*bf_B_w_i + B_i[bf_B_merge_index]*bf_B_w_r) >>> quantized_bits);
                B_r[bf_B_merge_index] <= B_r[bf_B_k] 
                    - ((B_r[bf_B_merge_index]*bf_B_w_r - B_i[bf_B_merge_index]*bf_B_w_i) >>> quantized_bits);
                B_i[bf_B_merge_index] <= B_i[bf_B_k] 
                    - ((B_r[bf_B_merge_index]*bf_B_w_i + B_i[bf_B_merge_index]*bf_B_w_r) >>> quantized_bits);
                bf_B_w_r <= ((bf_B_w_r*bf_B_wn_r-bf_B_w_i*bf_B_wn_i) >>> quantized_bits);
                bf_B_w_i <= ((bf_B_w_r*bf_B_wn_i+bf_B_w_i*bf_B_wn_r) >>> quantized_bits);

                bf_B_k <= bf_B_k + 1;
            end
            else if(bf_B_state == BF_J_ADD) begin
                bf_B_j <= bf_B_j + bf_B_h;
            end
            else if(bf_B_state == BF_H_ADD) begin
                bf_B_h <= bf_B_h <<< 1;
            end
            else if(bf_B_state == BF_INV_RESET) begin
                bf_B_i <= 0;
            end
            else if(bf_B_state == BF_INV_DIV) begin
                B_r[bf_B_i] <= B_r[bf_B_i] / FFT_len;
                bf_B_i <= bf_B_i + 1;
            end            
        end
        else if(state == CALCULATING) begin
            A_r[conv_count] <= ((A_r[conv_count]*B_r[conv_count]-A_i[conv_count]*B_i[conv_count]) >>> quantized_bits);
            A_i[conv_count] <= ((A_r[conv_count]*B_i[conv_count]+A_i[conv_count]*B_r[conv_count]) >>> quantized_bits);
        end
        
    end

    
    always @(negedge clk) begin // rader FSM 
        if(state != RADER) begin
            rader_A_state <= RADER_RESET;
            rader_B_state <= RADER_RESET;
        end
        else begin
            rader_A_state <= rader_A_next_state;
            rader_B_state <= rader_B_next_state;
        end
    end

    always @(*) begin // rader A
        if(rader_A_state == RADER_RESET) begin
            rader_A_next_state = RADER_SWAP;
        end
        else if(rader_A_state == RADER_SWAP) begin
            if(rader_A_j  >= (FFT_len >> 1))
                rader_A_next_state = RADER_K_SHIFT;
            else
                rader_A_next_state = RADER_J_ADD;
        end
        else if(rader_A_state == RADER_K_SHIFT) begin
            if((rader_A_j - rader_A_k) >= (rader_A_k >> 1))
                rader_A_next_state = RADER_K_SHIFT;
            else
                rader_A_next_state = RADER_J_ADD;
        end
        else if(rader_A_state == RADER_J_ADD) begin
            if((rader_A_i + 1) < FFT_len - 1)
                rader_A_next_state = RADER_SWAP;
            else
                rader_A_next_state = RADER_FINISH;
        end
        else if(rader_A_state == RADER_FINISH) begin
            rader_A_next_state = RADER_FINISH;
        end
        else begin
            rader_A_next_state = RADER_RESET;
        end
    end
    
    always @(*) begin // rader B
        if(rader_B_state == RADER_RESET) begin
            rader_B_next_state = RADER_SWAP;
        end
        else if(rader_B_state == RADER_SWAP) begin
            if(rader_B_j  >= (FFT_len >> 1))
                rader_B_next_state = RADER_K_SHIFT;
            else
                rader_B_next_state = RADER_J_ADD;
        end
        else if(rader_B_state == RADER_K_SHIFT) begin
            if((rader_B_j - rader_B_k) >= (rader_B_k >> 1))
                rader_B_next_state = RADER_K_SHIFT;
            else
                rader_B_next_state = RADER_J_ADD;
        end
        else if(rader_B_state == RADER_J_ADD) begin
            if((rader_B_i + 1) < FFT_len - 1)
                rader_B_next_state = RADER_SWAP;
            else
                rader_B_next_state = RADER_FINISH;
        end
        else if(rader_B_state == RADER_FINISH) begin
            rader_B_next_state = RADER_FINISH;
        end
        else begin
            rader_B_next_state = RADER_RESET;
        end
    end


    always @(negedge clk) begin
        if(state != TRANSFORMING && state != INVTRANSFORMING) begin
            bf_A_state <= BF_RESET;
            bf_B_state <= BF_RESET;
        end
        else begin
            bf_A_state <= bf_A_next_state;
            bf_B_state <= bf_B_next_state;
        end
    end
    
    always @(negedge clk) begin
        if(state == INITIAL) begin
            bf_A_on <= 1;
            bf_B_on <= 1;
        end
        else if(state == INVTRANSFORMING) begin
            bf_A_on <= 0;
            bf_B_on <= 0;
        end
    end

    always @(*) begin
        if(bf_A_state == BF_RESET) begin
            bf_A_next_state = BF_TRIG;
        end
        else if(bf_A_state == BF_TRIG) begin
            bf_A_next_state = BF_ROTATE;
        end
        else if(bf_A_state == BF_ROTATE) begin
            bf_A_next_state = BF_MERGE;
        end
        else if(bf_A_state == BF_MERGE) begin
            if(bf_A_k + 1 < bf_A_j + (bf_A_h / 2))
                bf_A_next_state = BF_MERGE;
            else
                bf_A_next_state = BF_J_ADD;
        end
        else if(bf_A_state == BF_J_ADD) begin
            if(bf_A_j + bf_A_h < FFT_len)
                bf_A_next_state = BF_ROTATE;
            else
                bf_A_next_state = BF_H_ADD;
        end
        else if(bf_A_state == BF_H_ADD) begin
            if((bf_A_h*2) <= FFT_len)
                bf_A_next_state = BF_TRIG;
            else if(bf_A_on == 0)
                bf_A_next_state = BF_INV_RESET;
            else
                bf_A_next_state = BF_FINISH;
        end
        else if(bf_A_state == BF_INV_RESET) begin
            bf_A_next_state = BF_INV_DIV;
        end
        else if(bf_A_state == BF_INV_DIV) begin
            if(bf_A_i + 1 < FFT_len)
                bf_A_next_state = BF_INV_DIV;
            else
                bf_A_next_state = BF_FINISH;
        end
        else if(bf_A_state == BF_FINISH) begin
            bf_A_next_state = BF_FINISH;
            
        end
        else begin
            bf_A_next_state = BF_RESET;
        end

    end

    always @(*) begin
        if(bf_B_state == BF_RESET) begin
            bf_B_next_state = BF_TRIG;
        end
        else if(bf_B_state == BF_TRIG) begin
            bf_B_next_state = BF_ROTATE;
        end
        else if(bf_B_state == BF_ROTATE) begin
            bf_B_next_state = BF_MERGE;
        end
        else if(bf_B_state == BF_MERGE) begin
            if(bf_B_k + 1 < bf_B_j + (bf_B_h / 2))
                bf_B_next_state = BF_MERGE;
            else
                bf_B_next_state = BF_J_ADD;
        end
        else if(bf_B_state == BF_J_ADD) begin
            if(bf_B_j + bf_B_h < FFT_len)
                bf_B_next_state = BF_ROTATE;
            else
                bf_B_next_state = BF_H_ADD;
        end
        else if(bf_B_state == BF_H_ADD) begin
            if((bf_B_h*2) <= FFT_len)
                bf_B_next_state = BF_TRIG;
            else if(bf_B_on == 0)
                bf_B_next_state = BF_INV_RESET;
            else
                bf_B_next_state = BF_FINISH;
        end
        else if(bf_B_state == BF_INV_RESET) begin
            bf_B_next_state = BF_INV_DIV;
        end
        else if(bf_B_state == BF_INV_DIV) begin
            if(bf_B_i + 1 < FFT_len)
                bf_B_next_state = BF_INV_DIV;
            else
                bf_B_next_state = BF_FINISH;
        end
        else if(bf_B_state == BF_FINISH) begin
            bf_B_next_state = BF_FINISH;
        end
        else begin
            bf_B_next_state = BF_RESET;
        end

    end

    

    always @(negedge clk) begin
        if(state == CALCULATING) begin
            conv_count <= conv_count + 1;
        end
        else begin
            conv_count <= 0;
        end
    end
    
    always @(negedge clk) begin
        if(state != WRITE) begin
            output_addr_i <= 0;
            output_addr_j <= 0;
        end
        else begin
            output_addr_i <= (output_addr_j == FFT_output_W - 1 ? output_addr_i + 1 : output_addr_i);
            output_addr_j <= (output_addr_j == FFT_output_W - 1 ? 0 : output_addr_j + 1);
        end
    end

    wire [15:0] write_base = FFT_input_W * kernel_W - FFT_input_W + kernel_W - 1;
    always @(*) begin
        if(state == WRITE)begin
            output_wen = 1;
            output_wdata = (A_r[write_base + FFT_input_W * output_addr_i + output_addr_j] >>> quantized_bits);
        end
        else begin
            output_wen = 0;
            output_wdata = 0;
        end
    end

    assign Ready = (state == FINISH);

endmodule


module SIN(
    input wire on,
    input wire [10:0] h,
    output reg signed[`BITS - 1:0] value 
);
    always @(*) begin
        if(on == 1) begin//on = 1 in C++
            case(h)
                2       : value = 0;
                4       : value = -2097152;
                8       : value = -1482910;
                16      : value = -802545;
                32      : value = -409134;
                64      : value = -205556;
                128     : value = -102902;
                default : value = 0;
            endcase
        end 
        else begin // on = -1 in C++
            case(h)
                2       : value = 0;
                4       : value = 2097152;
                8       : value = 1482910;
                16      : value = 802545;
                32      : value = 409134;
                64      : value = 205556;
                128     : value = 102902;
                default : value = 0;
            endcase
        end
    end

endmodule

module COS(
    input wire on,
    input wire [10:0] h,
    output reg signed[`BITS - 1:0] value 
);
    always @(*) begin
        if(on == 1) begin//on = 1 in C++
            case(h)
                2       : value = -2097152;
                4       : value = 0;
                8       : value = 1482910;
                16      : value = 1937515;
                32      : value = 2056855;
                64      : value = 2087053;
                128     : value = 2094625;
                default : value = 0;
            endcase
        end 
        else begin // on = -1 in C++
            case(h)
                2       : value = -2097152;
                4       : value = 0;
                8       : value = 1482910;
                16      : value = 1937515;
                32      : value = 2056855;
                64      : value = 2087053;
                128     : value = 2094625;
                default : value = 0;
            endcase
        end
    end

endmodule