#!/system/bin/sh
# Bind-mounts the modded camera libs over /vendor/lib64 (memory only, undone by reboot).
# Put the modded .so files in the SAME folder as this script, then:
#   sh enableraw_mod.sh on|off|status

DIR=$(cd "$(dirname "$0")" && pwd)       # folder this script lives in
D=/data/local/tmp/patched_libs           # staging copy with the right SELinux label
V=/vendor/lib64
LIBS="libmtkcam_metastore.so libmtkcam_3rdparty.customer.so"
PROV=vendor.samsung.hardware.camera.provider-service_64

[ "$(id -u)" = 0 ] || { echo "run as root (su)"; exit 1; }

init_ns() { nsenter -t 1 -m -- "$@"; }

is_mounted() { init_ns mount | grep -q " $V/$1 "; }

loaded_hash() { init_ns sha256sum "$V/$1" | cut -d' ' -f1; }

# lazy unmount (works even while the camera provider has the lib open);
# repeat in case the lib was mounted more than once
unmount_lib() {
  n=0
  while is_mounted "$1" && [ $n -lt 10 ]; do
    init_ns umount -l "$V/$1"
    n=$((n+1))
  done
}

wait_pid() {
  n=0
  while [ -z "$(pidof $1)" ] && [ $n -lt 20 ]; do sleep 1; n=$((n+1)); done
}

restart_cam() {
  p=$(pidof $PROV); [ -n "$p" ] && kill -9 $p
  sleep 2
  c=$(pidof cameraserver); [ -n "$c" ] && kill -9 $c
  wait_pid $PROV
  wait_pid cameraserver
  echo "provider: $(pidof $PROV)  cameraserver: $(pidof cameraserver)"
}

case "$1" in
on)
  for f in $LIBS; do
    [ -f "$DIR/$f" ] || { echo "missing $DIR/$f"; exit 1; }
  done
  mkdir -p "$D"
  for f in $LIBS; do
    unmount_lib "$f"
    # copy to a new file and rename over the old one, so a lib the provider
    # still has mapped is never overwritten in place
    cp "$DIR/$f" "$D/$f.new" || { echo "copy failed: $f"; exit 1; }
    chown root:root "$D/$f.new"
    chmod 644 "$D/$f.new"
    chcon u:object_r:vendor_file:s0 "$D/$f.new"
    mv -f "$D/$f.new" "$D/$f"
    init_ns mount --bind "$D/$f" "$V/$f" || { echo "mount failed: $f"; exit 1; }
  done
  restart_cam
  for f in $LIBS; do
    if [ "$(loaded_hash $f)" = "$(sha256sum "$DIR/$f" | cut -d' ' -f1)" ]; then
      echo "OK   $f is the loaded copy"
    else
      echo "FAIL $f: loaded file differs from $DIR/$f"
    fi
  done
  ;;
off)
  for f in $LIBS; do unmount_lib "$f"; done
  restart_cam
  for f in $LIBS; do
    if is_mounted "$f"; then echo "FAIL $f is still mounted"; else echo "OK   $f unmounted (stock)"; fi
  done
  ;;
status)
  init_ns mount | grep mtkcam | cut -d' ' -f1-3
  for f in $LIBS; do
    echo "$f loaded: $(loaded_hash $f)"
    [ -f "$DIR/$f" ] && echo "$f folder: $(sha256sum "$DIR/$f" | cut -d' ' -f1)"
  done
  ;;
*)
  echo "usage: sh $0 on|off|status"
  ;;
esac
