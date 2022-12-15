SRC_DIR := ./src_BSV
VL_DIR := ./verilog
OBJ_DIR := ./build
TOP_PKG := Testbench
TOP_MOD := mk$(TOP_PKG)

VL_SIMER := iverilog
BSC_LIBS := %/Libraries:%/Libraries/Flute_Addon
BSC_FLAGS := -u -bdir $(OBJ_DIR) -info-dir $(OBJ_DIR) -elab -p $(SRC_DIR):$(VL_DIR):$(BSC_LIBS)

compile: $(VL_DIR)/$(TOP_MOD).v

$(VL_DIR)/$(TOP_MOD).v: $(SRC_DIR)/*.bsv
	@mkdir -p $(VL_DIR)
	@mkdir -p $(OBJ_DIR)
	bsc -verilog $(BSC_FLAGS) -vdir $(VL_DIR) -g $(TOP_MOD) $(SRC_DIR)/$(TOP_PKG).bsv

simulate: $(OBJ_DIR)/$(TOP_MOD)_vsim
	@echo "====== Simulation Output ======"
	@./$<

$(OBJ_DIR)/$(TOP_MOD)_vsim: $(VL_DIR)/$(TOP_MOD).v
	bsc -verilog $(BSC_FLAGS) -vsim $(VL_SIMER) -e $(TOP_MOD) -o $@ $<

clean:
	@rm -rf ./build ./verilog

.PHONY: clean compile simulate
