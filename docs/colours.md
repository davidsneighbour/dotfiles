# Colours

The workstation uses the **Dracula Pro Nosferatu** palette by default. The **Dracula Pro** base palette stays available as an alternative for terminal output.

The single source for terminal colours is [`bashrc/lib/00-core/dnb-core-ui-theme.bash`](../bashrc/lib/00-core/dnb-core-ui-theme.bash). It stores each colour as `HEX|R,G,B|HSL|256`. Desktop configs (Polybar, Rofi, i3) cannot read that file, so they repeat the hex values; update them together with the palette.

## Select a palette

| `DNB_UI_THEME` | Palette |
| --- | --- |
| unset, `nosferatu`, or any unknown value | Dracula Pro Nosferatu |
| `dracula-pro` | Dracula Pro base |
| `dracula-pro-dark` | Retired. Maps to Nosferatu. |

## Use colours in scripts and configs

| Where | How |
| --- | --- |
| Bash helpers, styled text | Use the `dnb_ui_*` functions from [terminal UI](terminal-ui.md). Do not write raw escapes; `npm run lint:terminal-ui` rejects them. |
| Bash, colour value for a tool argument | Use the exported tokens, for example `"${DNB_UI_ACCENT}"`. Shell startup runs `dnb_ui_export_tokens`. |
| Bash, one palette field | `__dnb_ui_palette_field Orange hex` (fields: `hex`, `rgb`, `hsl`, `256`). Internal API for facade code. |
| Bash, one role field | `__dnb_ui_role_field warning rgb` (also `basic` for the ANSI SGR number). Internal API for facade code. |
| Logging | `dnb_log` level colours use the semantic roles automatically. |
| Glow, bat, delta | Generated assets in `configs/theme/dnb-terminal/`. Run `npm run build:terminal-theme` after palette changes. |
| Polybar | `${colours.<name>}` from [`configs/session/polybar/configs/01-colours.ini`](../configs/session/polybar/configs/01-colours.ini). |
| Rofi | `@dnb-<name>` from [`configs/session/rofi/theme.rasi`](../configs/session/rofi/theme.rasi). |
| i3 root background | `xsetroot` in [`configs/session/i3/configs/session-starts.conf`](../configs/session/i3/configs/session-starts.conf). |
| Starship | Palette names (`cyan`, `purple`, …) from `[palettes.nosferatu]` in [`configs/session/starship/starship.toml`](../configs/session/starship/starship.toml). |
| i3lock | Variables in the theme block of [`configs/session/i3/lock.sh`](../configs/session/i3/lock.sh). |

Not on this palette: the Sublime Text Dracula package is a vendored upstream theme.

### Exported tokens

`dnb_ui_export_tokens` exports one hex value per semantic role for the active palette.

| Role | Token | Palette name | Nosferatu | Dracula Pro |
| --- | --- | --- | --- | --- |
| `bg` | `DNB_UI_BG` | Background | `#17191B` | `#22212C` |
| `fg` | `DNB_UI_FG` | Foreground | `#D2D0CB` | `#F8F8F2` |
| `muted` | `DNB_UI_MUTED` | Comment | `#9EA4AC` | `#7970A9` |
| `accent` | `DNB_UI_ACCENT` | Cyan | `#A6BAC0` | `#80FFEA` |
| `info` | `DNB_UI_INFO` | Cyan | `#A6BAC0` | `#80FFEA` |
| `accent_alt` | `DNB_UI_ACCENT_ALT` | Magenta | `#C28FA3` | `#FF80BF` |
| `success` | `DNB_UI_SUCCESS` | Green | `#9BAF84` | `#8AFF80` |
| `warning` | `DNB_UI_WARNING` | Orange | `#C9A273` | `#FFCA80` |
| `error` | `DNB_UI_ERROR` | Red | `#FF7D6C` | `#FF9580` |
| `dry` | `DNB_UI_DRY` | Yellow | `#F2C861` | `#FFFF80` |
| `skip` | `DNB_UI_SKIP` | Magenta | `#C28FA3` | `#FF80BF` |
| `trace` | `DNB_UI_TRACE` | DimWhite | `#A8A6A2` | `#C6C6C2` |
| `border` | `DNB_UI_BORDER` | BrightBlack | `#9EA4AC` | `#504C67` |
| `selected` | `DNB_UI_SELECTED` | Selection | `#2E3236` | `#454158` |
| `cursor` | `DNB_UI_CURSOR` | Cursor | `#9EA4AC` | `#7970A9` |

```bash
gum style --foreground "${DNB_UI_ACCENT}" 'Example'   # facade code only
printf '%s\n' "$(__dnb_ui_palette_field Background rgb)"   # 23;25;27
```

