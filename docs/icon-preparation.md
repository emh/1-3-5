# App icon

Source: [icon.png](icon.png), supplied by the owner. The source is preserved unchanged.

Production assets: `ExerciseSnacks/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-light.png` (Any/Light) and `AppIcon.png` (Dark), both opaque 1024 × 1024 PNGs. Matching variants in `BrandIcon.imageset` follow the app’s selected theme. iOS chooses the Home Screen variant independently using its icon appearance setting.

Prepared with the built-in image generation tool to remove the mockup's white surround and extend the dark surface into square corners. The resulting image was resized to the required asset dimensions with macOS `sips`. iOS applies the final rounded corner mask.

Prompt used:

> Use case: precise-object-edit. Asset type: production iOS app icon, 1024 by 1024 pixel opaque square PNG. Input image is the exact edit target, not a style inspiration. Prepare this supplied app icon for Xcode. Remove the surrounding white mockup padding entirely, and remove the pre-rounded silhouette by extending the existing near-black interior surface continuously to all four edges and corners of the square canvas. The result must be full bleed near-black with no white anywhere, no transparency, no border, no rounded outer corners, no outer shadow. Preserve the icon's existing central artwork as faithfully as possible: the exact large mint-green monospaced text '1·3·5', the muted green top arc and the two muted green lower arc segments, their relative positions, proportions, spacing, color, and restrained surface treatment. Scale the original dark icon area to fill the square while preserving comfortable internal margins and all artwork. Do not redesign the numerals, arcs, colors, or composition. No new elements or text. Flat front-on app asset, no device or presentation mockup.

Light variant generated with the built-in image tool from the production dark icon, then resized with `sips`. Prompt:

> Use case: precise-object-edit. Asset type: production iOS app icon light appearance, opaque square, 1024 x 1024. This image is the exact edit target. Create a LIGHT MODE COLOR VARIANT of this exact icon. Change ONLY its colors: near-black background becomes a full-bleed very pale warm off-white/sage #F6F7F2, the mint-green numerals and middle-dot separators become rich deep forest green #27683C, the three muted green arc strokes become medium muted sage green #91AA92. Preserve the original precise typography reading '1·3·5', including exact glyph shapes, sizes, baseline, spacing, position and comfortable margins. Preserve the exact top arc and two lower arc geometries, rounded stroke ends, gap positions, thickness and positions. Flat front-on square bitmap filling all four edges and square corners, opaque no transparency, no border, no outer shadow or pre-rounded mask, no mockup or device. Keep restrained almost-flat surface finish. Do not redesign, move, add or remove any elements. Output only the single light version.
