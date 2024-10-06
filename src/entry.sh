#!/usr/bin/env bash
set -Eeuo pipefail

: "${BOOT_MODE:="windows"}"

APP="Windows"
SUPPORT="https://github.com/giliover/giliover-win"

cd /run || exit 1

check_script() {
    local script_name="$1"
    if [[ ! -f "$script_name" ]]; then
        echo "Error: Script $script_name not found!"
        exit 1
    fi
}

log_info() {
    echo "[INFO] $1"
}

SCRIPTS=("reset.sh" "define.sh" "mido.sh" "install.sh" "disk.sh" "display.sh" "network.sh" "samba.sh" "boot.sh" "proc.sh" "power.sh" "config.sh")
for script in "${SCRIPTS[@]}"; do
    check_script "$script"
    log_info "Running $script..."
    . "$script"
done

trap - ERR

version=$(qemu-system-x86_64 --version | head -n 1 | cut -d '(' -f 1 | awk '{ print $NF }')
log_info "Booting ${APP}${BOOT_DESC} using QEMU v$version..."

: "${QEMU_OUT:="/run/qemu_output.log"}"
: "${QEMU_LOG:="/run/qemu_log.log"}"
: "${QEMU_TERM:="/run/qemu_term"}"
: "${QEMU_PTY:="/run/qemu_pty"}"
: "${QEMU_END:="/run/qemu_end"}"

export NO_AT_BRIDGE=1

set -Eeuo pipefail

if [[ "$ARGS" == *"-display vnc"* ]]; then
  ARGS="${ARGS//-display vnc=:0,websocket=5700 -vga virtio/-display gtk -vga std}"
fi

ARGS="${ARGS//-drive file=\/storage\/win7x64.iso,id=cdrom9,format=raw,cache=unsafe,readonly=on,media=cdrom,if=none/}"
ARGS="${ARGS//-device ich9-ahci,id=ahci9,addr=0x5/}"
ARGS="${ARGS//-device ide-cd,drive=cdrom9,bus=ahci9.0,bootindex=9/}"

CPU_ARG=$(echo "$ARGS" | grep -oP '(?<=-cpu )[^ ]+')
MEM_ARG=$(echo "$ARGS" | grep -oP '(?<=-m )[^ ]+')
SMP_ARG=$(echo "$ARGS" | grep -oP '(?<=-smp )[^ ]+')
DRIVE=$(echo "$ARGS" | grep -oP '(?<=-drive )[^ ]+')
MACHINE=$(echo "$ARGS" | grep -oP '(?<=-machine )[^ ]+')
MONITOR=$(echo "$ARGS" | grep -oP '(?<=-monitor )[^ ]+')
NETDEV=$(echo "$ARGS" | grep -oP '(?<=-netdev )[^ ]+')
NAME=$(echo "$ARGS" | grep -oP '(?<=-name )[^ ]+')
DEVICES=$(echo "$ARGS" | grep -oP '(-device [^ ]+)')


echo "CPU: $CPU_ARG"
echo "Memory: $MEM_ARG"
echo "SMP: $SMP_ARG"
echo "Devices: $DEVICES"
echo "Drive: $DRIVE"
echo "Monitor: $MONITOR"
echo "Machine: $MACHINE"
echo "Netdev: $NETDEV"
echo "Global: $NAME"


{
qemu-system-x86_64 \
    -nodefaults \
    -cpu $CPU_ARG \
    -smp $SMP_ARG \
    -m $MEM_ARG \
    -machine $MACHINE \
    -monitor $MONITOR \
    -enable-kvm \
    -display gtk \
    -vga virtio \
    -daemonize -D /run/shm/qemu.log -pidfile /run/shm/qemu.pid \
    -name $NAME \
    -serial pty \
    -netdev $NETDEV \
    -drive $DRIVE \
    -rtc base=localtime \
    -global kvm-pit.lost_tick_policy=discard \
    -global ICH9-LPC.disable_s3=1 \
    -global ICH9-LPC.disable_s4=1 \
    -object iothread,id=io2 \
    -object rng-random,id=objrng0,filename=/dev/urandom \
    $DEVICES

} || :
(( rc != 0 )) && log_info "$(<"$QEMU_LOG")" && exit 15

terminal
( sleep 30; boot ) &
tail -fn +0 "$QEMU_LOG" 2>/dev/null &
cat "$QEMU_TERM" 2> /dev/null | tee "$QEMU_PTY" &
wait $! || :

sleep 1 & wait $!
[ ! -f "$QEMU_END" ] && finish 0
