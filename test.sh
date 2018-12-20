#Test IP Forwading esta activado en host remoto.
#
#!/bin/bash
for n in `cat ip.txt`
do

route add default gw $n
if ping 8.8.8.8 -c 1 -W 1 > /dev/null
then echo $n "IP forwarding up"
else echo $n "down"

done
