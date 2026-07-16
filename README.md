# ipforward

**Linux como router con IP Forwarding** — scripts para convertir un equipo Linux (Debian/Ubuntu) en un router / puerta de enlace (gateway) capaz de reenviar tráfico entre redes, con soporte de NAT (enmascaramiento) y una utilidad de comprobación remota.

> Fuente: [hackingyseguridad.com](http://www.hackingyseguridad.com/)

---

## Tabla de contenidos

- [¿Qué es IP Forwarding?](#qué-es-ip-forwarding)
- [Esquema de red](#esquema-de-red)
- [Tabla resumen de scripts](#tabla-resumen-de-scripts)
- [Descripción detallada de cada script](#descripción-detallada-de-cada-script)
  - [ipforward.sh](#ipforwardsh)
  - [router.sh](#routersh)
  - [nat.sh](#natsh)
  - [test.sh](#testsh)
- [Flujo de un paquete a través del router](#flujo-de-un-paquete-a-través-del-router)
- [Instalación y uso](#instalación-y-uso)
- [Requisitos](#requisitos)
- [Verificación manual](#verificación-manual)
- [Persistencia de las reglas de NAT](#persistencia-de-las-reglas-de-nat)
- [Solución de problemas](#solución-de-problemas)
- [Consideraciones de seguridad](#consideraciones-de-seguridad)
- [Licencia](#licencia)

---

## ¿Qué es IP Forwarding?

**IP Forwarding** (reenvío de IP) es una función del kernel de Linux que permite que un equipo con **más de una interfaz de red** reenvíe paquetes que no van dirigidos a él mismo, sino a otra red distinta a la que está conectado.

Por defecto, un Linux "de escritorio" o servidor normal **descarta** cualquier paquete que reciba y que no esté destinado a una de sus propias IPs. Al activar `ip_forward`, el kernel empieza a comportarse como un **router**: recibe el paquete por una interfaz, consulta su tabla de rutas y lo reenvía por la interfaz correspondiente hacia su destino final.

```
Sin IP Forwarding:                    Con IP Forwarding:

   Red A                                 Red A
     │                                     │
     ▼                                     ▼
 ┌───────┐                            ┌───────────┐
 │ Linux │  paquete no es para mí     │   Linux    │  reenvía el paquete
 │  (X)  │  ─────────► DESCARTADO     │  (Router)  │ ─────────► Red B
 └───────┘                            └───────────┘
```

Esta capacidad es la base de:

- **Routers/Gateways** que conectan dos o más redes (LAN ↔ Internet, LAN ↔ VLAN, etc.).
- **NAT / Masquerading**, para que varios equipos de una red privada salgan a Internet compartiendo una única IP pública.
- Escenarios de **pentesting** (pivoting, redirección de tráfico) donde se usa un host Linux como puente entre segmentos de red.

---

## Esquema de red

Escenario típico que estos scripts ayudan a construir: un equipo Linux con **dos interfaces de red** actuando de puerta de enlace entre una red interna (LAN) y la red externa (Internet / WAN).

```
                         INTERNET / WAN
                               │
                               │  IP pública (o red externa)
                          ┌────┴────┐
                          │  eth0   │
                    ┌─────┴─────────┴─────┐
                    │                     │
                    │   Linux Router      │   <-- ipforward.sh / router.sh / nat.sh
                    │ (ip_forward = 1)    │
                    │   MASQUERADE eth0   │
                    │                     │
                    └─────┬─────────┬─────┘
                          │  eth1   │
                          └────┬────┘
                               │  Red interna 192.168.1.0/24
              ┌────────────────┼────────────────┐
              │                │                │
         ┌────┴────┐     ┌─────┴────┐     ┌─────┴────┐
         │ Host A   │     │ Host B   │     │ Host C   │
         │192.168.1.10   │192.168.1.11    │192.168.1.12
         └──────────┘     └──────────┘     └──────────┘
```

- `eth0`: interfaz "externa" (hacia Internet o hacia la red que se quiere alcanzar). Sobre ella se aplica el `MASQUERADE`.
- `eth1` (o la interfaz interna que corresponda): conecta con la LAN cuyos equipos usarán este Linux como **puerta de enlace por defecto**.
- Cada host interno debe tener configurada como **gateway** la IP del Linux en su interfaz interna.

---

## Tabla resumen de scripts

| Script | Líneas | Función principal | Modifica el sistema | Requiere `sudo/root` | Persistente tras reinicio |
|---|---|---|---|---|---|
| `ipforward.sh` | 16 | Activa IP Forwarding (IPv4 e IPv6) a nivel de kernel y `sysctl.conf` | Sí (`/etc/modules`, `/etc/sysctl.conf`) | Sí | Sí (vía `sysctl.conf`) |
| `router.sh` | 35 | Igual que `ipforward.sh` + banner informativo + reinicio de servicios de red + reglas NAT | Sí (`/etc/modules`, `/etc/sysctl.conf`, `iptables`) | Sí | Parcial (kernel sí, `iptables` no) |
| `nat.sh` | 4 | Aplica únicamente el enmascaramiento NAT (`MASQUERADE`) sobre `eth0` | Sí (tabla `nat` de `iptables`) | Sí | No (se pierde al reiniciar) |
| `test.sh` | 9 | Comprueba desde un equipo remoto si una lista de IPs actúan correctamente como gateway con forwarding activo | No (solo lectura/red) | No (recomendable sí, para `route add`) | N/A |

---

## Descripción detallada de cada script

### `ipforward.sh`

Script mínimo cuyo único objetivo es **activar el reenvío de paquetes IPv4 e IPv6** en el kernel de Linux, tanto en caliente (`sysctl -w`) como de forma persistente (editando `/etc/sysctl.conf`).

```bash
#!/bin/bash
echo ipv4 >> /etc/modules
echo ipv6 >> /etc/modules
sysctl -w net.ipv4.ip_forward=1
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sed -i 's/#net.ipv6.conf.all.forwarding=1/net.ipv6.conf.all.forwarding=1/g' /etc/sysctl.conf
sysctl -p
```

**Qué hace paso a paso:**

1. Añade las cadenas `ipv4` e `ipv6` a `/etc/modules` (carga de módulos al arrancar).
2. Activa `net.ipv4.ip_forward=1` en caliente con `sysctl -w` (efecto inmediato, no persistente por sí solo).
3. Descomenta la línea `#net.ipv4.ip_forward=1` en `/etc/sysctl.conf` mediante `sed`, para que el ajuste sobreviva a un reinicio.
4. Hace lo mismo para IPv6 (`net.ipv6.conf.all.forwarding=1`).
5. Recarga la configuración con `sysctl -p`.
6. Muestra un aviso recomendando reiniciar el equipo.

> ⚠️ **Nota:** el `sed` solo funciona si esas líneas ya existen comentadas en `sysctl.conf` (es el caso por defecto en Debian/Ubuntu). Si el fichero no contiene esa línea exacta, el `sed` no tendrá efecto y habrá que añadirla manualmente.

---

### `router.sh`

Versión "completa" y más vistosa del script anterior. Hace todo lo que hace `ipforward.sh`, pero además:

- Muestra un **banner ASCII** de bienvenida con colores.
- Reinicia el servicio de red (`service networking restart`) y el pseudo-sistema de procesos (`procps`) para aplicar cambios sin reiniciar el equipo por completo.
- Incluye directamente las reglas de `iptables` para el **NAT/Masquerade** sobre `eth0`, dejando el equipo listo como router en una sola ejecución.

```bash
#!/bin/bash
# Activa IP forwarding en Linux / NAT
# Convierte Linux en un enrutador/ puerta de enlace

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
```

**Qué hace paso a paso:**

1. Muestra el banner y la cabecera informativa del script.
2. Activa IP Forwarding igual que `ipforward.sh` (kernel + persistencia en `sysctl.conf`).
3. Reinicia el servicio `networking` y `procps` para que los cambios de red y de kernel se apliquen sin necesidad de un reinicio completo del sistema.
4. Muestra las reglas actuales de la cadena `FORWARD` (`iptables -L FORWARD -nv`), útil para verificar el estado antes de añadir la regla NAT.
5. Inserta una regla de **MASQUERADE** en la cadena `POSTROUTING` de la tabla `nat`, para que todo el tráfico saliente por `eth0` se traduzca a la IP de esa interfaz (NAT dinámico, ideal cuando `eth0` tiene IP dinámica/DHCP).

> 💡 Es, en la práctica, la combinación de `ipforward.sh` + `nat.sh` en un solo script, con extras cosméticos y de reinicio de servicios.

---

### `nat.sh`

Script muy pequeño centrado exclusivamente en la parte de **NAT (enmascaramiento)**. Asume que el IP Forwarding ya está activo (por ejemplo, ejecutado previamente `ipforward.sh` o `router.sh`).

```bash
#!/bin/bash
# Nateo en la eth0
iptables -L FORWARD -nv
iptables -t nat -I POSTROUTING -o eth0 -j MASQUERADE
```

**Qué hace paso a paso:**

1. Lista las reglas actuales de la cadena `FORWARD` en formato numérico y con contadores (`-n` = no resolver nombres, `-v` = verbose).
2. Inserta (`-I`, al principio de la cadena) una regla de `MASQUERADE` en `POSTROUTING`, dentro de la tabla `nat`, para la interfaz de salida `eth0`.

**Efecto:** todo el tráfico que salga hacia Internet (o hacia la red al otro lado de `eth0`) desde los hosts de la LAN interna aparecerá con la IP de `eth0` como origen, permitiendo que varias máquinas privadas compartan una única IP pública.

> ⚠️ Esta regla **no es persistente**: se pierde al reiniciar `iptables` o el equipo. Ver la sección [Persistencia de las reglas de NAT](#persistencia-de-las-reglas-de-nat).

---

### `test.sh`

Script de **verificación remota**, pensado para ejecutarse en un equipo distinto al router (por ejemplo, un host de la LAN o de una red externa), para comprobar si una lista de direcciones IP están funcionando correctamente como puerta de enlace con IP Forwarding activo.

```bash
#Test IP Forwarding esta activado en host remoto.
#!/bin/bash
for n in `cat ip.txt`
do route add default gw $n
if ping 8.8.8.8 -c 1 -W 1 > /dev/null
then echo $n "IP forwarding up"
fi
done
```

**Qué hace paso a paso:**

1. Lee, línea a línea, el fichero `ip.txt` (que el usuario debe crear con una IP candidata a gateway por línea).
2. Para cada IP `$n`, la configura como **puerta de enlace por defecto** (`route add default gw $n`) en el equipo desde el que se ejecuta el test.
3. Lanza un único `ping` (`-c 1`, con timeout `-W 1` segundo) contra `8.8.8.8` (DNS público de Google) para comprobar conectividad real a Internet a través de esa IP.
4. Si el `ping` tiene éxito, imprime `<IP> IP forwarding up`, confirmando que ese host reenvía tráfico correctamente.

**Requisito previo:** crear un fichero `ip.txt` en el mismo directorio, con una IP por línea:

```text
192.168.1.1
192.168.1.254
10.0.0.1
```

> ⚠️ Este script modifica la tabla de rutas del equipo donde se ejecuta (`route add default gw`) en cada iteración, sin eliminar la ruta anterior. En sistemas con `iproute2` moderno puede no existir el comando `route` (paquete `net-tools`); instálalo con `apt install net-tools` si es necesario, o adapta el script a `ip route replace default via $n`.

---

## Flujo de un paquete a través del router

```
 Host LAN (192.168.1.10)
        │
        │ 1. Envía paquete a 8.8.8.8
        ▼
 ┌─────────────────────────────┐
 │        Linux Router         │
 │                              │
 │  eth1 (in)                  │
 │     │                       │
 │     ▼                       │
 │  [ ip_forward = 1 ] ───────►│  2. El kernel decide reenviar
 │     │                       │     (en vez de descartar)
 │     ▼                       │
 │  iptables: FORWARD          │  3. Reglas de filtrado (si existen)
 │     │                       │
 │     ▼                       │
 │  iptables: nat/POSTROUTING  │  4. MASQUERADE: cambia IP origen
 │     │                       │     192.168.1.10 → IP de eth0
 │     ▼                       │
 │  eth0 (out)                 │
 └──────────┬───────────────────┘
            │ 5. Sale hacia Internet con IP pública
            ▼
        Internet (8.8.8.8)
```

Al recibir la respuesta, el proceso es inverso: `iptables` recuerda (mediante `conntrack`) qué host interno originó la conexión y **des-enmascara** el paquete de vuelta hacia `192.168.1.10`.

---

## Instalación y uso

```bash
# 1. Clonar el repositorio
git clone https://github.com/hackingyseguridad/ipforward
cd ipforward

# 2. Dar permisos de ejecución
chmod +x ipforward.sh router.sh nat.sh test.sh

# 3a. Opción rápida: activar todo en un solo paso (forwarding + NAT)
sudo ./router.sh

# 3b. Opción por partes:
sudo ./ipforward.sh   # solo activa IP forwarding
sudo ./nat.sh          # solo aplica NAT/MASQUERADE sobre eth0

# 4. (Opcional) Verificar desde otro host que el router funciona
echo "192.168.1.1" > ip.txt
sudo ./test.sh
```

> Sustituye `eth0` en `nat.sh` / `router.sh` por el nombre real de tu interfaz **externa** (comprueba con `ip a` — en sistemas modernos suele llamarse `enp0s3`, `ens33`, etc., en lugar de `eth0`).

---

## Requisitos

| Requisito | Detalle |
|---|---|
| Sistema operativo | Linux basado en Debian/Ubuntu (usa `/etc/sysctl.conf` y `service networking`) |
| Privilegios | root o `sudo` (modifican kernel, `iptables` y ficheros de sistema) |
| Paquetes | `iptables`, `procps`; opcionalmente `net-tools` para el comando `route` usado en `test.sh` |
| Interfaces de red | Al menos 2 interfaces (una interna, una externa) para actuar como router real |

---

## Verificación manual

Comandos útiles para comprobar el estado sin depender de los scripts:

```bash
# ¿Está activo IP forwarding?
cat /proc/sys/net/ipv4/ip_forward     # 1 = activo, 0 = inactivo
sysctl net.ipv4.ip_forward

# ¿Qué reglas NAT hay activas?
sudo iptables -t nat -L POSTROUTING -nv

# ¿Qué reglas de forwarding hay activas?
sudo iptables -L FORWARD -nv

# Ver interfaces y sus IPs
ip a
```

---

## Persistencia de las reglas de NAT

`nat.sh` y la parte de `iptables` de `router.sh` **no sobreviven a un reinicio**. Para hacerlas persistentes:

```bash
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

O, alternativamente, añadir la ejecución de `nat.sh` a un servicio `systemd` o a `/etc/rc.local`.

---

## Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| Los hosts de la LAN no salen a Internet | `ip_forward` no activo o regla `MASQUERADE` no aplicada | Verifica con `cat /proc/sys/net/ipv4/ip_forward` y `iptables -t nat -L` |
| El `sed` de `ipforward.sh` no modifica `sysctl.conf` | La línea comentada no existe tal cual en el fichero | Añade manualmente `net.ipv4.ip_forward=1` al final de `/etc/sysctl.conf` |
| `route: command not found` en `test.sh` | Falta el paquete `net-tools` | `sudo apt install net-tools`, o reescribe el script con `ip route` |
| Las reglas de NAT desaparecen al reiniciar | `iptables` no es persistente por defecto | Instala `iptables-persistent` (ver sección anterior) |
| `router.sh` falla al reiniciar `networking` | Distribuciones modernas usan `NetworkManager`/`systemd-networkd` en vez de `service networking` | Reinicia el servicio de red correspondiente a tu distro, o simplemente reinicia el equipo |

---

## Consideraciones de seguridad

- Activar IP Forwarding convierte el equipo en un **punto de tránsito de tráfico**: revisa siempre las reglas `FORWARD` de `iptables` para no dejar la red completamente abierta entre segmentos.
- El `MASQUERADE` oculta las IPs internas, pero **no sustituye a un firewall**: complementa estos scripts con reglas de filtrado (`iptables -A FORWARD ...`) según la política de seguridad de tu red.
- En entornos de laboratorio o pentesting, recuerda **desactivar el forwarding** (`sysctl -w net.ipv4.ip_forward=0`) y eliminar las reglas NAT al terminar, si el equipo no debe seguir actuando como router.

---

## Licencia

Este proyecto se distribuye bajo los términos indicados en el fichero [`LICENSE`](./LICENSE) del repositorio.

---

<http://www.hackingyseguridad.com/>
