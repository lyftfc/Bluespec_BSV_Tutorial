package MyFifo;

interface IfcMyFifo #(type dt);
    method Action push (dt d);
    method dt peek ();
    method Action pop ();
endinterface

module mkMyFifo (IfcMyFifo #(dt))
    provisos (Bits #(dt, wt));

    Reg #(Bool) isEmpty <- mkReg(True);
    Reg #(Bool) isFull  <- mkReg(False);
    Reg #(dt)   data    <- mkReg(?);
    Reg #(Int#(32)) elemCount   <- mkReg(0);

    Int#(32) c_my_fifo_size = 1;

    method Action push (dt d) if (!isFull);
        data <= d;
        isEmpty <= False;
        elemCount <= elemCount + 1;
        if (elemCount + 1 == c_my_fifo_size)
            isFull <= True;
    endmethod

    method Action pop () if (!isEmpty);
        isFull <= False;
        elemCount <= elemCount - 1;
        if (elemCount - 1 == 0)
            isEmpty <= True;
    endmethod

    method dt peek () if (!isEmpty);
        return data;
    endmethod

endmodule


endpackage : MyFifo