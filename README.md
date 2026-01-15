# 5g_enabler

套用 Google Pixel 9 Pro XL 的预设，开启 Pixel 7 设备在中国联通的5G载波聚合组合（N78C）

原项目致谢部分：

### The module is inspired by the following modules and the working principle is taken from them (thanks to the authors):
Universal Modem Fix
Pixel-mdm-patch

The principle of operation is taken from the above modules. However, Universal Modem Fix is not updated by the author for more than a year, and Pixel-mdm-patch on my Pixel 8 stopped catching connection after updating to android 15.
The changes in cfg.db are done using the Displax method:
confnames -> it_iliad -> 2124 -> confmap -> 2124_as_hash -> WILDCARD (0) / PTCRB (20001) / PTCRB_ROW (20005) -> it_iliad_2124_hash
And patching of cfg.db itself is done with sqlite3 (idea like andrew_z1, but he used his own binary and patched only these mcc countries - 250 255 257 400 401 282 283 289).

* at the moment after the update you need to disable or uninstall the module, reboot the phone, install the module again from the storage (Magisk saves modules in the Downloads folder) and reboot again.
