# `image_zoom`

> Status: built
> Tier: 2 (custom element)

## Purpose and API

Click an image to inspect it in a native modal, with Escape and focus restoration.

`image_zoom src, alt:, zoom_src: nil`. Other HTML options go on the custom element. Blank sources raise ArgumentError.

## Design review

Uses the existing neutral palette, inherited type, rounded image edges and ordinary buttons.
The image is the main surface; controls sit below it. No new theme tokens or dependencies.
Reviewed against the server-rendering, custom-element and accessibility conventions.

## Markup and accessibility

Ruby renders the image, named controls and a live status region. Zoom uses a native dialog.
Crop has labeled numeric controls as an alternative to dragging; color sampling has arrow-key
navigation and Enter to select. Errors are announced, and images remain readable without JS.

## Small screens

Images fit their container, control rows wrap, and touch dragging uses pointer capture.
Focus outlines and coarse-pointer targets follow the library. Dark palette pairs are provided.

## Behaviour

`unmagic-image-zoom` adds interaction. Listeners on the element are installed once.
Document listeners are removed on disconnect; cache preparation closes overlays and clears
transient state. New image sources are read when loading or interacting. No Turbo dependency.

## Specs and preview

Cover markup, option validation, passthrough classes and ARIA. Browser examples exercise
keyboard, pointer, light/dark themes and narrow widths. README documents events and I18n.

## Native input comparison

Image color sampling enhances an existing field; native color inputs cannot sample image
pixels across browsers. Keep the native field for manual edits, without a picker dependency.
