# Changelog

## 0.4
* Make av-scenechange JSON parsing more lenient, as they added some new fields in the latest version of the CLI that we
don't need.

## 0.3
* Fixed handling of windows line endings with qpfiles, per https://github.com/adworacz/zscene/issues/2

## 0.2
* Add QP file support, per https://github.com/adworacz/zscene/issues/1
* Updated to Zig 0.15.2

## 0.1
* Initial release
* Add `ReadScenes` function.
* Support [av-scenechange](https://github.com/rust-av/av-scenechange) scenes file.
