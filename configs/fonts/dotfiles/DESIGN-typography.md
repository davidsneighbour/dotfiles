# Dotfiles typography

<!-- markdownlint-disable title-case-style -->

The settled typography system is:

* UI and content: Recursive Sans Linear.
* Code and data: Monaspace Argon.
* Rofi list items: Monaspace Argon for stable mixed labels.

The source tree is `configs/fonts/dotfiles`. Dotbot installs it to `/home/patrick/.fonts/dotfiles`.

## Retained files

### Recursive

Installed file:

* `/home/patrick/.fonts/dotfiles/recursive/Recursive_VF_1.085.ttf`

Repository source:

* `configs/fonts/dotfiles/recursive/Recursive_VF_1.085.ttf`

Rationale: the variable Recursive font exposes the Sans Linear styles needed for UI and content while keeping the repo small. The static TTC/OTC files and the `separate_statics` tree are removed because they duplicate this setup and add significant size.

### Monaspace Argon

Installed files:

* `/home/patrick/.fonts/dotfiles/monaspace/static/MonaspaceArgon-Regular.otf`
* `/home/patrick/.fonts/dotfiles/monaspace/static/MonaspaceArgon-Italic.otf`
* `/home/patrick/.fonts/dotfiles/monaspace/static/MonaspaceArgon-Bold.otf`
* `/home/patrick/.fonts/dotfiles/monaspace/static/MonaspaceArgon-BoldItalic.otf`
* `/home/patrick/.fonts/dotfiles/monaspace/frozen/MonaspaceArgonFrozen-Regular.ttf`
* `/home/patrick/.fonts/dotfiles/monaspace/frozen/MonaspaceArgonFrozen-Italic.ttf`
* `/home/patrick/.fonts/dotfiles/monaspace/frozen/MonaspaceArgonFrozen-Bold.ttf`
* `/home/patrick/.fonts/dotfiles/monaspace/frozen/MonaspaceArgonFrozen-BoldItalic.ttf`
* `/home/patrick/.fonts/dotfiles/monaspace/nerdfonts/MonaspiceArNerdFont-Regular.otf`
* `/home/patrick/.fonts/dotfiles/monaspace/nerdfonts/MonaspiceArNerdFontMono-Regular.otf`

Repository source:

* `configs/fonts/dotfiles/monaspace/static/`
* `configs/fonts/dotfiles/monaspace/frozen/`
* `configs/fonts/dotfiles/monaspace/nerdfonts/`

Rationale: the normal Argon OTF files are for ligature-capable apps. The Frozen TTF files are for apps that cannot control OpenType features reliably. Only regular, italic, bold, and bold italic are retained for each. Wider widths, extra weights, and the variable build are removed for now.

The Nerd Font files are retained as desktop OTF files from Nerd Fonts `v3.4.0`. The earlier `MonaspaceArgonNF-*.woff` and `MonaspaceArgonNF-*.woff2` files were webfont payloads and are removed from the desktop font set.

## Icon font order

Keep icon fonts ordered from most intentional to most specialised fallback: Lucide first for UI/action icons, Symbols Nerd Font Mono next for Nerd Font private-use glyphs and workspace/module symbols, and Font Awesome Brands last for brand-only glyphs.

## Font family names

Some applications, including VS Code, require font family names as strings instead of offering a font picker.

Use these names for the selected font set:

* UI/content font: `Recursive`
* Recursive Sans Linear style: `Recursive:style=Sans Linear`
* Recursive Sans Linear Light style: `Recursive:style=Sans Linear Light`
* Code font: `Monaspace Argon`
* Code fallback: `Monaspace Argon Frozen`
* Argon Nerd Font: `MonaspiceAr Nerd Font`
* Argon Nerd Font Mono: `MonaspiceAr Nerd Font Mono`
* Argon Nerd Font short aliases: `MonaspiceAr NF`, `MonaspiceAr NFM`

Use this to inspect family names from files:

```bash
fc-scan --format '%{family}\n' /home/patrick/.fonts/dotfiles/recursive/Recursive_VF_1.085.ttf /home/patrick/.fonts/dotfiles/monaspace/static/MonaspaceArgon-Regular.otf /home/patrick/.fonts/dotfiles/monaspace/frozen/MonaspaceArgonFrozen-Regular.ttf /home/patrick/.fonts/dotfiles/monaspace/nerdfonts/MonaspiceArNerdFont-Regular.otf /home/patrick/.fonts/dotfiles/monaspace/nerdfonts/MonaspiceArNerdFontMono-Regular.otf | sort -u
```

Use this to test the names after the font cache is current:

```bash
fc-cache -frv /home/patrick/.fonts/dotfiles
fc-match 'Recursive:style=Sans Linear'
fc-match 'Monaspace Argon'
fc-match 'Monaspace Argon Frozen'
fc-match 'MonaspiceAr Nerd Font'
fc-match 'MonaspiceAr Nerd Font Mono'
```

For VS Code code editing, start with:

```json
{
  "editor.fontFamily": "'Monaspace Argon', 'Symbols Nerd Font Mono', monospace",
  "editor.fontLigatures": true
}
```

Use `Monaspace Argon Frozen` in VS Code only if ligature or OpenType control does not behave correctly.

## Licenses

Each family root contains its upstream license:

* `configs/fonts/dotfiles/recursive/LICENSE.txt`
* `configs/fonts/dotfiles/monaspace/LICENSE.txt`

## Agent instructions

### UI and content typography

```text
Use Recursive Sans Linear for dotfiles UI and content work.

Installed font file: /home/patrick/.fonts/dotfiles/recursive/Recursive_VF_1.085.ttf
Repository source: /home/patrick/github.com/davidsneighbour/dotfiles/configs/fonts/dotfiles/recursive/Recursive_VF_1.085.ttf

Use fontconfig as Recursive:style=Sans Linear or Recursive:style=Sans Linear Light. Do not add Recursive static collections, separate static folders, webfonts, or version-number directories unless a real app cannot use the retained variable font.
```

### Code and data typography

```text
Use Monaspace Argon for dotfiles code and data work.

Installed normal Argon source: /home/patrick/.fonts/dotfiles/monaspace/static/
Installed frozen fallback source: /home/patrick/.fonts/dotfiles/monaspace/frozen/
Installed Argon Nerd Font source: /home/patrick/.fonts/dotfiles/monaspace/nerdfonts/
Repository source: /home/patrick/github.com/davidsneighbour/dotfiles/configs/fonts/dotfiles/monaspace/

Use Monaspace Argon in ligature-capable apps. Use Monaspace Argon Frozen only where OpenType controls are missing or unreliable. Use MonaspiceAr Nerd Font or MonaspiceAr Nerd Font Mono only when an Argon-shaped Nerd Font is specifically needed; use the existing Symbols Nerd Font fallback for ordinary desktop icons.
```
