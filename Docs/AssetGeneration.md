# NearNote asset generation

The current asset set was generated with the built-in image generation tool using the two supplied UI references as visual direction. The runtime does not expose a selectable Nano Banana Pro model, so no claim is made that that named external model was used.

## Shared direction

- Premium cinematic miniature product render.
- Mature, tactile, photoreal warm-gray river stone with two small black eyes and a restrained smile.
- Near-black navy surroundings, controlled upper-left studio light, electric blue only as the product accent.
- No text, logos, phone frames, childish proportions, plastic surfaces, or excess scenery.

## Generated assets

- `pebble_idle`: isolated Pebble mascot on a flat magenta key background.
- `pebble_searching`: same character with a graphite magnifying glass and blue glass highlight.
- `pebble_empty`: same character on a compact moss patch with restrained teal leaves.
- `pebble_completed`: same character with sparse blue, green, orange, and violet confetti.
- `onboarding_welcome`: Pebble in a quiet miniature landscape under an electric-blue location pin.
- `onboarding_location`: Pebble between location cards and a miniature pharmacy storefront.
- `onboarding_time`: Pebble protected by a precision graphite shield with blue rim light and a lock mark.

The four mascot states were generated against a flat magenta chroma background, converted locally to RGBA with soft-matte edge cleanup, and validated for transparent corners and non-empty subject bounds. The three onboarding scenes remain RGB images and blend to the app’s navy canvas at their outer edges.
