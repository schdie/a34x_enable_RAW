#!/system/bin/sh
D=/data/local/tmp/patched_libs
V=/vendor/lib64
LIBS="libmtkcam_metastore.so libmtkcam_3rdparty.customer.so"
PROV=vendor.samsung.hardware.camera.provider-service_64

restart_cam() {
  kill -9 $(pidof $PROV)
  sleep 2
  kill -9 $(pidof cameraserver)
  sleep 3
  echo "provider: $(pidof $PROV)  cameraserver: $(pidof cameraserver)"
}

case "$1" in
on)
  for f in $LIBS; do
    [ -f $D/$f ] || { echo "missing $D/$f"; exit 1; }
    chown root:root $D/$f; chmod 644 $D/$f
    chcon u:object_r:vendor_file:s0 $D/$f
    if nsenter -t 1 -m -- mount | grep -q "$V/$f"; then
      echo "$f already mounted"
    else
      nsenter -t 1 -m -- mount --bind $D/$f $V/$f || exit 1
    fi
  done
  restart_cam
  ;;
off)
  for f in $LIBS; do nsenter -t 1 -m -- umount $V/$f; done
  restart_cam
  ;;
status)
  nsenter -t 1 -m -- mount | grep mtkcam | cut -d' ' -f1-3
  ;;
*)
  echo "usage: sh enableraw_mod.sh on|off|status"
  ;;
esac
