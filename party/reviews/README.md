# Review photos — drop crops in here

The 15 real reviews in **Devine la note** each look for their own photo in this folder.
Save a crop as `<name>.jpg` (or `.png`) and it appears in the game automatically — no
code change needed. Until a file exists, a generic fallback image is shown instead.

Square-ish crops work best (the card renders a 116×116 rounded square, cover-fitted).

| File to save            | Review it belongs to                          | Rating |
|-------------------------|-----------------------------------------------|--------|
| `bird.jpg`              | Cockatiel perched on the adult toy            | 5★     |
| `cutter.jpg`            | Bandaged thumb next to the utility knife      | 5★     |
| `balloons.jpg`          | Balloons spelling "HAPPY BIRHTAAY"            | 1★     |
| `catbed.jpg`            | Cat standing *under* the cat tent             | 3★     |
| `leggings2.jpg`         | Person sliding down a mountain in leggings    | 5★     |
| `leggings1.jpg`         | Blush-pink leggings matching skin tone        | 4★     |
| `shoes.jpg`             | Fake trainers + the "hehe" seller reply       | 1★     |
| `drum.jpg`              | 55-gallon blue drum of lubricant              | 4★     |
| `casket.jpg`            | Titan Casket, "No complaints from Grandpa"    | 5★     |
| `hulk.jpg`              | Hulk Smash Hands foam gloves                  | 2★     |
| `mattress.jpg`          | Air mattress mistaken for an ice cream sandwich | 1★   |
| `sennheiser.jpg`        | Sennheiser HD 800 S, sold both kidneys        | 5★     |
| `teeth.jpg`             | Teeth whitening, "taking other people's land" | 5★     |
| `brush.jpg`             | Toilet brush, "too much pain"                 | 2★     |
| `wolf.jpg`              | Wolf of Wall Street, "not a nature documentary" | 1★   |

## Why these aren't already here

The screenshots were supplied in chat. Claude can view images but has no way to write
image data out to a file or crop it, so these have to be saved by hand — the fallback
chain exists so the game works fine in the meantime.

## How the fallback works

`REVIEWS_PACK` entries carry a `shot` path; `reviewPhotoLayers()` builds a layered CSS
`background-image`:

    url('reviews/bird.jpg'), url('reviews/bird.png'), url('<generic fallback>'), <gradient>

A browser skips any layer that fails to load and paints the next one, so the real crop
wins as soon as it exists.
