package AxiFifoSim;

import Vector::*;
import StmtFSM::*;
import Connectable::*;
import GetPut::*;
import ClientServer::*;
import FShow::*;
import DefaultValue::*;
import TLM3::*;
import Axi4::*;
import FIFO::*;
import Cur_Cycle::*;
import Axi4MstFifo::*;
import Axi4BramSlave::*;

typedef 4   Axi_Id_W;
typedef 64  Axi_Addr_W;
typedef 128 Axi_Data_W;
/* Length fixed to 8b, User fixed to none */

`define AXI4_PRMS \
    Axi_Id_W, Axi_Addr_W, Axi_Data_W
`define AXI4_TLM_REQ_RESP \
    TLMRequest#(`AXI4_PRMS, 8, 0), TLMResponse#(`AXI4_PRMS, 8, 0)
`define AXI4_XATR_PRMS \
    `AXI4_TLM_REQ_RESP, `AXI4_PRMS, 8, 0

typedef Axi4TrxnStreamBeat#(`AXI4_PRMS) AxiTrxnBeat_t;
typedef Axi4TrxnHeader#(`AXI4_PRMS) AxiTrxnHdr_t;
typedef Axi4TrxnPayload#(`AXI4_PRMS) AxiTrxnPayl_t;

module mkAxiFifoSim (Empty);

    Integer sim_rounds = 5;

    Vector #(5, Reg#(UInt#(32))) barr <- mapM(mkReg, map(fromInteger, genVector));
    Reg #(UInt#(8)) count <- mkReg(0);
    Reg #(UInt#(8)) sub_count <- mkReg(0);
    Reg #(UInt#(8)) recv_count <- mkReg(0);

    let {m_req_in, m_axi} <- mkAxi4MstFifo_i;
    let s_axi <- mkAxiBramSlave_64k;

    mkConnection(m_axi, s_axi);

    function Stmt submit_axi_req (Bool isWr, Integer numBytes, UInt#(Axi_Addr_W) addr);
        Integer bytes_per_beat = valueOf(Axi_Data_W) / 8;
        Integer total_dbeats = (numBytes + bytes_per_beat - 1) / bytes_per_beat;
        let send_hdr = (action
            AxiTrxnBeat_t b = tagged Header AxiTrxnHdr_t{
                trxnWrEn: isWr,
                trxnId: 0,
                trxnLen: fromInteger(numBytes),
                trxnAddr: addr
            };
            m_req_in.put(b);
            sub_count <= 0;
            $display("Master sent: ", fshow(b));
        endaction);
        let send_wr_data = (action
            Bit#(Axi_Data_W) u_cnt = extend(pack(count));
            AxiTrxnBeat_t b = tagged Payload AxiTrxnPayl_t{
                trxnData: (u_cnt << 4) | (u_cnt << 2) | extend(pack(sub_count)),
                trxnLast: sub_count + 1 == fromInteger(total_dbeats)
            };
            m_req_in.put(b);
            sub_count <= sub_count + 1;
            $display("Master sent: ", fshow(b));
        endaction);
        return (seq
            send_hdr;
            if (isWr)
                while (sub_count < fromInteger(total_dbeats)) send_wr_data;
        endseq);
    endfunction

    mkAutoFSM (seq
        $display("Simulation start");
        while (count < fromInteger(sim_rounds)) seq
            action
                let t <- cur_cycle;
                $display("Iteration %2d (T =%4d)", barr[count], t);
                count <= count + 1;
            endaction
            // submit_axi_req (count % 3 != 0, 16, extend(count) << 10);
            submit_axi_req (count % 3 != 0, 16, 'h1000);
        endseq
        delay(100);
        // while (recv_count < fromInteger(sim_rounds)) noAction;
    endseq);

    // rule prn_slv_req;
    //     $display("Slave received TLM request: ", fshow(s_req_out.first));
    //     s_req_out.deq;
    //     recv_count <= recv_count + 1;
    // endrule

endmodule

(* synthesize *)
module mkAxi4MstFifo_i (Tuple2 #(
        Put #(Axi4TrxnStreamBeat#(`AXI4_PRMS)),
        Axi4RdWrMaster#(`AXI4_PRMS, 8, 0)
));
    Axi4MstServer#(`AXI4_PRMS) axisrv <- mkAxi4MstServer;
    rule prn_resp;
        let resp <- axisrv.srv_in.response.get;
        $display("Response: ", fshow(resp));
    endrule
    return tuple2(axisrv.srv_in.request, axisrv.aximm_out);
endmodule

(* synthesize *)
module mkAxiBramSlave_64k (Axi4RdWrSlave#(`AXI4_PRMS, 8, 0));
    Axi4RdWrSlave#(`AXI4_PRMS, 8, 0) m <- mkAxi4BramSlave('h0, 'h10000);
    return m;
endmodule

endpackage : AxiFifoSim