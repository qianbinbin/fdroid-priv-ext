#!/usr/bin/env sh

set -e

error() { echo "$@" >&2; }

USAGE=$(
  cat <<-END
Usage: $0 [OPTION]...

  -e                  early exit if no updates
  -n                  additionally build the netinst version
  -h                  display this help and exit

Home page: <https://github.com/qianbinbin/fdroid-priv-ext>
END
)

_exit() {
  error "$USAGE"
  exit 2
}

EARLY_EXIT=false
NETINST=false
while getopts "enh" c; do
  case $c in
  e) EARLY_EXIT=true ;;
  n) NETINST=true ;;
  h) error "$USAGE" && exit ;;
  *) _exit ;;
  esac
done

shift $((OPTIND - 1))
[ $# -ne 0 ] && _exit

PROG_DIR=$(dirname "$(realpath "$0")")
cd "$PROG_DIR"
OUT_DIR="$PROG_DIR/build"
[ -d "$OUT_DIR" ] || mkdir -p "$OUT_DIR"

TMP_DIR=$(mktemp -d -t fpe.tmp.XXXXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

FDROID_NAME=F-Droid
FPE_NAME=F-DroidPrivilegedExtension
FDROID_PKG=org.fdroid.fdroid
FPE_PKG="$FDROID_PKG.privileged"

FPE_OLD_VC=$(sed -n 's/^fpeVersionCode=//p' module.prop)
[ -n "$FPE_OLD_VC" ] || FPE_OLD_VC=$(sed -n 's/^fpeOtaVersionCode=//p' module.prop) # migrate from ota to apk
# suggestedVersionCode of FPE_PKG is too old, so just use the latest
FPE_NEW_VC=$(curl --compressed -fsSL "https://f-droid.org/api/v1/packages/$FPE_PKG" | jq '.packages.[0].versionCode')
[ -n "$FPE_NEW_VC" ] || { error "Unable to retrieve versionCode of $FPE_PKG" && exit 1; }
FDROID_OLD_VC=$(sed -n 's/^fdroidVersionCode=//p' module.prop)
FDROID_NEW_VC=$(curl --compressed -fsSL "https://f-droid.org/api/v1/packages/$FDROID_PKG" | jq '.suggestedVersionCode')
[ -n "$FDROID_NEW_VC" ] || { error "Unable to retrieve versionCode of $FDROID_PKG" && exit 1; }
if [ "$FDROID_NEW_VC" -ge 2000000 ]; then
  error "==> Exiting for F-Droid $FDROID_NEW_VC"
  error 'F-Droid Privileged Extension (FPE) is not currently supported by 2.0, see'
  error 'https://f-droid.org/en/2026/09/24/f-droid-2.0-a-new-chapter-for-android-freedom.html'
  error 'rework privileged extension and alternate installer support:'
  error 'https://gitlab.com/fdroid/fdroidclient/-/work_items/3376'
  exit 1
fi
MOD_VER=$(sed -n 's/^versionCode=//p' module.prop)

UPGRADE=false
if [ "$FPE_OLD_VC" -eq "$FPE_NEW_VC" ]; then
  error "$FPE_PKG is already the newest version ($FPE_OLD_VC)."
else
  error "==> Upgrading:"
  error "$FPE_PKG $FPE_OLD_VC -> $FPE_NEW_VC"
  UPGRADE=true
fi
if [ "$FDROID_OLD_VC" -eq "$FDROID_NEW_VC" ]; then
  error "$FDROID_PKG is already the newest version ($FDROID_OLD_VC)."
else
  error "==> Upgrading:"
  error "$FDROID_PKG $FDROID_OLD_VC -> $FDROID_NEW_VC"
  UPGRADE=true
fi
if [ "$EARLY_EXIT" = true ] && [ "$UPGRADE" != true ]; then
  exit 0
fi
if [ "$UPGRADE" = true ]; then
  MOD_VER=$(date +%Y%m%d)
fi

error "==> Fetching info"
INDEX_URL="https://f-droid.org/repo/index-v1.json"
INDEX_JSON="$TMP_DIR/index-v1.json"
curl --compressed -fL "$INDEX_URL" >"$INDEX_JSON"
FPE_INFO=$(jq ".packages.\"$FPE_PKG\" | .[] | select(.versionCode==$FPE_NEW_VC)" "$INDEX_JSON")
if [ "$(echo "$FPE_INFO" | jq -r '.hashType')" = sha256 ]; then
  FPE_SHA256=$(echo "$FPE_INFO" | jq -r '.hash')
fi
FPE_URL="https://f-droid.org/repo/$(echo "$FPE_INFO" | jq -r '.apkName')"
FPE_SRC_TARBALL="$(echo "$FPE_INFO" | jq -r '.srcname')"
FPE_SRC_URL="https://f-droid.org/repo/$FPE_SRC_TARBALL"
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

mkdir -p "$TMP_DIR/system/app/$FDROID_NAME" "$TMP_DIR/system/priv-app/$FPE_NAME" "$TMP_DIR/system/etc/permissions"
error "==> Downloading $FPE_URL"
curl -fL -o "$TMP_DIR/system/priv-app/$FPE_NAME/$FPE_NAME.apk" "$FPE_URL"
if [ -n "$FPE_SHA256" ]; then
  error "==> Verifying checksum"
  verify_sha256 "$TMP_DIR/system/priv-app/$FPE_NAME/$FPE_NAME.apk" "$FPE_SHA256"
else
  error "==> Skipping checksum verification"
fi
error "==> Downloading $FPE_SRC_URL"
curl --compressed -fL -o "$TMP_DIR/$FPE_SRC_TARBALL" "$FPE_SRC_URL"
error "==> Extracting permission allowlist from $FPE_SRC_TARBALL"
tar -xf "$TMP_DIR/$FPE_SRC_TARBALL" -C "$TMP_DIR/system/etc/permissions" --strip-components 4 \
  "$FPE_SRC_TARBALL/app/src/main/permissions_org.fdroid.fdroid.privileged.xml"
rm -f "$TMP_DIR/$FPE_SRC_TARBALL"

error "==> Downloading $FDROID_URL"
curl -fL -o "$TMP_DIR/system/app/$FDROID_NAME/$FDROID_NAME.apk" "$FDROID_URL"
if [ -n "$FDROID_SHA256" ]; then
  error "==> Verifying checksum"
  verify_sha256 "$TMP_DIR/system/app/$FDROID_NAME/$FDROID_NAME.apk" "$FDROID_SHA256"
else
  error "==> Skipping checksum verification"
fi

error "==> Collecting files"
DUMB_DIR="$TMP_DIR/META-INF/com/google/android"
mkdir -p "$DUMB_DIR"
curl --compressed -fL -o "$DUMB_DIR/update-binary" https://raw.githubusercontent.com/topjohnwu/Magisk/master/scripts/module_installer.sh
chmod +x "$DUMB_DIR/update-binary"
echo "#MAGISK" >"$DUMB_DIR/updater-script"
chmod +x "$DUMB_DIR/updater-script"

cp customize.sh "$TMP_DIR"
if [ "$UPGRADE" = true ]; then
  sed -e "s/^version=.*$/version=$MOD_VER/g" \
    -e "s/^versionCode=.*$/versionCode=$MOD_VER/g" \
    -e "s/^fpeOtaVersionCode=.*$/fpeVersionCode=$FPE_NEW_VC/g" \
    -e "s/^fpeVersionCode=.*$/fpeVersionCode=$FPE_NEW_VC/g" \
    -e "s/^fdroidVersionCode=.*$/fdroidVersionCode=$FDROID_NEW_VC/g" module.prop >"$TMP_DIR/module.prop"
  cp "$TMP_DIR/module.prop" module.prop
else
  cp module.prop "$TMP_DIR"
fi

error "==> Creating zip"
FPE_MOD_ZIP="$FPE_PKG.mod_$MOD_VER.zip"
cd "$TMP_DIR"
zip -r "$OUT_DIR/$FPE_MOD_ZIP" .
error "$OUT_DIR/$FPE_MOD_ZIP"
if [ "$NETINST" = true ]; then
  FPE_MOD_NETINST_ZIP="$FPE_PKG.mod.netinst_$MOD_VER-beta.zip"
  rm -rf system customize.sh
  cp "$PROG_DIR/customize-netinst.sh" customize.sh
  sed 's/^\(updateJson=.*\)\.json$/\1-netinst.json/g' "$PROG_DIR/module.prop" >module.prop
  zip -r "$OUT_DIR/$FPE_MOD_NETINST_ZIP" .
  error "$OUT_DIR/$FPE_MOD_NETINST_ZIP"
fi
cd "$PROG_DIR"

if [ "$UPGRADE" = true ]; then
  error "==> Updating CHANGELOG"
  {
    echo "### $MOD_VER" && echo
    [ "$FPE_OLD_VC" -ne "$FPE_NEW_VC" ] && echo "- $FPE_PKG $FPE_OLD_VC -> $FPE_NEW_VC" && echo
    [ "$FDROID_OLD_VC" -ne "$FDROID_NEW_VC" ] && echo "- $FDROID_PKG $FDROID_OLD_VC -> $FDROID_NEW_VC" && echo
  } >"$TMP_DIR/CHANGELOG.md"
  [ -f CHANGELOG.md ] && cat CHANGELOG.md >>"$TMP_DIR/CHANGELOG.md"
  mv "$TMP_DIR/CHANGELOG.md" CHANGELOG.md
fi
