set -Eeuo pipefail

: "${BOOT_MODE:="windows"}"

APP="Windows"
SUPPORT="https://github.com/dockur/windows"

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

{ qemu-system-x86_64 ${ARGS:+ $ARGS} >"$QEMU_OUT" 2>"$QEMU_LOG"; rc=$?; } || :
(( rc != 0 )) && log_info "$(<"$QEMU_LOG")" && exit 15

terminal
( sleep 30; boot ) &
tail -fn +0 "$QEMU_LOG" 2>/dev/null &
cat "$QEMU_TERM" 2> /dev/null | tee "$QEMU_PTY" &
wait $! || :

sleep 1 & wait $!
[ ! -f "$QEMU_END" ] && finish 0
