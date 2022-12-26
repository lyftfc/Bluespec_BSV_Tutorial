package Axi4BramSlave;

import Connectable::*;
import FIFO::*;
import BRAM::*;
import TLM3::*;
import Axi4::*;
import Assert::*;

export mkAxi4BramSlave;

`include "Axi4Params.defines"

module mkAxi4BramSlave #(
    Integer addr_start, Integer addr_end
) (
    Axi4RdWrSlave#(`AXI_TLM_PRMS)
) provisos (
    Add#(d_bs_w_, 3, data_w)
);
    staticAssert(addr_end > addr_start,
        "Axi4BramSlave: addr_end must be higher than addr_start.");

    function Bool axi4_slv_addr(Bit#(addr_size) addr);
        return addr >= fromInteger(addr_start) && addr < fromInteger(addr_end);
    endfunction

    Axi4RdWrSlaveXActorIFC#(`AXI_XATR_PRMS) s_xatr <- mkAxi4RdWrSlave(True, axi4_slv_addr);
    BRAM1Port#(Bit#(addr_w), Bit#(addr_w)) bram <- mkBRAM1Server(
        BRAM_Configure {
            memorySize:     addr_end - addr_start,
            latency:        2,
            outFIFODepth:   3,
            loadFormat:     None,
            allowWriteResponseBypass: False
        }
    );
    TLMRecvIFC#(`AXI_TLM_REQ_RESP) tlm_bram <- mkTLMBRAM(bram.portA);

    mkConnection(s_xatr.tlm, tlm_bram);
    interface Axi4RdSlave read = s_xatr.read.bus;
    interface Axi4WrSlave write = s_xatr.write.bus;
endmodule

endpackage : Axi4BramSlave