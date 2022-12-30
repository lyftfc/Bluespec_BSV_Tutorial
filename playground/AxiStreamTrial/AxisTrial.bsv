import AxisGetPut::*;
import GetPut::*;
import Connectable::*;
import Cur_Cycle::*;

`define PRN_CYCLE \
    $write("[%06d] ", cur_cycle)

typedef 32 DW;

module mkAxisTrial ();

    Reg #(UInt#(DW)) count <- mkReg(0);
    let mst_i <- mkAxisMst_i;
    let slv_i <- mkAxisSlv_i;

    mkConnection(mst_i.m_axis, slv_i.s_axis);

    rule counter_fini (True);
        count <= count + 1;
        if (count >= 20) $finish;
    endrule

    rule enq_payl;
        let b = AxisBeatS {
            data: pack(count),
            keep: '1,
            last: True
        };
        mst_i.din.put(b);
        `PRN_CYCLE;
        $display("ENQ: ", fshow(b));
    endrule

    rule deq_payl (count >= 12 || count < 8);
        let b <- slv_i.dout.get;
        `PRN_CYCLE;
        $display("DEQ: ", fshow(b));
    endrule

    // Reg #(Bool) recv_flag <- mkReg(False);
    // rule detect_recv_once (!recv_flag);
    //     let _u = slv_i.dout.first;
    //     `PRN_CYCLE;
    //     $display("Receive side data ready.");
    //     recv_flag <= True;
    // endrule

endmodule

(* synthesize *)
module mkAxisMst_i (AxisMasterAdapterS #(DW));
    AxisMasterAdapterS #(DW) m <- mkAxisMasterAdapterS;
    return m;
endmodule

(* synthesize *)
module mkAxisSlv_i (AxisSlaveAdapterS #(DW));
    AxisSlaveAdapterS #(DW) m <- mkAxisSlaveAdapterS;
    return m;
endmodule
