#!/usr/bin/env sh

set -e

error() { echo "$@" >&2; }

USAGE=$(
  cat <<-END
Usage: $0 [OPTION]...

  -e                  early exit if no updates
  -h                  display this help and exit

Home page: <https://github.com/qianbinbin/fdroid-priv-ext>
END
)

_exit() {
  error "$USAGE"
  exit 2
}

EARLY_EXIT=false
while getopts "eh" c; do
  case $c in
  e) EARLY_EXIT=true ;;
  h) error "$USAGE" && exit ;;
  *) _exit ;;
  esac
done

shift $((OPTIND - 1))
[ $# -ne 0 ] && _exit

PROG_DIR=$(dirname "$(realpath "$0")")
cd "$PROG_DIR"
OUT_DIR="$PROG_DIR/build"
[ ! -d "$OUT_DIR" ] && mkdir -p "$OUT_DIR"

TMP_DIR=$(mktemp -d -t fpe.tmp.XXXXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

FDROID_NAME=F-Droid
FPE_NAME=F-DroidPrivilegedExtension
FDROID_PKG=org.fdroid.fdroid
FPE_PKG="$FDROID_PKG.privileged"
FPE_OTA_PKG="$FPE_PKG.ota"

FPE_OTA_OLD_VC=$(sed -n 's/^fpeOtaVersionCode=//p' module.prop)
FPE_OTA_NEW_VC=$(curl --compressed -fsSL "https://f-droid.org/api/v1/packages/$FPE_OTA_PKG" | jq '.suggestedVersionCode')
FDROID_OLD_VC=$(sed -n 's/^fdroidVersionCode=//p' module.prop)
FDROID_NEW_VC=$(curl --compressed -fsSL "https://f-droid.org/api/v1/packages/$FDROID_PKG" | jq '.suggestedVersionCode')
MOD_VER=$(sed -n 's/^versionCode=//p' module.prop)

UPGRADE=false
if [ "$FPE_OTA_OLD_VC" -eq "$FPE_OTA_NEW_VC" ]; then
  error "$FPE_OTA_PKG is already the newest version ($FPE_OTA_OLD_VC)."
else
  error "==> Upgrading:"
  error "$FPE_OTA_PKG $FPE_OTA_OLD_VC -> $FPE_OTA_NEW_VC"
  UPGRADE=true
fi
if [ "$FDROID_OLD_VC" -eq "$FDROID_NEW_VC" ]; then
  error "$FDROID_PKG is already the newest version ($FDROID_OLD_VC)."
else
  error "==> Upgrading:"
  error "$FDROID_PKG $FDROID_OLD_VC -> $FDROID_NEW_VC"
  UPGRADE=true
fi
[ "$EARLY_EXIT" = true ] && [ "$UPGRADE" != true ] && exit
[ "$UPGRADE" = true ] && MOD_VER=$(date +%Y%m%d)

error "==> Fetching info"
INDEX_URL="https://f-droid.org/repo/index-v1.json"
INDEX_JSON="$TMP_DIR/index-v1.json"
curl --compressed -L "$INDEX_URL" >"$INDEX_JSON"
FPE_OTA_INFO=$(jq ".packages.\"$FPE_OTA_PKG\" | .[] | select(.versionCode==$FPE_OTA_NEW_VC)" "$INDEX_JSON")
FPE_OTA_ZIP=$(echo "$FPE_OTA_INFO" | jq -r '.apkName')
if [ "$(echo "$FPE_OTA_INFO" | jq -r '.hashType')" = sha256 ]; then
  FPE_OTA_SHA256=$(echo "$FPE_OTA_INFO" | jq -r '.hash')
fi
FPE_OTA_URL="https://f-droid.org/repo/$FPE_OTA_ZIP"
FDROID_INFO=$(jq ".packages.\"$FDROID_PKG\" | .[] | select(.versionCode==$FDROID_NEW_VC)" "$INDEX_JSON")
if [ "$(echo "$FDROID_INFO" | jq -r '.hashType')" = sha256 ]; then
  FDROID_SHA256=$(echo "$FDROID_INFO" | jq -r '.hash')
fi
FDROID_URL="https://f-droid.org/repo/$(echo "$FDROID_INFO" | jq -r '.apkName')"
rm -f "$INDEX_JSON"

verify_sha256() {
  actual=$(sha256sum "$1" | awk '{ print $1 }')
  if [ "$actual" != "$2" ]; then
    error "$actual != $2"
    return 1
  fi
}

error "==> Downloading $FPE_OTA_URL"
curl -L "$FPE_OTA_URL" >"$TMP_DIR/$FPE_OTA_ZIP"
if [ -n "$FPE_OTA_SHA256" ]; then
  error "==> Verifying checksum"
  verify_sha256 "$TMP_DIR/$FPE_OTA_ZIP" "$FPE_OTA_SHA256"
else
  error "==> Skipping checksum verification"
fi
error "==> Extracting files from $FPE_OTA_ZIP"
mkdir -p "$TMP_DIR/system/app/$FDROID_NAME" "$TMP_DIR/system/priv-app/$FPE_NAME" "$TMP_DIR/system/etc/permissions"
unzip "$TMP_DIR/$FPE_OTA_ZIP" "$FPE_NAME.apk" -d "$TMP_DIR/system/priv-app/$FPE_NAME"
unzip "$TMP_DIR/$FPE_OTA_ZIP" permissions_org.fdroid.fdroid.privileged.xml -d "$TMP_DIR/system/etc/permissions"

error "==> Downloading $FDROID_URL"
curl -L "$FDROID_URL" >"$TMP_DIR/system/app/$FDROID_NAME/$FDROID_NAME.apk"
if [ -n "$FDROID_SHA256" ]; then
  error "==> Verifying checksum"
  verify_sha256 "$TMP_DIR/system/app/$FDROID_NAME/$FDROID_NAME.apk" "$FDROID_SHA256"
else
  error "==> Skipping checksum verification"
fi
rm -f "$TMP_DIR/$FPE_OTA_ZIP"

error "==> Collecting files"
DUMB_DIR="$TMP_DIR/META-INF/com/google/android"
mkdir -p "$DUMB_DIR"
curl --compressed -L https://raw.githubusercontent.com/topjohnwu/Magisk/master/scripts/module_installer.sh >"$DUMB_DIR/update-binary"
chmod +x "$DUMB_DIR/update-binary"
echo "#MAGISK" >"$DUMB_DIR/updater-script"
chmod +x "$DUMB_DIR/updater-script"

cp customize.sh "$TMP_DIR"
if [ "$UPGRADE" = true ]; then
  sed -e "s/^version=.*$/version=$MOD_VER/g" \
    -e "s/^versionCode=.*$/versionCode=$MOD_VER/g" \
    -e "s/^fpeOtaVersionCode=.*$/fpeOtaVersionCode=$FPE_OTA_NEW_VC/g" \
    -e "s/^fdroidVersionCode=.*$/fdroidVersionCode=$FDROID_NEW_VC/g" module.prop >"$TMP_DIR/module.prop"
  cp "$TMP_DIR/module.prop" module.prop
else
  cp module.prop "$TMP_DIR"
fi

error "==> Creating zip"
FPE_MOD_ZIP="$FPE_PKG.mod_$MOD_VER.zip"
cd "$TMP_DIR"
zip -r "$OUT_DIR/$FPE_MOD_ZIP" .
cd "$PROG_DIR"
error "$OUT_DIR/$FPE_MOD_ZIP"

if [ "$UPGRADE" = true ]; then
  error "==> Updating CHANGELOG"
  {
    echo "### $MOD_VER" && echo
    [ "$FPE_OTA_OLD_VC" -ne "$FPE_OTA_NEW_VC" ] && echo "- $FPE_OTA_PKG $FPE_OTA_OLD_VC -> $FPE_OTA_NEW_VC" && echo
    [ "$FDROID_OLD_VC" -ne "$FDROID_NEW_VC" ] && echo "- $FDROID_PKG $FDROID_OLD_VC -> $FDROID_NEW_VC" && echo
  } >"$TMP_DIR/CHANGELOG.md"
  [ -f CHANGELOG.md ] && cat CHANGELOG.md >>"$TMP_DIR/CHANGELOG.md"
  mv "$TMP_DIR/CHANGELOG.md" CHANGELOG.md
fi
