SRC_DIR := .
VL_DIR := ./verilog
OBJ_DIR := ./build
TOP_PKG := AxiTrial
TOP_MOD := mk$(TOP_PKG)

VL_SIMER := iverilog
BSLIB_PFX := %/Libraries
BSC_LIBS := $(BSLIB_PFX):$(BSLIB_PFX)/Bus:$(BSLIB_PFX)/Flute_Addon:$(BSLIB_PFX)/AMBA_TLM3/TLM3:$(BSLIB_PFX)/AMBA_TLM3/Axi:$(BSLIB_PFX)/AMBA_TLM3/Axi4
BSC_FLAGS := -u -bdir $(OBJ_DIR) -info-dir $(OBJ_DIR) -elab -p $(SRC_DIR):$(VL_DIR):$(BSC_LIBS)

compile: $(VL_DIR)/$(TOP_MOD).v

$(VL_DIR)/$(TOP_MOD).v: $(SRC_DIR)/*.bsv
	@mkdir -p $(VL_DIR)
	@mkdir -p $(OBJ_DIR)
	bsc -verilog $(BSC_FLAGS) -vdir $(VL_DIR) -g $(TOP_MOD) $(SRC_DIR)/$(TOP_PKG).bsv

simulate: $(OBJ_DIR)/$(TOP_MOD)_vsim
	@echo "====== Simulation Output ======"
	@./$< +bscvcd

$(OBJ_DIR)/$(TOP_MOD)_vsim: $(VL_DIR)/$(TOP_MOD).v
	bsc -verilog $(BSC_FLAGS) -vsim $(VL_SIMER) -e $(TOP_MOD) -o $@ $<

clean:
	@rm -rf ./build ./verilog *.vcd

.PHONY: clean compile simulate
