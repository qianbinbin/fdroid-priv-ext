# F-Droid Privileged Extension

[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/qianbinbin/fdroid-priv-ext/build.yml)](https://github.com/qianbinbin/fdroid-priv-ext/actions/workflows/build.yml)
[![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/qianbinbin/fdroid-priv-ext/total)](https://github.com/qianbinbin/fdroid-priv-ext/releases)
[![GitHub Release](https://img.shields.io/github/v/release/qianbinbin/fdroid-priv-ext)](https://github.com/qianbinbin/fdroid-priv-ext/releases)
[![Dynamic JSON Badge](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapt.izzysoft.de%2Fmagisk%2Fmodules%2Ffdroid-priv-ext%2Fupdate.json&query=%24.versions%5B-1%3A%5D.versionCode&label=izzyondroid)](https://apt.izzysoft.de/magisk)

[![Dynamic Regex Badge](<https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fgithub.com%2Fqianbinbin%2Ffdroid-priv-ext%2Fraw%2Frefs%2Fheads%2Fmaster%2Fmodule.prop&search=fpeOtaVersionCode%3D(.*)&replace=%241&label=org.fdroid.fdroid.privileged.ota>)](https://f-droid.org/en/packages/org.fdroid.fdroid.privileged.ota/)
[![Dynamic Regex Badge](<https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fgithub.com%2Fqianbinbin%2Ffdroid-priv-ext%2Fraw%2Frefs%2Fheads%2Fmaster%2Fmodule.prop&search=fdroidVersionCode%3D(.*)&replace=%241&label=org.fdroid.fdroid>)](https://f-droid.org/en/packages/org.fdroid.fdroid/)

With the privileged extension,
[F-Droid](https://f-droid.org/en/packages/org.fdroid.fdroid/) can make use of
system permissions to install, update and remove applications on its own.

Instead of installing the
[OTA update ZIP file](https://f-droid.org/en/packages/org.fdroid.fdroid.privileged.ota/)
from recovery, now you can install the module from
[Magisk](https://github.com/topjohnwu/Magisk) systemlessly, which means it won't
permanently overwrite your system files.

The module is kept up to date via GitHub Actions.

## Installation

You don't have to install F-Droid app first.

Download the [ZIP file](https://github.com/qianbinbin/fdroid-priv-ext/releases)
or [build your own module](#build), then install it from Magisk and reboot. The
F-Droid app with the privileged extension will appear on your phone.

Alternatively, you can install the module via
[MMRL](https://github.com/MMRLApp/MMRL) from
[IzzyOnDroid Magisk Repository](https://apt.izzysoft.de/magisk).

### Network Installation

The [netinst version](https://github.com/qianbinbin/fdroid-priv-ext/releases),
specifically `org.fdroid.fdroid.privileged.mod.netinst_*.zip`, allows you to
install the required files via the Internet.

Optionally, create the `/sdcard/.fpe` file to downloading from a mirror site,
e.g.:

```
mirror=https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo

# Legal examples:
# https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo
# https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo/
# https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo/?fingerprint=43238D512C1E5EB2D6569F4A3AFBF5523418B82E0A3ED1552770ABB9A9C9CCAB

# Uncomment the following code to disable the mirror:
# mirror=
```

> [!NOTE]
> The mirror only affects the installation process and does not impact the
> F-Droid app configuration.
>
> After successful installation, the `/sdcard/.fpe` file will be deleted, but
> the configuration will persist unless the module is removed.

## Build

Simply run:

```sh
./create_mod.sh
```

## Troubleshooting

In some cases, network access of system apps may get disabled by default. Follow
these steps to make it work:

> Settings -> Apps -> F-Droid -> Mobile data & Wi-Fi -> Allow network access
