DEBUG = 3

# add your source code
SRC = testbench.v input_sram.v weight_sram.v output_sram.v top.v

BAK = *.bak
LOG = *.log *.history *.key *.fsdb out_log.txt
INCA_libs = INCA_libs
SYNSRC = header.v testbench.v input_sram.v weight_sram.v output_sram.v top_syn.v -v /theda21_2/library/GPDK045/cur/gsclib045/verilog/slow_vdd1v2_basicCells.v

all :: sim


sim :
	ncverilog +debug=${DEBUG} ${SRC} +access+r

syn :
	ncverilog +debug=${DEBUG} ${SYNSRC} +access+r
clean:
	-rm -f ${BAK} ${LOG}
	-rm -rf ${INCA_libs}
