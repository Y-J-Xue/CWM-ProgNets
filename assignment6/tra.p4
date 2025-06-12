/* -*- P4_16 -*- */

/*
 * P4 Algorithmic Trading
 *
 * This program implements a simple protocol. It can be carried over Ethernet
 * (Ethertype 0x1234).
 *
 * The Protocol header looks like this:
 *
 *        0                1                  2              3
 * +----------------+----------------+----------------+---------------+
 * |      P         |       4        |     Version    |     Act       |
 * +----------------+----------------+----------------+---------------+
 * |            Identifier           |             Quantity           |
 * +----------------+----------------+----------------+---------------+
 * |                           Bought Price                           |
 * +----------------+----------------+----------------+---------------+
 * |                          Current Price                           |
 * +----------------+----------------+----------------+---------------+
 *
 * P is an ASCII Letter 'P' (0x50)
 * 4 is an ASCII Letter '4' (0x34)
 * Version is currently 0.1 (0x01)
 * Act is an action to take: (buy = 0, sell =1)
 *	If receiving 0, Act = 1
  *	If receiving 1, Act = 0
 * Identifier: name of the stock
 * Quantity: quantity of the stock held, or to be transacted
 * Bought Price: price of the stock when bought
 * Current Price: price of the stock currently
 *
 * The device receives a packet containing the quantity and price information of a stock, decides if to buy or sell stocks and the quantity to buy or sell, and sends the packet back out of the same port it came in on, while swapping the source and destination addresses.
 *
 * If the message is not valid, the packet is dropped.
 */

#include <core.p4>
#include <v1model.p4>

/*
 * Define the headers the program will recognize
 */

/*
 * Standard Ethernet header
 */
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

/*
 * This is a custom protocol header. We'll use
 * etherType 0x1234 for it (see parser)
 */
const bit<16> P4TRA_ETYPE = 0x1234;
const bit<8>  P4CALC_P    = 0x50;   // 'P'
const bit<8>  P4CALC_4    = 0x34;   // '4'
const bit<8>  P4CALC_VER  = 0x01;   // v0.1
const bit<8>  P4TRA_BUY   = 0;
const bit<8>  P4TRA_SELL  = 1;

header p4tra_t {
    bit<8>  p;
    bit<8>  four;
    bit<8>  ver;
    bit<8>  act;
    bit<16>  id;
    bit<16>  Q;
    bit<32>  P1;
    bit<32>  P2;
}

/*
 * All headers, used in the program needs to be assembled into a single struct.
 * We only need to declare the type, but there is no need to instantiate it,
 * because it is done "by the architecture", i.e. outside of P4 functions
 */
struct headers {
    ethernet_t   ethernet;
    p4tra_t      p4tra;
}

/*
 * All metadata, globally used in the program, also  needs to be assembled
 * into a single struct. As in the case of the headers, we only need to
 * declare the type, but there is no need to instantiate it,
 * because it is done "by the architecture", i.e. outside of P4 functions
 */

struct metadata {
    /* In our case it is empty */
}

/*************************************************************************
 ***********************  P A R S E R  ***********************************
 *************************************************************************/
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            P4TRA_ETYPE  : check_p4tra;
            default      : accept;
        }
    }

    state check_p4tra {
    
        transition select(packet.lookahead<p4tra_t>().p,
        packet.lookahead<p4tra_t>().four,
        packet.lookahead<p4tra_t>().ver) {
            (P4TRA_P, P4TRA_4, P4TRA_VER)    : parse_p4tra;
            default                          : accept;
        }
        
    }


    state parse_p4tra {
        packet.extract(hdr.p4tra);
        transition accept;
    }
}

/*************************************************************************
 ************   C H E C K S U M    V E R I F I C A T I O N   *************
 *************************************************************************/
control MyVerifyChecksum(inout headers hdr,
                         inout metadata meta) {
    apply { }
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    bit<48> tmp;
    action send_back(bit<8>   decision,
     		     bit<16>  quantity) {
        /* TODO
         * - put ...
         * - swap MAC addresses in hdr.ethernet.dstAddr and
         *   hdr.ethernet.srcAddr using a temp variable
         * - Send the packet back to the port it came from
             by saving standard_metadata.ingress_port into
             standard_metadata.egress_spec
         */
         hdr.p4tra.act = decision;
         hdr.p4tra.Q = quantity;

         tmp = hdr.ethernet.dstAddr;
         hdr.ethernet.dstAddr = hdr.ethernet.srcAddr;
         hdr.ethernet.srcAddr = tmp;
         standard_metadata.egress_spec = standard_metadata.ingress_port;
    }

    action buy() {
        send_back(0,
        	  hdr.p4tra.Q * 0.5);
    }

    action sell() {
        send_back(1,
        	  hdr.p4tra.Q * 0.5);
    }
101
    action act_drop() {
        mark_to_drop(standard_metadata);
    }

    table calculate {
        key = {
            hdr.p4tra.P1 < hdr.p4tra.P2  : exact;
        }
        actions = {
            buy;
            sell;
            act_drop;
        }
        const default_action = act_drop();
        const entries = {
            P4TRA_BUY : buy();
            P4TRA_SELL: sell();
        }
    }

    apply {
        if (hdr.p4tra.isValid()) {
            calculate.apply();
        } else {
            act_drop();
        }
    }
}

/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
}

/*************************************************************************
 *************   C H E C K S U M    C O M P U T A T I O N   **************
 *************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/*************************************************************************
 ***********************  D E P A R S E R  *******************************
 *************************************************************************/
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.p4tra);
    }
}

/*************************************************************************
 ***********************  S W I T T C H **********************************
 *************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
