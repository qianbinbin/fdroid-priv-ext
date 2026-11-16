# This script will be sourced after all files are extracted, see
# https://topjohnwu.github.io/Magisk/guides.html
# https://github.com/topjohnwu/Magisk/blob/master/scripts/util_functions.sh

MODPATH_OLD="$NVBASE/modules/$MODID"

WELCOME=$(
  cat <<-END
-------------------------------------------------
|    $(read_prop name "$MODPATH/module.prop") - $(read_prop version "$MODPATH/module.prop")    |
|                                               |
| https://github.com/qianbinbin/fdroid-priv-ext |
|                                               |
$(read_prop description "$MODPATH/module.prop" | fold -w 45 -s | while IFS= read -r s; do printf "| %-45s |\n" "$s"; done)
|                                               |
$(printf "| %-45s |\n" "$([ -d "$MODPATH_OLD" ] && echo "Installed: $MODPATH_OLD")")
-------------------------------------------------
END
)

ui_print "$WELCOME"

WARNING=$(
  cat <<-END
-------------------------------------------------
[!WARNING]
[F-Droid Privileged Extension is not currently
supported by F-Droid
2.0](https://f-droid.org/en/2026/09/24/f-droid-2.
0-a-new-chapter-for-android-freedom.html):

> Also, F-Droid Privileged Extension (FPE) is
not currently supported by 2.0. That means even
if FPE is installed, F-Droid 2.0 won’t use it.
This overhaul focused on full featured support
for the Android "session" installer. That lets
F-Droid run background updates on any recent
Android version without requiring FPE. Like with
any of the changes here, we welcome feedback.

If you prefer the traditional unattended
updates, please don't update the F-Droid app.

For potential future support, see
https://gitlab.com/fdroid/fdroidclient/-/work_ite
ms/3376

If you're using the netinst version and have
enabled the mirror, you may encounter a 404
error during installation because the mirror
sites may have removed older F-Droid versions.
Simply disabling the mirror will allow you to
download from the official server.

This module will be paused from updates until a
new privileged extension is released that
supports 2.0.
-------------------------------------------------
END
)

ui_print "$WARNING"

# Permission allowlists are required for Android >= 8.0, see
# https://source.android.com/docs/core/permissions/perms-allowlist
if [ "$API" -lt 26 ]; then
  ui_print "==> API level: $API"
  ui_print "==> Removing the permission allowlist"
  rm -rf "$MODPATH/system/etc"
fi
