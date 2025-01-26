# F-Droid Privileged Extension

With the privileged extension, [F-Droid](https://f-droid.org/en/packages/org.fdroid.fdroid/) can make use of system
permissions to install, update and remove applications on its own.

Instead of installing the [OTA zip file](https://f-droid.org/en/packages/org.fdroid.fdroid.privileged.ota/) from
recovery, now you can install the module from [Magisk](https://github.com/topjohnwu/Magisk) systemlessly, which means it
won't permanently overwrite your system files.

The module is kept up to date via GitHub Actions.

## Installation

You don't have to install F-Droid first.

Download the [zip file](https://github.com/qianbinbin/fdroid-priv-ext/releases) or [build your own module](#Build),
then install it from Magisk and reboot. The F-Droid app with the privileged extension will appear on your phone.

Alternatively, you can install the module via
[MMRL](https://github.com/DerGoogler/MMRL) from [IzzyOnDroid Magisk Repository](https://apt.izzysoft.de/magisk).

### Network Installation

The [netinst version](https://github.com/qianbinbin/fdroid-priv-ext/releases), specifically `org.fdroid.fdroid.privileged.mod.netinst_*.zip`, allows you to install the required files via the Internet.
Create the `/sdcard/.fpe` file to enable mirror:

```
mirror=https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo

# Legal examples:
# https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo
# https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo/
# https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo/?fingerprint=43238D512C1E5EB2D6569F4A3AFBF5523418B82E0A3ED1552770ABB9A9C9CCAB

# Uncomment the following code to disable the mirror:
# mirror=
```

Note that after successful installation, the `/sdcard/.fpe` file will be deleted, but the configuration will be remembered unless the module is removed.

## Build

Simply run:

```sh
$ ./create_mod.sh
```

## Troubleshooting

In some cases, network access of system apps may get disabled by default. Follow these steps to make it work:

> Settings -> Apps -> F-Droid -> Mobile data & Wi-Fi -> Allow network access
