*Usage:* after the phone booted:
1. Get root.
2. Create the `/data/local/tmp/patched_libs` folder.
3. Push the `.so`, `.xml` and `.sh` file(s) to _a_ folder on the phone.
4. In a root shell run: `sh enableraw_mod.sh on` to enable the mod, `sh enableraw_mod.sh status` for info on the currently loaded files and `sh enableraw_mod.sh off` to use the stock files.
Optional: the script has an optional flag at the top `PATCH_CAMERA_FEATURE=yes`, set it to `PATCH_CAMERA_FEATURE=no` to use the stock `camera-feature.xml` file.

After it worked at least once, every time the phone reboots use `1` and then `4` to get RAW enabled again.

This sets camera2 api to FULL, but should be enough for any gcam to work. Tested on a a34@A16.

Credits: I have no idea who edited the original libmtkcam_metastore.so file, god bless you.
