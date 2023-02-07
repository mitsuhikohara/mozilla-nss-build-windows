# mozilla-nss-build-windows

This script build Mozilla NSS with NSPR on Windows

**Usage:**

$ nss-build-windows.sh [-v|-l|-c] `<NSS source directory>`

    NSS source directory: top directory of NSS with NSPR source (e. nss-3.87)
    -v: vervose option (for debug)
    -l: legacy build using make
    -c: clean up build artifacts

Original build instruction is described in

[Firefox Source Documentation - building NSS](https://firefox-source-docs.mozilla.org/security/nss/legacy/building/index.html)

Unfortunately build did not succeed and need some modifications are required.
It is reason why nss-build-windows.sh is developed

## Pre-requisite

Following build environments are required

* Bash

  * [Git for Windows](https://gitforwindows.org/)
* Make

  * [Make for Windows (sourceforge.net)](https://gnuwin32.sourceforge.net/packages/make.htm)
* Visual Studio

  * Visual Studio 2022 Community Version
    [Visual Studio Tools Download](https://visualstudio.microsoft.com/ja/downloads/)
* MozillaBuild　[MozillaBuild - MozillaWiki](https://wiki.mozilla.org/MozillaBuild)
* gyp　[GYP - Generate Your Projects. (gsrc.io)](https://gyp.gsrc.io/)

  * Use python3 which is contained in MozillaBuild
* ninja [Ninja, a small build system with a focus on speed (ninja-build.org)](https://ninja-build.org/)

These command path should be set in Windows Environment Variables. For Visual Studio, NSS build script updates appropriately.

## Build Instruction

To build using legacy make

$ nss-build-windows.sh -l `<Firefox NSS source top directory>`

To build using gyp/ninja

$ nss-build-windows.sh `<Firefox NSS source top directory>`

## Knwon Issue and Limitation

This script is tested on the following configuration

* Windows: Windows 11 Home 22H2 22621.1105 Japanese
* Mozilla NSS+NSPR source : nss-3.87-with-nspr-4.35.tar.gz

* Visual Studio Code: 1.75.0
* bash : GNU bash, version 4.4.23(2)-release (x86_64-pc-msys)

* make : GNU Make 3.81
* Visual Studio : Visual Studio Community 2022 17.4.33213.308

* ninja : 1.11.1
* gyp: 0.1

## References

[Releases — Firefox Source Docs documentation (mozilla.org)](https://firefox-source-docs.mozilla.org/security/nss/releases/index.html)
