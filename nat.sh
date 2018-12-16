#!/bin/bash
# Nateo en la eth0
iptables -L FORWARD -nv
iptables -t nat -I POSTROUTING -o eth0 -j MASQUERADE
