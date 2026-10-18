# With `SKIPUNZIP=1`, the script will be sourced without extracting files,
# otherwise the script will be sourced after all files have been extracted, see
# https://topjohnwu.github.io/Magisk/guides.html
# https://github.com/topjohnwu/Magisk/blob/master/scripts/util_functions.sh
SKIPUNZIP=1

FDROID_NAME=F-Droid
FPE_NAME=F-DroidPrivilegedExtension
FDROID_PKG=org.fdroid.fdroid
FPE_PKG="$FDROID_PKG.privileged"

# The config file will be removed by default
# mirror=https://f-droid.org/repo
CONFIG_FILE=/sdcard/.fpe

MODPATH_OLD="$NVBASE/modules/$MODID"

unzip -oq "$ZIPFILE" module.prop -d "$MODPATH"

read_prop() {
  key="$1"
  shift
  cat "$@" 2>/dev/null | sed -n "s/^$key=//p" 2>/dev/null | head -n 1
}

FPE_VC=$(read_prop fpeVersionCode "$MODPATH/module.prop")
FDROID_VC=$(read_prop fdroidVersionCode "$MODPATH/module.prop")

WELCOME=$(
  cat <<-END
-------------------------------------------------
|    $(read_prop name "$MODPATH/module.prop") - $(read_prop version "$MODPATH/module.prop")    |
|                                               |
| https://github.com/qianbinbin/fdroid-priv-ext |
|                                               |
$(read_prop description "$MODPATH/module.prop" | fold -w 45 -s | while IFS= read -r s; do printf "| %-45s |\n" "$s"; done)
|                                               |
$(printf "| %-45s |\n" "$([ -f "$CONFIG_FILE" ] && echo "Config: $CONFIG_FILE")")
$(printf "| %-45s |\n" "$([ -d "$MODPATH_OLD" ] && echo "Installed: $MODPATH_OLD")")
-------------------------------------------------
END
)

ui_print "$WELCOME"

# https://f-droid.org/repo/FILE -> https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo/FILE
MIRROR=
if grep -qs '^mirror=$' "$CONFIG_FILE"; then
  ui_print "==> Disabling mirror"
else
  MIRROR=$(read_prop mirror "$CONFIG_FILE" "$MODPATH_OLD/module.prop")
  # busybox grep doesn't support \? and group capturing
  MIRROR=$(echo "$MIRROR" | grep -o -e '^https\{0,1\}://.*/repo$' -e '^https\{0,1\}://.*/repo/')
  case "$MIRROR" in
  */) MIRROR="${MIRROR%/}" ;;
  esac
fi
if [ -n "$MIRROR" ]; then
  ui_print "==> Using mirror: $MIRROR"
  echo "mirror=$MIRROR" >>"$MODPATH/module.prop"
fi

mirrorify() {
  if [ -n "$MIRROR" ]; then
    sed "s|https://f-droid.org/repo|$MIRROR|g"
  else
    cat
  fi
}

FPE_APK="${FPE_PKG}_$FPE_VC.apk"
FPE_URL=$(echo "https://f-droid.org/repo/$FPE_APK" | mirrorify)
FPE_SRC_TARBALL="${FPE_PKG}_${FPE_VC}_src.tar.gz"
FPE_SRC_URL=$(echo "https://f-droid.org/repo/$FPE_SRC_TARBALL" | mirrorify)
FDROID_APK="${FDROID_PKG}_$FDROID_VC.apk"
FDROID_URL=$(echo "https://f-droid.org/repo/$FDROID_APK" | mirrorify)

# There's no mirror for URL like https://verification.f-droid.org/FILE.json
# so we use the bulky index-v1.json
INDEX_JSON="index-v1.json"
INDEX_URL=$(echo "https://f-droid.org/repo/$INDEX_JSON" | mirrorify)
ui_print "==> Downloading $INDEX_URL"
curl --compressed -fL -o "$TMPDIR/$INDEX_JSON" "$INDEX_URL" || abort "Unable to download"
find "$TMPDIR/$INDEX_JSON"

