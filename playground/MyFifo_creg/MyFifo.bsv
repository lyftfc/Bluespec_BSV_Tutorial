package MyFifo;

import Vector :: *;

typedef 16 FifoDepthT;
typedef UInt#(32) SizeT;

interface IfcMyFifo #(type dt);
    method Action push (dt d);
    method dt peek ();
    method Action pop ();
endinterface

module mkMyFifo #(parameter Integer depth_not_used) (IfcMyFifo #(dt))
    provisos (Bits #(dt, wt));

    SizeT cDepth = fromInteger(valueOf(FifoDepthT));

    Reg #(SizeT) qHead[2]  <- mkCReg(2, 0);    // Slot for next dequeuing (2-port concurrent register)
    Reg #(SizeT) qTail[2]  <- mkCReg(2, 0);    // Empty slot for next enqueuing (2-port concurrent register)
    // Alternatively, mkConfigReg can be used here, which holds the old value for all rules in that cycle
    //  (Which is, actually, closer to how the traditional Verilog register behaves.)
    // Use Monadic Replicate to initialize all vector elements
    Vector #(FifoDepthT, Reg#(dt)) data <- replicateM(mkReg(?));

    function SizeT nextIndex (SizeT i);
        if (i == cDepth - 1) return 0;
        else return i + 1;
    endfunction

    let currIsEmpty = qHead[0] == qTail[0];
    let currIsFull = nextIndex(qTail[1]) == qHead[1];

    // Push and pop are in conflict as currIsFull/currIsEmpty depends on state of data/qHead/qTail, which they modifies
    method Action push (dt d) if (!currIsFull); 
        data[qTail[1]] <= d;
        qTail[1] <= nextIndex(qTail[1]);
    endmethod

    method Action pop () if (!currIsEmpty);
        qHead[0] <= nextIndex(qHead[0]);
    endmethod

    method dt peek () if (!currIsEmpty);
        return data[qHead[0]];
    endmethod

endmodule

endpackage : MyFifo