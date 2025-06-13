#!/usr/bin/env python3

import re

from scapy.all import *

class P4tra(Packet):
    name = "P4tra"
    fields_desc = [ StrFixedLenField("P", "P", length=1),
                    StrFixedLenField("Four", "4", length=1),
                    XByteField("version", 0x01),
                    ShortField("identifier", 0),
                    ShortField("quantity", 0),
                    IntField("bought_price", 0xDEADBABE),
                    IntField("current_price", 0xDEADBEEF),
                    ByteField("decision", 0)]

bind_layers(Ether, P4tra, type=0x1234)

class NumParseError(Exception):
    pass

class OpParseError(Exception):
    pass

class Token:
    def __init__(self,type,value = None):
        self.type = type
        self.value = value

def num_parser(s, i, ts):
    pattern = "^\s*([0-9]+)\s*"
    match = re.match(pattern,s[i:])
    if match:
        ts.append(Token('num', match.group(1)))
        return i + match.end(), ts
    raise NumParseError('Expected number literal.')


#def op_parser(s, i, ts):
#    pattern = "^\s*([-+&|^])\s*"
#   match = re.match(pattern,s[i:])
#    if match:
#        ts.append(Token('num', match.group(1)))
#        return i + match.end(), ts
#    raise NumParseError("Expected binary operator '-', '+', '&', '|', or '^'.")


def make_seq(p1, p2):
    def parse(s, i, ts):
        i,ts2 = p1(s,i,ts)
        return p2(s,i,ts2)
    return parse

def get_if():
    ifs=get_if_list()
    iface= "veth0-1" # "h1-eth0"
    #for i in get_if_list():
    #    if "eth0" in i:
    #        iface=i
    #        break;
    #if not iface:
    #    print("Cannot find eth0 interface")
    #    exit(1)
    #print(iface)
    return iface

def main():

    p = make_seq(num_parser, make_seq(num_parser, make_seq(num_parser,num_parser)))
    s = ''
    #iface = get_if()
    iface = "enx0c37965f8a25"

    while True:
        s = input('> ')
        if s == "quit":
            break
        print(s)
        try:
            i,ts = p(s,0,[])
            #print(ts[0].value, ts[1].value, ts[2].value, ts[3].value)
            pkt = Ether(dst='00:04:00:00:00:00', type=0x1234) / P4tra(
            				      identifier=int(ts[0].value),
                                              quantity=int(ts[1].value),
                                              bought_price=int(ts[2].value),
                                              current_price=int(ts[3].value))

            pkt = pkt/' '

            #pkt.show()
            resp = srp1(pkt, iface=iface,timeout=5, verbose=False)
            if resp:
                p4tra=resp[P4tra]
                if p4tra:
                    print(p4tra.decision)
                    print(p4tra.identifier, p4tra.quantity, p4tra.bought_price, p4tra.current_price)
                else:
                    print("cannot find P4tra header in the packet")
            else:
                print("Didn't receive response")
        except Exception as error:
            print(error)


if __name__ == '__main__':
    main()