## Default palette

Dracula Pro Nosferatu.

### Named colours

Polybar and Rofi use these names. Pink and purple have no terminal slot of the same name.

| Name | Hex | RGB | HSL | 256 |
| --- | --- | --- | --- | --- |
| Foreground | `#D2D0CB` | `210, 208, 203` | `43° 7% 81%` | `252` |
| Cyan | `#8FA9B4` | `143, 169, 180` | `198° 20% 63%` | `109` |
| Green | `#D0DBC4` | `208, 219, 196` | `89° 24% 81%` | `252` |
| Orange | `#C9A273` | `201, 162, 115` | `33° 44% 62%` | `180` |
| Pink | `#EE9440` | `238, 148, 64` | `29° 84% 59%` | `209` |
| Purple | `#B3A6BC` | `179, 166, 188` | `275° 14% 69%` | `249` |
| Red | `#FF7D6C` | `255, 125, 108` | `7° 100% 71%` | `209` |
| Yellow | `#F2C861` | `242, 200, 97` | `43° 85% 66%` | `221` |
| Background | `#17191B` | `23, 25, 27` | `210° 8% 10%` | `234` |
| Comment | `#9EA4AC` | `158, 164, 172` | `214° 8% 65%` | `248` |
| Selection | `#2E3236` | `46, 50, 54` | `210° 8% 20%` | `236` |

### Terminal standard

`__DNB_UI_PALETTE_NOSFERATU` stores these rows. Note that the terminal Cyan and Green differ from the named colours above.

| Name | Hex | RGB | HSL | 256 |
| --- | --- | --- | --- | --- |
| Black | `#1F2326` | `31, 35, 38` | `206° 10% 14%` | `235` |
| Red | `#FF7D6C` | `255, 125, 108` | `7° 100% 71%` | `209` |
| Green | `#9BAF84` | `155, 175, 132` | `88° 21% 60%` | `108` |
| Yellow | `#F2C861` | `242, 200, 97` | `43° 85% 66%` | `221` |
| Blue | `#8CA3B5` | `140, 163, 181` | `206° 22% 63%` | `109` |
| Magenta | `#C28FA3` | `194, 143, 163` | `336° 29% 66%` | `139` |
| Cyan | `#A6BAC0` | `166, 186, 192` | `194° 17% 70%` | `249` |
| White | `#D2D0CB` | `210, 208, 203` | `43° 7% 81%` | `252` |
| BrightBlack | `#9EA4AC` | `158, 164, 172` | `214° 8% 65%` | `248` |
| BrightRed | `#FF9582` | `255, 149, 130` | `9° 100% 75%` | `210` |
| BrightGreen | `#B3C49C` | `179, 196, 156` | `86° 25% 69%` | `151` |
| BrightYellow | `#F7D98A` | `247, 217, 138` | `43° 87% 75%` | `222` |
| BrightBlue | `#A6BACB` | `166, 186, 203` | `208° 26% 72%` | `146` |
| BrightMagenta | `#D4A6B6` | `212, 166, 182` | `339° 35% 74%` | `181` |
| BrightCyan | `#BFD0D4` | `191, 208, 212` | `191° 20% 79%` | `252` |
| BrightWhite | `#F7F4ED` | `247, 244, 237` | `42° 38% 95%` | `255` |
| DimBlack | `#191C1E` | `25, 28, 30` | `204° 9% 11%` | `234` |
| DimRed | `#CC6456` | `204, 100, 86` | `7° 54% 57%` | `167` |
| DimGreen | `#7C8C6A` | `124, 140, 106` | `88° 14% 48%` | `101` |
| DimYellow | `#C2A04E` | `194, 160, 78` | `42° 49% 53%` | `143` |
| DimBlue | `#708291` | `112, 130, 145` | `207° 13% 50%` | `66` |
| DimMagenta | `#9B7282` | `155, 114, 130` | `337° 17% 53%` | `96` |
| DimCyan | `#85959A` | `133, 149, 154` | `194° 9% 56%` | `246` |
| DimWhite | `#A8A6A2` | `168, 166, 162` | `40° 3% 65%` | `248` |
| Background | `#17191B` | `23, 25, 27` | `210° 8% 10%` | `234` |
| Foreground | `#D2D0CB` | `210, 208, 203` | `43° 7% 81%` | `252` |
| Comment | `#9EA4AC` | `158, 164, 172` | `214° 8% 65%` | `248` |
| Selection | `#2E3236` | `46, 50, 54` | `210° 8% 20%` | `236` |
| Cursor | `#9EA4AC` | `158, 164, 172` | `214° 8% 65%` | `248` |
| Orange | `#C9A273` | `201, 162, 115` | `33° 44% 62%` | `179` |

