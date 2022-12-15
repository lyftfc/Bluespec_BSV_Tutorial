package MyFifo;

import Vector :: *;

typedef UInt#(32) SizeT;

interface IfcMyFifo #(numeric type depth, type dt);
    method Action push (dt d);
    method dt peek ();
    method Action pop ();
endinterface

module mkMyFifo (IfcMyFifo #(depth, dt))
    provisos (Bits #(dt, wt));

    SizeT cDepth = fromInteger(valueOf(depth));

    Reg #(SizeT) qHead  <- mkReg(0);    // Slot for next dequeuing (2-port concurrent register)
    Reg #(SizeT) qTail  <- mkReg(0);    // Empty slot for next enqueuing (2-port concurrent register)
    Wire #(SizeT) wqh <- mkWire;
    Wire #(SizeT) wqt <- mkWire;
    // Use Monadic Replicate to initialize all vector elements
    Vector #(depth, Reg#(dt)) data <- replicateM(mkReg(?));

    function SizeT nextIndex (SizeT i);
        if (i == cDepth - 1) return 0;
        else return i + 1;
    endfunction

    rule rl_qh_qt;
        wqh <= qHead;
        wqt <= qTail;
    endrule

    let currIsEmpty = wqh == wqt;
    let currIsFull = nextIndex(wqt) == wqh;

    // Push and pop are in conflict as currIsFull/currIsEmpty depends on state of data/qHead/qTail, which they modifies
    method Action push (dt d) if (!currIsFull); 
        data[wqt] <= d;
        qTail <= nextIndex(wqt);
    endmethod

    method Action pop () if (!currIsEmpty);
        qHead <= nextIndex(wqh);
    endmethod

    method dt peek () if (!currIsEmpty);
        return data[wqh];
    endmethod

endmodule

endpackage : MyFifo