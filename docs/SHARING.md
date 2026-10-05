# Sharing a playable build

Spinward exports to the web. It's single-threaded, so it needs no special server headers. A friend can then play it from a link, with nothing to install.

## 1. Build

The web export templates must be installed first. They go in `%APPDATA%\Godot\export_templates\4.7.2.stable\`, as `web_nothreads_release.zip` and `web_nothreads_debug.zip`. The templates are extracted from `Godot_v4.7.2-stable_export_templates.tpz` (Godot's GitHub releases).

```powershell
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Web" build/web/index.html
```

Zip the *contents* of `build/web/` (so `index.html` is at the top level of the zip): `build/spinward-web.zip`.

To try it locally, serve the folder (`python -m http.server 8060 --directory build/web`) and open http://localhost:8060. Opening `index.html` straight from disk doesn't work, because browsers won't load WebAssembly from `file://`.

## 2. Upload to itch.io

1. Sign in at https://itch.io. Then go to **Dashboard → Create new project**.
2. Fill in the basics:
   - **Title:** Spinward
   - **Project URL:** spinward
   - **Kind of project:** **HTML**
   - **Classification:** Games
3. Under **Uploads**, upload `build/spinward-web.zip` and tick **This file will be played in the browser**.
4. Under **Embed options**:
   - Choose **Embed in page**.
   - Set the size to **1280 × 800**.
   - Tick **Mobile friendly** off.
   - Tick **Fullscreen button** on.
   - Leave **SharedArrayBuffer support** off, because the build is single-threaded.
5. Under **Visibility & access**, pick one:
   - **Draft:** only you can see it. Share the **secret URL** from the project's edit page.
   - **Restricted:** only people with the password can see it. Set a password and share it with the link.
6. **Save**, then open the page and check it plays.

To update the build, upload the new zip in place of the old one under **Uploads**. The link stays the same.

## 3. Page images

Make the images, then upload them:

```powershell
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1920x1080 -- --promo=build/promo
python tools/make_itch_images.py build/promo
```

That writes `build/itch/`:
- **`cover.png`** (630 × 500, itch's cover size; `cover@2x.png` is double size). Upload it under **Cover image**.
- **`banner.png`** (1920 × 480). Use it under **Edit theme → Banner**.
- **`01-…` to `14-…`** (1920 × 1080). Upload them under **Screenshots**, in that order. The cinematic shots come first, then play: docking, the elevator ride, the map, projects, the news and the controls.

`--promo` also leaves the raw captures in `build/promo`: every title set-up at two moments, and cockpit and chase views at six ports.

## What a player needs to know

- **Browser:** a desktop browser such as Chrome, Edge or Firefox, with a window of 1280 × 800 or larger.
- **Loading:** the first load downloads about 40 MB.
- **Controls:** click the game once so it has keyboard focus. **F1** shows every key, anywhere in the game.
- **Saves:** F5 quick-saves and F9 quick-loads, kept in that browser only.
- **Route plotting:** in the browser this pauses for a second or two (single-threaded).
