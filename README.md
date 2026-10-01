After the phone booted:
1. Get root.
2. Create /data/local/tmp/patched_libs
3. Push the .so files there.
4. Run: sh enableraw_mod.sh on

After it worked at least once, every time the phone reboots use 1 and then 4 to get RAW enabled again.

This sets camera2 api to FULL, but should be enough for any gcam to work. Tested on a a34@A16.

Credits: I have no idea who edited the .so files, god bless you.
