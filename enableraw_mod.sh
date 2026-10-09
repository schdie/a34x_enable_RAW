#!/system/bin/sh
# Bind-mounts the modded camera libs (and optionally camera-feature.xml) over the
# system copies. Memory only, undone by reboot.
# Put the modded files in the SAME folder as this script, then:
#   sh enableraw_mod.sh on|off|status

# ---------------- settings ----------------
# yes = also mount camera-feature.xml (from this folder) over /system/cameradata
# no  = leave camera-feature.xml stock (and unmount it if it was mounted)
PATCH_CAMERA_FEATURE=yes
# ------------------------------------------

DIR=$(cd "$(dirname "$0")" && pwd)       # folder this script lives in
D=/data/local/tmp/patched_libs           # staging copy with the right SELinux label
V=/vendor/lib64
LIBS="libmtkcam_metastore.so libmtkcam_3rdparty.customer.so"
FEATURE=camera-feature.xml
FEATURE_PATH=/system/cameradata/$FEATURE
PROV=vendor.samsung.hardware.camera.provider-service_64
CAMAPP=com.sec.android.app.camera

[ "$(id -u)" = 0 ] || { echo "run as root (su)"; exit 1; }

init_ns() { nsenter -t 1 -m -- "$@"; }

# the functions below take the full target path
is_mounted() { init_ns mount | grep -q " $1 "; }

loaded_hash() { init_ns sha256sum "$1" | cut -d' ' -f1; }

# lazy unmount (works even while the camera provider has the file open);
# repeat in case it was mounted more than once
unmount_path() {
  n=0
  while is_mounted "$1" && [ $n -lt 10 ]; do
    init_ns umount -l "$1"
    n=$((n+1))
  done
}

# mount_file <name in DIR> <target path> <fallback selinux label>
mount_file() {
  f=$1; target=$2; fallback=$3
  unmount_path "$target"                       # so we read the stock label below
  label=$(stat -c %C "$target" 2>/dev/null)
  case "$label" in u:object_r:*) ;; *) label=$fallback ;; esac
  # copy to a new file and rename over the old one, so a file the
  # provider still has mapped is never overwritten in place
  cp "$DIR/$f" "$D/$f.new" || { echo "copy failed: $f"; return 1; }
  chown root:root "$D/$f.new"
  chmod 644 "$D/$f.new"
  chcon "$label" "$D/$f.new"
  mv -f "$D/$f.new" "$D/$f"
  init_ns mount --bind "$D/$f" "$target" || { echo "mount failed: $target"; return 1; }
}

# check_loaded <name in DIR> <target path>
check_loaded() {
  if [ "$(loaded_hash "$2")" = "$(sha256sum "$DIR/$1" | cut -d' ' -f1)" ]; then
    echo "OK   $2 is the loaded copy"
  else
    echo "FAIL $2: loaded file differs from $DIR/$1"
  fi
}

check_unmounted() {
  if is_mounted "$1"; then echo "FAIL $1 is still mounted"; else echo "OK   $1 unmounted (stock)"; fi
}

wait_pid() {
  n=0
  while [ -z "$(pidof $1)" ] && [ $n -lt 20 ]; do sleep 1; n=$((n+1)); done
}

restart_cam() {
  am force-stop $CAMAPP
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
  if [ "$PATCH_CAMERA_FEATURE" = yes ]; then
    [ -f "$DIR/$FEATURE" ] || { echo "missing $DIR/$FEATURE (or set PATCH_CAMERA_FEATURE=no)"; exit 1; }
  fi
  mkdir -p "$D"
  for f in $LIBS; do
    mount_file "$f" "$V/$f" u:object_r:vendor_file:s0 || exit 1
  done
  if [ "$PATCH_CAMERA_FEATURE" = yes ]; then
    mount_file "$FEATURE" "$FEATURE_PATH" u:object_r:system_file:s0 || exit 1
  else
    unmount_path "$FEATURE_PATH"
  fi
  restart_cam
  for f in $LIBS; do check_loaded "$f" "$V/$f"; done
  if [ "$PATCH_CAMERA_FEATURE" = yes ]; then
    check_loaded "$FEATURE" "$FEATURE_PATH"
  else
    check_unmounted "$FEATURE_PATH"
  fi
  ;;
off)
  for f in $LIBS; do unmount_path "$V/$f"; done
  unmount_path "$FEATURE_PATH"
  restart_cam
  for f in $LIBS; do check_unmounted "$V/$f"; done
  check_unmounted "$FEATURE_PATH"
  ;;
status)
  echo "PATCH_CAMERA_FEATURE=$PATCH_CAMERA_FEATURE"
  init_ns mount | grep -E "mtkcam|cameradata" | cut -d' ' -f1-3
  for f in $LIBS; do
    echo "$f loaded: $(loaded_hash "$V/$f")"
    [ -f "$DIR/$f" ] && echo "$f folder: $(sha256sum "$DIR/$f" | cut -d' ' -f1)"
  done
  echo "$FEATURE loaded: $(loaded_hash "$FEATURE_PATH")"
  [ -f "$DIR/$FEATURE" ] && echo "$FEATURE folder: $(sha256sum "$DIR/$FEATURE" | cut -d' ' -f1)"
  ;;
*)
  echo "usage: sh $0 on|off|status"
  ;;
esac
