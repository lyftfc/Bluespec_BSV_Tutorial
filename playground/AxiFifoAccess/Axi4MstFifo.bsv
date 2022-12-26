package Axi4MstFifo;

import Connectable::*;
import GetPut::*;
import ClientServer::*;
import DefaultValue::*;
import FShow::*;
import TLM3::*;
import Axi4::*;
import FIFO::*;

import Cur_Cycle::*;

export Axi4TrxnHeader(..), Axi4TrxnPayload(..), Axi4TrxnStreamBeat(..);
export Axi4MstServer(..), mkAxi4MstServer;
export mkAxi4MstFifo;

`define BRSTLEN_W   8
`define DLEN_W      12
`define MAX_OTF     8
`define AXI_IFC_PRMS_DCL \
    numeric type id_w, numeric type addr_w, numeric type data_w
`define AXI_IFC_PRMS \
    id_w, addr_w, data_w
`define AXI_TLM_PRMS \
    `AXI_IFC_PRMS, `BRSTLEN_W, 0
`define AXI_XATR_PRMS \
    TLMRequest#(`AXI_TLM_PRMS), TLMResponse#(`AXI_TLM_PRMS), `AXI_TLM_PRMS

typedef struct {
    Bool            trxnWrEn;   // False for read
    UInt#(id_w)     trxnId;
    UInt#(`DLEN_W)  trxnLen;    // Length in bytes
    UInt#(addr_w)   trxnAddr;
} Axi4TrxnHeader #(`AXI_IFC_PRMS_DCL) deriving (Bits, Eq, Bounded);

typedef struct {
    Bool            trxnLast;
    Bit#(data_w)    trxnData;
} Axi4TrxnPayload #(`AXI_IFC_PRMS_DCL) deriving (Bits, Eq, Bounded);

typedef union tagged {
    Axi4TrxnHeader #(`AXI_IFC_PRMS) Header;
    Axi4TrxnPayload #(`AXI_IFC_PRMS) Payload;
} Axi4TrxnStreamBeat #(`AXI_IFC_PRMS_DCL) deriving (Bits, Eq, Bounded);

interface Axi4MstServer #(`AXI_IFC_PRMS_DCL);
    interface Server #(
        Axi4TrxnStreamBeat#(`AXI_IFC_PRMS),
        Axi4TrxnPayload #(`AXI_IFC_PRMS)) srv_in;
    interface Axi4RdWrMaster#(`AXI_TLM_PRMS) aximm_out;
endinterface

