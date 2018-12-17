#!/bin/bash

# Activa IP forwarding en Linux / NAT
# Convierte Linux en un en un enrutador/ puerta de enlace
# www.hackingyseguridad.com
echo ...
echo ipv4 >> /etc/modules
echo ipv6 >> /etc/modules
sysctl -w net.ipv4.ip_forward=1
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sed -i 's/#net.ipv6.conf.all.forwarding=1/net.ipv6.conf.all.forwarding=1/g' /etc/sysctl.conf
sysctl -p
echo
echo "===================================================="
echo "   CONVIERTE ESTE EQUIPO EN UN ROUTER / GATEWAY !   "
echo "===================================================="
iptables -L FORWARD -nv
iptables -t nat -I POSTROUTING -o eth0 -j MASQUERADE
