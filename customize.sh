# This script will be sourced after all files are extracted, see
# https://topjohnwu.github.io/Magisk/guides.html
# https://github.com/topjohnwu/Magisk/blob/master/scripts/util_functions.sh

# Permission allowlists are required for Android >= 8.0, see
# https://source.android.com/docs/core/permissions/perms-allowlist
if [ "$API" -lt 26 ]; then
  ui_print "- ==> API level: $API"
  ui_print "- ==> Removing the permission allowlist"
  rm -rf "$MODPATH/system/etc"
fi
