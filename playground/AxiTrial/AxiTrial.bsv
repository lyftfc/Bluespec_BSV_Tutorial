package AxiTrial;

import Vector::*;
import StmtFSM::*;
import Connectable::*;
import GetPut::*;
import FShow::*;
import DefaultValue::*;
import TLM3::*;
import Axi4::*;
import FIFO::*;
import Cur_Cycle::*;

typedef 4   Axi_Id_W;
typedef 64  Axi_Addr_W;
typedef 128 Axi_Data_W;
/* Length fixed to 8b, User fixed to none */

`define AXI4_TLM_PRMS \
    Axi_Id_W, Axi_Addr_W, Axi_Data_W, 8, 0
`define AXI4_XATR_PRMS \
    TLMRequest#(`AXI4_TLM_PRMS), TLMResponse#(`AXI4_TLM_PRMS), `AXI4_TLM_PRMS

module mkAxiTrial (Empty);

    Vector #(5, Reg#(UInt#(32))) barr <- mapM(mkReg, map(fromInteger, genVector));
    Reg #(UInt#(8)) count <- mkReg(0);

    function Bool axi4_slv_addr(Bit#(addr_size) addr);
        return addr >= 'h1000 && addr < 'h2000;
    endfunction

    Axi4RdWrMasterXActorIFC#(`AXI4_XATR_PRMS) m_xatr <- mkAxi4RdWrMaster(8, False);
    Axi4RdWrSlaveXActorIFC#(`AXI4_XATR_PRMS) s_xatr <- mkAxi4RdWrSlave(True, axi4_slv_addr);

    mkConnection(m_xatr.read, s_xatr.read);
    mkConnection(m_xatr.write, s_xatr.write);

    let {m_req_in, m_resp_out} <- mkTlmMasterFifoWrapper(m_xatr.tlm);
    let {s_req_out, s_resp_in} <- mkTlmSlaveFifoWrapper(s_xatr.tlm);

    mkAutoFSM (seq
        $display("Simulation start");
        while (count < 5) seq
            action
                $display("Iteration %2d", barr[count]);
                count <= count + 1;
                let {x, y} = tuple2(3, 4);
            endaction
            action
                RequestDescriptor#(`AXI4_TLM_PRMS) req_desc = defaultValue;
                let u_cnt = pack(count);
                req_desc.addr = extend(u_cnt) << 10;
                req_desc.data = extend((u_cnt << 4) | u_cnt);
                TLMRequest#(`AXI4_TLM_PRMS) axireq = tagged Descriptor req_desc;
                $display("Master sent TLM request: ", fshow(axireq));
                m_req_in.enq(axireq);
            endaction
            action
                RequestData#(`AXI4_TLM_PRMS) req_data = defaultValue;
                let u_cnt = pack(count);
                req_data.data = extend((u_cnt << 4) | (u_cnt << 2) | u_cnt);
                TLMRequest#(`AXI4_TLM_PRMS) axireq = tagged Data req_data;
                $display("Master sent TLM request: ", fshow(axireq));
                m_req_in.enq(axireq);
            endaction
        endseq
    endseq);

    rule prn_slv_req;
        $display("Slave received TLM request: ", fshow(s_req_out.first));
        s_req_out.deq;
    endrule

    // rule prn_cyc;
    //     $display("Current cycle: ", fshow(curr_cycle), fshow(s_xatr.read.addrMatch(req_desc.addr)));
    // endrule

endmodule

module mkTlmMasterFifoWrapper #(TLMRecvIFC#(tlmreq_t, tlmresp_t) mst_tlm)
        (Tuple2 #(FIFO#(tlmreq_t), FIFO#(tlmresp_t)))
        provisos (Bits#(tlmreq_t, tlmreq_w), Bits#(tlmresp_t, tlmresp_w));
    FIFO #(tlmreq_t) m_req_in <- mkLFIFO;
    FIFO #(tlmresp_t) m_resp_out <- mkLFIFO;
    mkConnection(toGet(m_req_in), mst_tlm.rx);
    mkConnection(toPut(m_resp_out), mst_tlm.tx);
    return tuple2(m_req_in, m_resp_out);
endmodule

module mkTlmSlaveFifoWrapper #(TLMSendIFC#(tlmreq_t, tlmresp_t) slv_tlm)
        (Tuple2 #(FIFO#(tlmreq_t), FIFO#(tlmresp_t)))
        provisos (Bits#(tlmreq_t, tlmreq_w), Bits#(tlmresp_t, tlmresp_w));
    FIFO #(tlmreq_t) s_req_out <- mkLFIFO;
    FIFO #(tlmresp_t) s_resp_in <- mkLFIFO;
    mkConnection(toGet(s_resp_in), slv_tlm.rx);
    mkConnection(toPut(s_req_out), slv_tlm.tx);
    return tuple2(s_req_out, s_resp_in);
endmodule

// ====== AXI4 Crossbar Inst ======

// (* synthesize *)
// module mkAxi4Xbar_64a512_2x1 (Axi4Xbar #(2, 1, `AXI4_TLM_PRMS))
//     Axi4Xbar #(2, 1, `AXI4_TLM_PRMS) xb <- mkAxi4Xbar;
//     return m;
// endmodule

// ====== AXI4 Crossbar ======

/*

`define AXI4_XBARIF_PRMS_DCL \
    numeric type num_ups, numeric type num_downs, \
    numeric type id_w, numeric type addr_w, numeric type data_w

`define AXI4_XBARIF_PRMS \
    num_ups, num_downs, id_w, addr_w, data_w

`define AXI4_XBAR_PRMS \
    id_w, addr_w, data_w, 8, 0

`define AXI4_XBAR_XATR_PRMS \
    TLMRequest#(`AXI4_XBAR_PRMS), TLMResponse#(`AXI4_XBAR_PRMS), `AXI4_XBAR_PRMS

interface Axi4Xbar #(`AXI4_XBARIF_PRMS_DCL);
    interface Vector #(num_ups, Axi4RdWrSlave #(id_w, addr_w, data_w, 8, 0)) upstream;
    interface Vector #(num_downs, Axi4RdWrMaster #(id_w, addr_w, data_w, 8, 0)) downstream;
endinterface

module mkAxi4Xbar #(
    parameter UInt#(32) max_flight
) (Axi4Xbar #(`AXI4_XBARIF_PRMS));

    function Bool addr_match(Bit#(addr_size) addr);
        return True;    // TODO: replace with real per-port implementation
    endfunction

    Vector #(num_ups, Axi4RdWrSlaveXActorIFC#(`AXI4_XBAR_XATR_PRMS))
        ups_xatr_ifcs <- replicateM(mkAxi4RdWrSlave(True, addr_match));
    Vector #(num_downs, Axi4RdWrMasterXActorIFC#(`AXI4_XBAR_XATR_PRMS))
        downs_xatr_ifcs <- replicateM(mkAxi4RdWrMaster(max_flight, False));

endmodule

*/

endpackage : AxiTrial