## Alternative palette

Dracula Pro base.

### Named colours

| Name | Hex | RGB | HSL | 256 |
| --- | --- | --- | --- | --- |
| Foreground | `#F8F8F2` | `248, 248, 242` | `60° 30% 96%` | `231` |
| Cyan | `#80FFEA` | `128, 255, 234` | `170° 100% 75%` | `159` |
| Green | `#8AFF80` | `138, 255, 128` | `115° 100% 75%` | `157` |
| Orange | `#FFCA80` | `255, 202, 128` | `35° 100% 75%` | `223` |
| Pink | `#FF80BF` | `255, 128, 191` | `330° 100% 75%` | `218` |
| Purple | `#9580FF` | `149, 128, 255` | `250° 100% 75%` | `147` |
| Red | `#FF9580` | `255, 149, 128` | `10° 100% 75%` | `217` |
| Yellow | `#FFFF80` | `255, 255, 128` | `60° 100% 75%` | `229` |
| Background | `#22212C` | `34, 33, 44` | `250° 15% 15%` | `59` |
| Comment | `#7970A9` | `121, 112, 169` | `250° 25% 55%` | `103` |
| Selection | `#454158` | `69, 65, 88` | `250° 15% 30%` | `60` |

### Terminal standard

`__DNB_UI_PALETTE_MAIN` stores these rows.

| Name | Hex | RGB | HSL | 256 |
| --- | --- | --- | --- | --- |
| Black | `#22212C` | `34, 33, 44` | `250° 15% 15%` | `59` |
| Red | `#FF9580` | `255, 149, 128` | `10° 100% 75%` | `217` |
| Green | `#8AFF80` | `138, 255, 128` | `115° 100% 75%` | `157` |
| Yellow | `#FFFF80` | `255, 255, 128` | `60° 100% 75%` | `229` |
| Blue | `#9580FF` | `149, 128, 255` | `250° 100% 75%` | `147` |
| Magenta | `#FF80BF` | `255, 128, 191` | `330° 100% 75%` | `218` |
| Cyan | `#80FFEA` | `128, 255, 234` | `170° 100% 75%` | `159` |
| White | `#F8F8F2` | `248, 248, 242` | `60° 30% 96%` | `231` |
| BrightBlack | `#504C67` | `80, 76, 103` | `249° 15% 35%` | `60` |
| BrightRed | `#FFAA99` | `255, 170, 153` | `10° 100% 80%` | `216` |
| BrightGreen | `#A2FF99` | `162, 255, 153` | `115° 100% 80%` | `156` |
| BrightYellow | `#FFFF99` | `255, 255, 153` | `60° 100% 80%` | `228` |
| BrightBlue | `#AA99FF` | `170, 153, 255` | `250° 100% 80%` | `141` |
| BrightMagenta | `#FF99CC` | `255, 153, 204` | `330° 100% 80%` | `212` |
| BrightCyan | `#99FFEE` | `153, 255, 238` | `170° 100% 80%` | `123` |
| BrightWhite | `#FFFFFF` | `255, 255, 255` | `0° 0% 100%` | `231` |
| DimBlack | `#1B1A23` | `27, 26, 35` | `247° 15% 12%` | `234` |
| DimRed | `#CC7766` | `204, 119, 102` | `10° 50% 60%` | `173` |
| DimGreen | `#6ECC66` | `110, 204, 102` | `115° 50% 60%` | `77` |
| DimYellow | `#CCCC66` | `204, 204, 102` | `60° 50% 60%` | `185` |
| DimBlue | `#7766CC` | `119, 102, 204` | `250° 50% 60%` | `98` |
| DimMagenta | `#CC6699` | `204, 102, 153` | `330° 50% 60%` | `168` |
| DimCyan | `#66CCBB` | `102, 204, 187` | `170° 50% 60%` | `79` |
| DimWhite | `#C6C6C2` | `198, 198, 194` | `60° 3% 77%` | `251` |
| Background | `#22212C` | `34, 33, 44` | `250° 15% 15%` | `59` |
| Foreground | `#F8F8F2` | `248, 248, 242` | `60° 30% 96%` | `231` |
| Comment | `#7970A9` | `121, 112, 169` | `250° 25% 55%` | `103` |
| Selection | `#454158` | `69, 65, 88` | `250° 15% 30%` | `60` |
| Cursor | `#7970A9` | `121, 112, 169` | `250° 25% 55%` | `103` |
| Orange | `#FFCA80` | `255, 202, 128` | `35° 100% 75%` | `222` |

The 256-colour indices are approximations. The supplied tables give Orange two different indices (named `223`/`180`, terminal `222`/`179`); the terminal code uses the terminal-standard values.