# May be unstable but we have no `jq`
get_sha256() {
  # Some tricks to speed up searching
  tr '{}[]' '\n' <"$TMPDIR/$INDEX_JSON" | grep -F "\"apkName\": \"$1\"" | sed -n "s/.*\"hash\": \"\([0-9a-f]\{64\}\)\", \"hashType\": \"sha256\".*/\1/p"
}

verify_sha256() {
  actual=$(sha256sum "$1" | awk '{ print $1 }')
  if [ "$actual" != "$2" ]; then
    ui_print "$actual != $2"
    return 1
  fi
}

ui_print "==> Extracting sha256 for $FPE_APK"
FPE_SHA256=$(get_sha256 "$FPE_APK")
if [ -n "$FPE_SHA256" ]; then ui_print "$FPE_SHA256"; else ui_print "Unable to extract"; fi
ui_print "==> Extracting sha256 for $FDROID_APK"
FDROID_SHA256=$(get_sha256 "$FDROID_APK")
if [ -n "$FDROID_SHA256" ]; then ui_print "$FDROID_SHA256"; else ui_print "Unable to extract"; fi

ui_print "==> Downloading $FPE_URL"
mkdir -p "$MODPATH/system/priv-app/$FPE_NAME"
curl -fL -o "$MODPATH/system/priv-app/$FPE_NAME/$FPE_NAME.apk" "$FPE_URL" || abort "Unable to download"
find "$MODPATH/system/priv-app/$FPE_NAME/$FPE_NAME.apk"
if [ -n "$FPE_SHA256" ]; then
  ui_print "Verifying checksum"
  verify_sha256 "$MODPATH/system/priv-app/$FPE_NAME/$FPE_NAME.apk" "$FPE_SHA256" || abort "Unable to download"
else
  ui_print "Skipping checksum verification"
fi
# Permission allowlists are required for Android >= 8.0, see
# https://source.android.com/docs/core/permissions/perms-allowlist
if [ "$API" -ge 26 ]; then
  ui_print "==> Downloading $FPE_SRC_URL for API level $API"
  mkdir -p "$MODPATH/system/etc/permissions"
  curl -fL -o "$TMPDIR/$FPE_SRC_TARBALL" "$FPE_SRC_URL" || abort "Unable to download"
  find "$TMPDIR/$FPE_SRC_TARBALL"
  ui_print "==> Extracting permission allowlist"
  tar -xf "$TMPDIR/$FPE_SRC_TARBALL" -C "$MODPATH/system/etc/permissions" --strip-components 4 \
    "$FPE_SRC_TARBALL/app/src/main/permissions_org.fdroid.fdroid.privileged.xml" || abort "Unable to extract"
  find "$MODPATH/system/etc/permissions/permissions_org.fdroid.fdroid.privileged.xml"
fi

ui_print "==> Downloading $FDROID_URL"
mkdir -p "$MODPATH/system/app/$FDROID_NAME"
curl -fL -o "$MODPATH/system/app/$FDROID_NAME/$FDROID_NAME.apk" "$FDROID_URL" || abort "Unable to download"
find "$MODPATH/system/app/$FDROID_NAME/$FDROID_NAME.apk"
if [ -n "$FDROID_SHA256" ]; then
  ui_print "Verifying checksum"
  verify_sha256 "$MODPATH/system/app/$FDROID_NAME/$FDROID_NAME.apk" "$FDROID_SHA256" || abort
else
  ui_print "Skipping checksum verification"
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644

if [ -f "$CONFIG_FILE" ]; then
  ui_print "==> Deleting $CONFIG_FILE"
  rm "$CONFIG_FILE"
fi

ui_print "==> Installed files:"
find "$MODPATH/system" -type f | sed "s|$MODPATH/||g"
ui_print "==> Reboot and enjoy!"
