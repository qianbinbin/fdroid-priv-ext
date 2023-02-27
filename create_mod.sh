#!/usr/bin/env sh

set -e

error() { echo "$@" >&2; }

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
FPE_OTA_NEW_VC=$(curl -fsSL "https://f-droid.org/api/v1/packages/$FPE_OTA_PKG" | jq '.suggestedVersionCode')
FDROID_OLD_VC=$(sed -n 's/^fdroidVersionCode=//p' module.prop)
FDROID_NEW_VC=$(curl -fsSL "https://f-droid.org/api/v1/packages/$FDROID_PKG" | jq '.suggestedVersionCode')
MOD_NEW_VER=$(date +%Y%m%d)

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
[ "$UPGRADE" != true ] && exit 1

error "==> Fetching info"
INDEX_URL="https://f-droid.org/repo/index-v1.json"
INDEX_JSON="$TMP_DIR/index-v1.json"
curl -L "$INDEX_URL" >"$INDEX_JSON"
FPE_OTA_INFO=$(jq ".packages.\"$FPE_OTA_PKG\" | .[] | select(.versionCode==$FPE_OTA_NEW_VC)" "$INDEX_JSON")
FPE_OTA_ZIP=$(echo "$FPE_OTA_INFO" | jq -r '.apkName')
FPE_OTA_URL="https://f-droid.org/repo/$FPE_OTA_ZIP"
FDROID_INFO=$(jq ".packages.\"$FDROID_PKG\" | .[] | select(.versionCode==$FDROID_NEW_VC)" "$INDEX_JSON")
FDROID_URL="https://f-droid.org/repo/$(echo "$FDROID_INFO" | jq -r '.apkName')"
rm -f "$INDEX_JSON"

error "==> Downloading $FPE_OTA_URL"
curl -L "$FPE_OTA_URL" >"$TMP_DIR/$FPE_OTA_ZIP"
error "==> Extracting files from $FPE_OTA_ZIP"
mkdir -p "$TMP_DIR/system/app/$FDROID_NAME" "$TMP_DIR/system/priv-app/$FPE_NAME" "$TMP_DIR/system/etc/permissions"
unzip "$TMP_DIR/$FPE_OTA_ZIP" "$FPE_NAME.apk" -d "$TMP_DIR/system/priv-app/$FPE_NAME"
unzip "$TMP_DIR/$FPE_OTA_ZIP" permissions_org.fdroid.fdroid.privileged.xml -d "$TMP_DIR/system/etc/permissions"
error "==> Downloading $FDROID_URL"
curl -L "$FDROID_URL" >"$TMP_DIR/system/app/$FDROID_NAME/$FDROID_NAME.apk"
rm -f "$TMP_DIR/$FPE_OTA_ZIP"

error "==> Collecting files"
DUMB_DIR="$TMP_DIR/META-INF/com/google/android"
mkdir -p "$DUMB_DIR"
curl -L https://raw.githubusercontent.com/topjohnwu/Magisk/master/scripts/module_installer.sh >"$DUMB_DIR/update-binary"
chmod +x "$DUMB_DIR/update-binary"
echo "#MAGISK" >"$DUMB_DIR/updater-script"
chmod +x "$DUMB_DIR/updater-script"

sed -i '' "s/^version=.*$/version=$MOD_NEW_VER/g" module.prop
sed -i '' "s/^versionCode=.*$/versionCode=$MOD_NEW_VER/g" module.prop
sed -i '' "s/^fpeOtaVersionCode=.*$/fpeOtaVersionCode=$FPE_OTA_NEW_VC/g" module.prop
sed -i '' "s/^fdroidVersionCode=.*$/fdroidVersionCode=$FDROID_NEW_VC/g" module.prop
cp module.prop customize.sh "$TMP_DIR"

error "==> Creating zip"
FPE_MOD_ZIP="$FPE_PKG.mod_$MOD_NEW_VER.zip"
cd "$TMP_DIR"
zip -r "$OUT_DIR/$FPE_MOD_ZIP" .
cd "$PROG_DIR"
error "$OUT_DIR/$FPE_MOD_ZIP"

CHANGELOG=CHANGELOG.md
error "==> Updating $CHANGELOG"
{
  echo "### $MOD_NEW_VER" && echo
  [ "$FPE_OTA_OLD_VC" -ne "$FPE_OTA_NEW_VC" ] && echo "- $FPE_OTA_PKG $FPE_OTA_OLD_VC -> $FPE_OTA_NEW_VC" && echo
  [ "$FDROID_OLD_VC" -ne "$FDROID_NEW_VC" ] && echo "- $FDROID_PKG $FDROID_OLD_VC -> $FDROID_NEW_VC" && echo
} >"$TMP_DIR/$CHANGELOG"
[ -f "$CHANGELOG" ] && cat CHANGELOG.md >>"$TMP_DIR/$CHANGELOG"
mv "$TMP_DIR/$CHANGELOG" "$CHANGELOG"
