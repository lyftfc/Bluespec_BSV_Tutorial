package Axi4TlmConvert;

import Connectable::*;
import GetPut::*;
import FIFO::*;
import TLM3::*;
import Axi4::*;

export Axi4TLMConverter(..);
export mkAxi4BurstReducer;

`include "Axi4Params.defines"

interface Axi4TLMConverter #(`AXI_IFC_PRMS_DCL);
    interface TLMRecvIFC #(`AXI_TLM_REQ_RESP) tlm_in;
    interface TLMSendIFC #(`AXI_TLM_REQ_RESP) tlm_out;
endinterface

module mkAxi4BurstReducer #(Integer max_burst_out)
        (Axi4TLMConverter #(`AXI_IFC_PRMS));
    
    Bit#(addr_w) bytes_per_burst = fromInteger(valueOf(data_w) / 8 * max_burst_out);
    UInt#(`BRSTLEN_W) beats_per_burst = fromInteger(max_burst_out);
    
    Reg #(Maybe #(RequestDescriptor#(`AXI_TLM_PRMS))) curr_desc <- mkReg(tagged Invalid);
    Reg #(UInt#(`BRSTLEN_W)) beat_in_burst <- mkReg(0);
    Reg #(UInt#(`BRSTLEN_W)) rem_beat <- mkRegU;
    
    FIFO #(TLMRequest#(`AXI_TLM_PRMS)) req_in <- mkLFIFO;
    FIFO #(TLMRequest#(`AXI_TLM_PRMS)) req_out <- mkLFIFO;
    FIFO #(TLMResponse#(`AXI_TLM_PRMS)) resp_buf <- mkLFIFO;

    rule translate_start (curr_desc matches Invalid);
        let tlmreq = req_in.first;
        req_in.deq;
        if (tlmreq matches tagged Descriptor .op) begin
            let desc = op;
            rem_beat <= desc.b_length;
            if (desc.command == WRITE && desc.b_length > 0) begin
                beat_in_burst <= min(beats_per_burst - 1, 1);
                desc.b_length = min(beats_per_burst - 1, desc.b_length);
                curr_desc <= tagged Valid desc;
                $display("--- Written desc");
            end else if (desc.command == READ && desc.b_length >= beats_per_burst) begin
                desc.b_length = min(beats_per_burst - 1, desc.b_length);
                curr_desc <= tagged Valid desc;
            end
            $display("--- ", fshow(desc));
            req_out.enq(tagged Descriptor desc);
        end
    endrule

    rule fwd_write (isValid(curr_desc) && curr_desc.Valid.command == WRITE);
        let tlmreq = req_in.first;
        let desc = curr_desc.Valid;
        if (tlmreq matches tagged Data .dt) begin
            if (beat_in_burst == 0) begin
                desc.addr = desc.addr + bytes_per_burst;
                desc.b_length = min(beats_per_burst, rem_beat) - 1;
                if (rem_beat == 1 || dt.is_last)
                    curr_desc <= tagged Invalid;
                else begin
                    rem_beat <= rem_beat - 1;
                    curr_desc <= tagged Valid desc;
                end
                desc.data = dt.data;
                desc.user = dt.user;
                desc.byte_enable = dt.byte_enable;
                desc.transaction_id = dt.transaction_id;
                $display("--- ", fshow(desc));
                req_out.enq(tagged Descriptor desc);
            end else begin
                let cdt = dt;
                if (rem_beat == 1 || dt.is_last) begin
                    curr_desc <= tagged Invalid;
                    cdt.is_last = True;
                end else rem_beat <= rem_beat - 1;
                if (beat_in_burst == beats_per_burst - 1) begin
                    beat_in_burst <= 0;
                    cdt.is_last = True;
                end else beat_in_burst <= beat_in_burst + 1;
                $display("--- ", fshow(cdt));
                req_out.enq(tagged Data cdt);
            end
        end
        else curr_desc <= tagged Invalid;
    endrule

    rule split_read (isValid(curr_desc) && curr_desc.Valid.command == READ);
        let desc = curr_desc.Valid;
        desc.addr = desc.addr + bytes_per_burst;
        if (rem_beat < beats_per_burst - 1) begin
            rem_beat <= 0;
            desc.b_length = rem_beat - 1;
            curr_desc <= tagged Invalid;
        end else begin
            let rem_beat_next = rem_beat - beats_per_burst;
            rem_beat <= rem_beat_next;
            desc.b_length = beats_per_burst - 1;
            if (rem_beat_next == 0)
                curr_desc <= tagged Invalid;
        end
        $display("--- ", fshow(desc));
        req_out.enq(tagged Descriptor desc);
    endrule

    interface TLMRecvIFC tlm_in;
        interface Put rx = toPut(req_in);
        interface Get tx = toGet(resp_buf);
    endinterface
    interface TLMSendIFC tlm_out;
        interface Get tx = toGet(req_out);
        interface Put rx = toPut(resp_buf);
    endinterface
endmodule

endpackage : Axi4TlmConvert