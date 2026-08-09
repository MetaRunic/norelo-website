# Profile pictures

Drop a photo per person in here and it appears automatically — as their suspect
avatar in **Qui a posté ça**, on the reveal card, and next to their comments.

## Naming

Use the person's **first name, lowercase**, matching `posterName` in `POSTS_PACK`:

| File | Person |
|---|---|
| `catherine.jpg` | Catherine Landry |
| `daniel.jpg` | Daniel |
| `danny.jpg` | Danny |
| `jasmine.jpg` | Jasmine |
| `jayson.jpg` | Jayson |
| `kevin.jpg` | Kevin Kenney |
| `marie.jpg` | Marie-alexia Tellier |
| `mikael.jpg` | Mikaël Trudeau-Buteau |
| `radu.jpg` | Radu Oprița |
| `simon.jpg` | Simon Pageau |
| `sydney.jpg` | Sydney |
| `zachary.jpg` | Zachary |

`.jpg`, `.jpeg`, `.png` and `.webp` all work — the loader tries each in turn.

**Case matters on the live site.** Vercel serves from Linux, so `Kevin.jpg` is a
different file from `kevin.jpg`. Keep them lowercase.

Square crops look best — they render as circles at 26–84px. Anything roughly
square is fine; the image is cover-fitted, so a tall photo gets cropped top and
bottom.

## Anyone missing

Falls back to the coloured initials avatar, exactly as now. You can add them one
at a time; nothing breaks while the folder is half full.

## Adding a new person later

No list to update here — the names come from `POSTS_PACK`. Add their posts with
`posterName: "Xavier"`, drop in `xavier.jpg`, done.
