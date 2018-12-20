#Test IP Forwading esta activado en host remoto.
#!/bin/bash
for n in `cat ip.txt`
do

route add default gw $n
ping 8.8.8.8
route del default gw $n

done
