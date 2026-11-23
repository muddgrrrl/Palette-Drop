<p align="center">
  <img src="readme-banner.png" width="920" alt="Palette Drop. Pull a color palette from an image · IMAGE → PALETTE · Example swatches.">
</p>

# Palette Drop

Turn a photo, screenshot, or album cover into a small color palette from your Mac terminal. Each swatch can include the better-contrast choice of black or white text.

## At a glance

| Task | How |
| --- | --- |
| **Extract colors** | Pass a local image to get a ranked palette. |
| **Choose the size** | Pass a swatch count after the image path. |
| **Export for another tool** | Choose `css` or `json` as the output format. |

## Quick start

```sh
swift PaletteDrop.swift photo.jpg
swift PaletteDrop.swift cover.png 6 css > palette.css
swift PaletteDrop.swift screenshot.png 5 json
```

Requires macOS with Swift from Apple’s command-line developer tools. ImageIO downsamples the first image or frame into sRGB. The palette combines common colors into buckets, ranks them by frequency, and skips near-duplicate colors. Transparent pixels are ignored, and a nearly monochrome image may yield fewer colors than requested. The image stays on your Mac.

Run `swift PaletteDrop.swift --self-test` to check color ranking and contrast.

[MIT license](LICENSE)
