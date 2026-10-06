# batch-remove-user-accounts-windows

Batch script for Windows 10/11 that asks **which user(s) to delete** and removes the account + profile data (`C:\Users\<name>`).

🌐 **Live page (download + view code):** enable GitHub Pages (Settings → Pages → Deploy from branch → `main` → `/ (root)`), then visit:
`https://edevsuraj.github.io/batch-remove-user-accounts-windows/`

## Files

| File | Purpose |
|---|---|
| `Remove-User.bat` | Main script — run as Administrator |
| `index.html` | GitHub Pages site — download button + live code viewer |

## How to use

1. Download `Remove-User.bat` from the [Pages site](https://edevsuraj.github.io/batch-remove-user-accounts-windows/) or this repo.
2. **Right-click → Run as administrator.**
3. Script lists local accounts + `C:\Users` folders.
4. A popup list opens — select user(s) (`Ctrl+Click` = multiple) → `OK`. If the popup is cancelled or can't open, type names manually, e.g. `test1 test2`.
5. Confirm with `Y` → account (`net user /delete`) + profile folder + orphan profile entry deleted.
6. Self account (`%USERNAME%`) auto-skip hota hai — wahi ek admin bachega. **Guest / Default / Public / dusre Admin accounts — sab delete honge** agar naam likha.

> ⚠️ `Default` naye users ka template hai, `Public` shared folder hai. Ye delete karne se naye user banane / sharing me problem aa sakti hai. Sirf jaan-bujhkar delete karo.

## Safety

- ⚠️ Deleted data **cannot be recovered**.
- Close the target user's files/apps first; locked folders may need a reboot + re-run.
- If a name doesn't exist, the script skips it ("account nahi mila").

## Host on GitHub Pages (already done in this repo)

1. Push `Remove-User.bat` + `index.html` to `main` (root folder).
2. Repo → **Settings → Pages → Build and deployment → Deploy from a branch → `main` / `(root)` → Save.**
3. Open `https://edevsuraj.github.io/batch-remove-user-accounts-windows/`.

The page fetches `./Remove-User.bat` at runtime, so download + displayed code always stay in sync — no copy-paste needed after edits.
