package AxisGetPut;

import AXI4_Stream::*;
import Semi_FIFOF::*;
import FIFO::*;
import GetPut::*;

// Re-exporting AXI4_Stream ifaces
export AXI4_Stream_Master_IFC(..);
export AXI4_Stream_Slave_IFC(..);

export AxisBeatS(..);
export AxisMasterAdapterS(..), AxisSlaveAdapterS(..);
export mkAxisMasterAdapterS, mkAxisSlaveAdapterS;

// Simple AXIS Beat, has no tdest/tuser
typedef struct {
    Bit#(data_w) data;
    Bit#(TDiv#(data_w, 8)) keep;
    Bool last;
} AxisBeatS #(numeric type data_w)
    deriving (Bits, Eq, FShow);

interface AxisMasterAdapterS #(numeric type data_w);
    interface AXI4_Stream_Master_IFC #(0, 0, data_w, 0) m_axis;
    interface Put #(AxisBeatS#(data_w)) din;
endinterface

interface AxisSlaveAdapterS #(numeric type data_w);
    interface AXI4_Stream_Slave_IFC #(0, 0, data_w, 0) s_axis;
    interface Get #(AxisBeatS#(data_w)) dout;
endinterface

module mkAxisMasterAdapterS (AxisMasterAdapterS #(data_w))
        provisos (Div#(data_w, 8, TDiv#(data_w, 8)));

    AXI4_Stream_Master_Xactor_IFC #(0, 0, data_w, 0) xatr <- mkAXI4_Stream_Master_Xactor;
    FIFO #(AxisBeatS#(data_w)) sbuf <- mkLFIFO;

    rule wr_ifc (xatr.i_stream.notFull);
        let ub = sbuf.first;
        sbuf.deq;
        let xb = AXI4_Stream {
            tid: 0,
            tdata: ub.data,
            tstrb: ub.keep,
            tkeep: ub.keep,
            tlast: ub.last,
            tdest: 0,
            tuser: 0
        };
        xatr.i_stream.enq(xb);
    endrule

    interface AXI4_Stream_Master_IFC m_axis = xatr.axi_side;
    interface Put din = toPut(sbuf);

endmodule

module mkAxisSlaveAdapterS (AxisSlaveAdapterS #(data_w))
        provisos (Div#(data_w, 8, TDiv#(data_w, 8)));

    AXI4_Stream_Slave_Xactor_IFC #(0, 0, data_w, 0) xatr <- mkAXI4_Stream_Slave_Xactor;
    FIFO #(AxisBeatS#(data_w)) sbuf <- mkLFIFO;

    rule rd_ifc (xatr.o_stream.notEmpty);
        let xb = xatr.o_stream.first;
        xatr.o_stream.deq;
        let ub = AxisBeatS {
            data: xb.tdata,
            keep: xb.tkeep & xb.tstrb,
            last: xb.tlast
        };
        sbuf.enq(ub);
    endrule

    interface AXI4_Stream_Master_IFC s_axis = xatr.axi_side;
    interface Get dout = toGet(sbuf);

endmodule

endpackage : AxisGetPut