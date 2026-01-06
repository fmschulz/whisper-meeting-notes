# YTerMusic (YouTube Music TUI)

## Install (Arch)

If you run `./setup.sh`, `ytermusic` is installed automatically (it’s in `packages/aur-packages.txt`).

Manual install:
```bash
yay -S --needed ytermusic
```

## First-time setup (auth)

YTerMusic needs your YouTube Music cookies/headers.

1. Open `https://music.youtube.com` in your browser and log in
2. Open DevTools → Network
3. Click the `music.youtube.com` document request (the `/` page)
4. Copy the `Cookie` request header value
5. Create `headers.txt` in YTerMusic’s config directory:
   - Find the exact path with: `ytermusic --files`
   - Usually: `~/.config/ytermusic/headers.txt`
6. Put this in `headers.txt`:
   ```
   Cookie: <cookie>
   User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36
   ```

Then run:
```bash
ytermusic
```

## Troubleshooting

- Show paths/logs: `ytermusic --files`
- Fix DB/cache issues: `ytermusic --fix-db`
- Clear cache: `ytermusic --clear-cache`
