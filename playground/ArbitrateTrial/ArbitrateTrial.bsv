import GPMux::*;
import GetPut::*;
import FIFO::*;

module mkArbitrateTrial ();

    let mux <- mkGPMux_u8_3;
    let demux <- mkGPDemux_u8_2;
    Reg #(UInt#(8)) count <- mkReg(0);

    rule sim_every;
        count <= count + 1;
        $display("[Count: %02d]", count);
        if (count >= 12) $finish;
    endrule

    for (Integer i = 0; i < 3; i = i + 1)
        rule wr_mux;
            mux.din[i].put(fromInteger(i));
            $display("Enqueue %02d", i);
        endrule

    rule rd_mux;
        let d <- mux.dout.get;
        $display("Dequeue %02d, wr. dmx.", d);
        demux.din.put(d);
    endrule

    rule rd_demux_0 (count < 3 || count >= 8);
        let d <- demux.dout[0].get;
        $display("Demux 0: %02d", d);
    endrule
    rule rd_demux_1;
        let d <- demux.dout[1].get;
        $display("Demux 1: %02d", d);
    endrule

endmodule

(* synthesize *)
module mkGPMux_u8_3 (GPMux#(3, UInt#(8)));
    GPMux #(3, UInt#(8)) m <- mkGPMuxRR;
    return m;
endmodule

(* synthesize *)
module mkGPDemux_u8_2 (GPDemux#(2, UInt#(8)));
    GPDemux #(2, UInt#(8)) m <- mkGPDemuxRR;
    return m;
endmodule