module mkAxi4MstServer (Axi4MstServer#(`AXI_IFC_PRMS));
    GetPut #(Axi4TrxnStreamBeat#(`AXI_IFC_PRMS)) cmd_din <- mkGPFIFO1; // {fget, fput}
    GetPut #(Axi4TrxnPayload #(`AXI_IFC_PRMS)) resp_dout <- mkGPFIFO1;
    let axi_cli = (interface Client
        interface Get request = tpl_1(cmd_din);
        interface Put response = tpl_2(resp_dout);
    endinterface);
    let mstfifo <- mkAxi4MstFifo(axi_cli);
    let srvif = (interface Server;
        interface Put request = tpl_2(cmd_din);
        interface Get response = tpl_1(resp_dout);
    endinterface);
    interface Server srv_in = srvif;
    // interface Server srv_in;
    //     interface Put request = tpl_2(cmd_din);
    //     interface Get response = tpl_1(resp_dout);
    // endinterface
    interface Axi4RdWrMaster aximm_out = mstfifo;
endmodule

module mkAxi4MstFifo #(
    Client #(Axi4TrxnStreamBeat#(`AXI_IFC_PRMS),
             Axi4TrxnPayload #(`AXI_IFC_PRMS)) client_in
) (
    Axi4RdWrMaster#(`AXI_TLM_PRMS)
);
    UInt#(`DLEN_W) nbytes_dw = fromInteger(valueOf(TDiv#(data_w, 8)));
    Integer ntrx_shamt = valueOf(TLog#(TDiv#(data_w, 8)));

    Axi4RdWrMasterXActorIFC#(`AXI_XATR_PRMS) m_xatr <- mkAxi4RdWrMaster(`MAX_OTF, False);
    let {qReq, qResp} <- mkTlmMasterFifoWrapper(m_xatr.tlm);

    Reg #(Maybe #(Axi4TrxnHeader #(`AXI_IFC_PRMS))) curr_hdr <- mkReg(tagged Invalid);
    Reg #(UInt #(`BRSTLEN_W)) burst_sent <- mkReg(0);
    Reg #(UInt #(`BRSTLEN_W)) burst_total <- mkReg(0);

    function TLMRequest#(`AXI_TLM_PRMS) prep_tlm_desc (
            Axi4TrxnPayload #(`AXI_IFC_PRMS) d, Axi4TrxnHeader#(`AXI_IFC_PRMS) h);
        RequestDescriptor #(`AXI_TLM_PRMS) desc = defaultValue;
        desc.command = h.trxnWrEn ? WRITE : READ;
        desc.mode = REGULAR;
        desc.addr = pack(h.trxnAddr);
        desc.data = d.trxnData;
        desc.b_length = burst_total - 1;    // 0-based value
        desc.burst_mode = INCR;
        desc.b_size = getMaxBSize(valueOf(data_w));
        desc.transaction_id = pack(h.trxnId);
        return tagged Descriptor desc;
    endfunction

    function TLMRequest#(`AXI_TLM_PRMS) prep_tlm_data (
            Axi4TrxnPayload #(`AXI_IFC_PRMS) d, Axi4TrxnHeader#(`AXI_IFC_PRMS) h);
        RequestData #(`AXI_TLM_PRMS) data = defaultValue;
        data.data = d.trxnData;
        data.transaction_id = pack(h.trxnId);
        data.is_last = burst_sent + 1 >= burst_total || d.trxnLast;
        return tagged Data data;
    endfunction

    rule decode_stream;
        let trxn_beat <- client_in.request.get;
        case (trxn_beat) matches
            tagged Header .hdr: begin
                if (hdr.trxnWrEn) 
                    curr_hdr <= tagged Valid hdr;
                else begin
                    let req = prep_tlm_desc(?, hdr);
                    qReq.enq(req);
                    // $write(cur_cycle, ": ");
                    // $display(fshow(req));
                end
                burst_sent <= 0;
                burst_total <= truncate((hdr.trxnLen + nbytes_dw - 1) >> ntrx_shamt);
            end
            tagged Payload .dt:
                if (curr_hdr matches tagged Valid .hdr) begin
                    TLMRequest#(`AXI_TLM_PRMS) req;
                    if (burst_sent == 0)
                        req = prep_tlm_desc(dt, hdr);
                    else
                        req = prep_tlm_data(dt, hdr);
                    qReq.enq(req);
                    // $write(cur_cycle, ": ");
                    // $display(fshow(req));
                    if (burst_sent + 1 >= burst_total || dt.trxnLast)
                        curr_hdr <= tagged Invalid;
                    burst_sent <= burst_sent + 1;
                end
        endcase
    endrule

    rule pop_resp;
        let resp_b = qResp.first;
        qResp.deq;
        // $write(cur_cycle, ": ");
        // $display(fshow(resp_b));
        if (resp_b.command == READ && resp_b.status == SUCCESS)
            client_in.response.put(Axi4TrxnPayload{
                trxnData: resp_b.data,
                trxnLast: resp_b.is_last
            });
    endrule

    interface Axi4RdMaster read = m_xatr.read.bus;
    interface Axi4WrMaster write = m_xatr.write.bus;
endmodule

module mkTlmMasterFifoWrapper #(
    TLMRecvIFC#(tlmreq_t, tlmresp_t) mst_tlm
) (Tuple2 #(
    FIFO#(tlmreq_t),
    FIFO#(tlmresp_t)
)) provisos (
    Bits#(tlmreq_t, tlmreq_w),
    Bits#(tlmresp_t, tlmresp_w)
);
    FIFO #(tlmreq_t) m_req_in <- mkLFIFO;
    FIFO #(tlmresp_t) m_resp_out <- mkLFIFO;
    mkConnection(toGet(m_req_in), mst_tlm.rx);
    mkConnection(toPut(m_resp_out), mst_tlm.tx);
    return tuple2(m_req_in, m_resp_out);
endmodule

instance FShow#(Axi4TrxnHeader#(`AXI_IFC_PRMS));
   function Fmt fshow (Axi4TrxnHeader#(`AXI_IFC_PRMS) op);
      return ($format("<HDR [%0d] ", op.trxnId) + 
              fshow(op.trxnWrEn ? "WR " : "RD ") +
              $format("%h:%0d>", op.trxnAddr, op.trxnLen));
   endfunction
endinstance

instance FShow#(Axi4TrxnPayload#(`AXI_IFC_PRMS));
   function Fmt fshow (Axi4TrxnPayload#(`AXI_IFC_PRMS) op);
      return ($format("<PAYL %0h ", op.trxnData) + 
              fshow(op.trxnLast ? "(LAST)>" : ">"));
   endfunction
endinstance

instance FShow#(Axi4TrxnStreamBeat#(`AXI_IFC_PRMS));
   function Fmt fshow (Axi4TrxnStreamBeat#(`AXI_IFC_PRMS) op);
      case (op) matches
        tagged Header .hdr: return fshow(hdr);
        tagged Payload .data: return fshow(data);
      endcase
   endfunction
endinstance

endpackage : Axi4MstFifo