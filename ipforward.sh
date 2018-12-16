#!/bin/bash

# Activa IP forwarding en Linux
# Convierte Linux en un en un enrutador/ puerta de enlace 
# www.hackingyseguridad.com
echo .
echo ipv4 >> /etc/modules
echo .
echo ipv6 >> /etc/modules
sysctl -w net.ipv4.ip_forward=1
echo .
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sed -i 's/#net.ipv6.conf.all.forwarding=1/net.ipv6.conf.all.forwarding=1/g' /etc/sysctl.conf
sysctl -p
echo
echo "===================================================="
echo "   POR FAVOR REINICIALIZA PARA QUE TENGA EFECTO !   "
echo "===================================================="
