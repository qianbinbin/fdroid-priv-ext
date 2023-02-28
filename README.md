# F-Droid Privileged Extension

With the Privileged Extension, [F-Droid](https://f-droid.org/en/packages/org.fdroid.fdroid/) can make use of system
permissions to install, update and remove applications on its own.

Instead of installing the [OTA zip file](https://f-droid.org/en/packages/org.fdroid.fdroid.privileged.ota/) from
recovery, now you can install the module from [Magisk](https://github.com/topjohnwu/Magisk) systemlessly, which means it
won't permanently overwrite your system files.

The module is kept up to date via GitHub Actions.

## Installation

Download the [module zip file](https://github.com/qianbinbin/fdroid-priv-ext/releases) or [build your own](#Build),
install it from Magisk, then reboot.

## Build

Simply run:

```sh
$ ./create_mod.sh
```