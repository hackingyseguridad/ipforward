#!/bin/bash

# Activa IP forwarding en Linux / NAT
# Convierte Linux en un en un enrutador/ puerta de enlace
# www.hackingyseguridad.com
Blanco=$(echo 'printf' '\033[0m')
BlancoAlt=$(echo 'printf' '\033[97m')
$Blanco
cat << "INFO"
  _____             _            
 |  __ \           | |           
 | |__) |___  _   _| |_ ___ _ __ 
 |  _  // _ \| | | | __/ _ \ '__|
 | | \ \ (_) | |_| | ||  __/ |   
 |_|  \_\___/ \__,_|\__\___|_|  V 1.0 
INFO
$BlancoAlt
echo "     http://www.hackingyseguridad.com"
echo
echo "===================================================="
echo "   CONVIERTE ESTE EQUIPO EN UN ROUTER / GATEWAY !   "
echo "===================================================="
echo 
echo ...
$Blanco
echo ipv4 >> /etc/modules
echo ipv6 >> /etc/modules
sysctl -w net.ipv4.ip_forward=1
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sed -i 's/#net.ipv6.conf.all.forwarding=1/net.ipv6.conf.all.forwarding=1/g' /etc/sysctl.conf
sysctl -p
service networking restart
sudo /etc/init.d/procps restart
iptables -L FORWARD -nv
iptables -t nat -I POSTROUTING -o eth0 -j MASQUERADE
