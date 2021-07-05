#include<bits/stdc++.h>

using namespace std;


const int input_len = 8;
const int kernel_len = 3;
const int len = 128;
const double PI = acos(-1.0);
const int quantized_bits = 21;


// 複數
struct Complex
{
    long long int  r, i;
    Complex(double _r = 0, double _i = 0)
    {
        r = _r;
        i = _i;
    }
    Complex operator +(const Complex& b)
    {
        Complex ans(0, 0);
        ans.r = r + b.r;
        ans.i = i + b.i;
        return ans;
    }
    Complex operator -(const Complex& b)
    {
        Complex ans(0, 0);
        ans.r = r - b.r;
        ans.i = i - b.i;
        return ans;
    }
    Complex operator *(const Complex& b)
    {
        Complex ans(0, 0);
        ans.r = (r * b.r - i * b.i) / pow(2, quantized_bits);
        ans.i = (r * b.i + i * b.r) / pow(2, quantized_bits);
        return ans;
    }
};

// 雷德演算法 -- 倒位序
void Rader(Complex F[], int len)
{
    int j = len >> 1;
    for (int i = 1; i < len - 1; i++)
    {

        if (i < j)
            swap(F[i], F[j]);
        int k = len >> 1;
        while (j >= k)
        {
            j -= k;
            k >>= 1;
        }
        if (j < k)
            j += k;
    }
}

int COS(int h, int on) {
    int result = cos(-on * 2 * PI / h) * pow(2, quantized_bits);

    return result;
}


int SIN(int h, int on) {
    int result = sin(-on * 2 * PI / h) * pow(2, quantized_bits);

    return result;

}
void FFT(Complex F[], int len, int on)
{
    Rader(F, len);

    //RESET, Verilog FSM state
    int h = 2;
    while (h <= len)    //計算長度為h的DFT
    {
        //TRIG
        Complex wn(COS(h, on), SIN(h, on));   //單位復根e^(2*PI/m),用尤拉公式展開

        int j = 0;
        while (j < len)
        {
            // ROTATE
            Complex w(1 * pow(2, quantized_bits), 0 * pow(2, quantized_bits));       //旋轉因子
            int k = j;
            while (k < j + h / 2)
            {
                //MERGE
                Complex u = F[k];
                Complex t = w * F[k + h / 2];
                F[k] = u + t;        //蝴蝶合併操作
                F[k + h / 2] = u - t;

                w = w * wn;          //更新旋轉因子
                k++;
            }
            // J_ADD
            j += h;
        }
        // H_ADD
        h <<= 1;
    }

    //求逆傅立葉變換
    if (on == -1)
    {
        // INV_RESET
        int i = 0;
        while (i < len)
        {
            // INV_DIV
            F[i].r /= len;
            i++;
        }
    }

    //FINISH
}


void Conv(Complex a[], Complex b[], int len)
{

    for (int i = 0; i < len; i++) { //quantize input for quantized trignomical function 
        a[i].r = a[i].r << quantized_bits;
        a[i].i = a[i].i << quantized_bits;
        b[i].r = b[i].r << quantized_bits;
        b[i].i = b[i].i << quantized_bits;
    }


    FFT(a, len, 1); //FFT to frequency domain
    FFT(b, len, 1); //FFT to frequency domain

    for (int i = 0; i < len; i++)
    {
        a[i] = a[i] * b[i];         //Convolution 
    }

    FFT(a, len, -1); // Invert FFT

    for (int i = 0; i < len; i++) { // dequantized to origin
        a[i].r = a[i].r >> quantized_bits;
        a[i].i = a[i].i >> quantized_bits;
        b[i].r = b[i].r >> quantized_bits;
        b[i].i = b[i].i >> quantized_bits;
    }

}
void read_in(int Input[input_len][input_len], int Kernel[kernel_len][kernel_len]) {
    fstream file;
    file.open("data/input.csv", ios::in);
    for (int i = 0; i < input_len; i++) {
        for (int j = 0; j < input_len; j++) {
            file >> Input[i][j];
        }
    }

    file.close();

    file.open("data/weight.csv", ios::in);
    for (int i = 0; i < kernel_len; i++) {
        for (int j = 0; j < kernel_len; j++) {
            file >> Kernel[i][j];
        }
    }

    file.close();
}

void write_out(int Result[input_len - kernel_len + 1][input_len - kernel_len + 1]) {
    fstream file;
    file.open("data/golden.csv", ios::out);
    for (int i = 0; i < input_len - kernel_len + 1; i++) {
        for (int j = 0; j < input_len - kernel_len + 1; j++) {
            file << Result[i][j] << endl;
        }
    }

    file.close();
}
int main() {

    int Input[input_len][input_len];
    int Kernel[kernel_len][kernel_len];
    int Golden[input_len - kernel_len + 1][input_len - kernel_len + 1];
    int Result[input_len - kernel_len + 1][input_len - kernel_len + 1];

    read_in(Input, Kernel);

    int FFT_sum = 0;
    int Gold_sum = 0;

    // Calculate golden
    for (int i = 0; i < input_len - kernel_len + 1; i++) {
        for (int j = 0; j < input_len - kernel_len + 1; j++) {
            Golden[i][j] = 0;
            for (int k = 0; k < kernel_len; k++) {
                for (int l = 0; l < kernel_len; l++) {
                    Golden[i][j] += Kernel[k][l] * Input[i + k][j + l];
                }
            }
        }
    }

    //DO FFT Convolution
    Complex A[len];
    Complex B[len];

    // prepare 1D input value
    for (int i = 0; i < len; i++) {
        if (i < input_len * input_len)
            A[i] = Input[i / input_len][i % input_len];
        else
            A[i] = Complex(0, 0);

    }

    // prepare 1D kernel value
    for (int i = 0; i < len; i++) {
        B[i] = Complex(0, 0);
    }
    for (int i = 0; i < kernel_len; i++) {
        for (int j = 0; j < kernel_len; j++) {

            B[i * input_len + j] = Kernel[kernel_len - 1 - i][kernel_len - 1 - j];

        }
    }

    // do FFT convolution by prepared source
    Conv(A, B, len);


    //validate computed result
    bool pass = true;
    int base = input_len * kernel_len - input_len + kernel_len - 1;
    double max_error_rate = 0;
    double avg_error_rate = 0;
    int error_val = 2;
    for (int i = 0; i < input_len - kernel_len + 1; i++)
        for (int j = 0; j < input_len - kernel_len + 1; j++) {
            double error = abs(abs(round(A[base + input_len * i + j].r)) - abs(Golden[i][j]));
            double error_rate = error / abs(Golden[i][j]);
            avg_error_rate += error_rate;

            max_error_rate = max(max_error_rate, error_rate);

            Result[i][j] = (int)round(A[base + input_len * i + j].r);

            if (abs(Golden[i][j] - round(A[base + input_len * i + j].r)) > error_val) {
                cout << "[" << i << "," << j << "]" << endl;
                cout << "   Golden: " << Golden[i][j] << endl;
                cout << "   FFT   : " << round(A[base + input_len * i + j].r) << endl;
                cout << "   ===> Failed" << endl;

                pass = false;
            }
        }
    if (pass)
        cout << "PASS!" << endl;
    else
        cout << "FAILED!" << endl;

    write_out(Result);

    // error rate
    cout << "Error     rate = " << avg_error_rate / (input_len - kernel_len + 1) / (input_len - kernel_len + 1) * 100 << " %" << endl;
    cout << "Max Error rate = " << max_error_rate * 100 << " %" << endl;

    return 0;
}