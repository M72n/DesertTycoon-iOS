# Desert Tycoon Visual Upgrade Policy

This project preserves gameplay behavior and upgrades only visual/audio packaging assets.

## Allowed Changes

- Replace raster images with higher-resolution versions that preserve the original composition.
- Add upscaled assets under `LegacyAssets/iphone-hd-upscaled`.
- Prefer upscaled assets at runtime, with fallback to the original `iphone-hd` assets.
- Update sprite metadata only when coordinate scaling is required by an asset resolution change.
- Improve app icons, splash images, menus, and interface textures without changing gameplay timing or balance.
- Generate full map PNGs from original TMX metadata when SpriteKit needs a renderable map asset.
- Rebuild mechanics only when names/assets/strings are evidenced by the APK, and keep uncertain values isolated.

## Not Allowed Without Original Source Verification

- Changing movement speed, progression, economy, task order, map rules, or win conditions.
- Reordering sprite frames in a way that changes animation timing.
- Replacing original gameplay logic inferred from Android bytecode with new behavior.
- Removing fallback access to the original extracted assets.
- Adding fake objectives, economy counters, shops, or character movement that is not verified from the original source.
- Claiming exact gameplay parity while the original C++ source remains unavailable.

## Runtime Asset Resolution

The iOS app should resolve assets in this order:

1. `LegacyAssets/iphone-hd-upscaled` or app-bundle root `iphone-hd-upscaled`
2. `LegacyAssets/iphone-hd` or app-bundle root `iphone-hd`
3. top-level preview assets in `Resources`

This keeps the visual upgrade reversible and protects the original game presentation while the iOS port is rebuilt.
