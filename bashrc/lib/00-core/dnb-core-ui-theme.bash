# shellcheck shell=bash

# Canonical terminal theme for the DNB UI facade.
#
# This file only defines data and pure lookup functions. It does not print,
# prompt, start tools, or change shell options on source.
#
# Palette rows use the format 'HEX|R,G,B|HSL|256' and preserve the supplied
# Dracula Pro "Terminal Standard" values verbatim.
# `scripts/build-terminal-theme.ts` parses the `[Name]='…'` rows below; keep
# one row per line. See docs/colours.md for the full overview.
#
# Selectors:
#   DNB_UI_THEME=nosferatu|dracula-pro         (default: nosferatu)
#                The retired `dracula-pro-dark` maps to nosferatu.
#   DNB_UI_SYMBOLS=auto|unicode|ascii           (default: auto)

# Dracula Pro base palette.
declare -gA __DNB_UI_PALETTE_MAIN=(
  [Black]='#22212C|34,33,44|250° 15% 15%|59'
  [Red]='#FF9580|255,149,128|10° 100% 75%|217'
  [Green]='#8AFF80|138,255,128|115° 100% 75%|157'
  [Yellow]='#FFFF80|255,255,128|60° 100% 75%|229'
  [Blue]='#9580FF|149,128,255|250° 100% 75%|147'
  [Magenta]='#FF80BF|255,128,191|330° 100% 75%|218'
  [Cyan]='#80FFEA|128,255,234|170° 100% 75%|159'
  [White]='#F8F8F2|248,248,242|60° 30% 96%|231'
  [BrightBlack]='#504C67|80,76,103|249° 15% 35%|60'
  [BrightRed]='#FFAA99|255,170,153|10° 100% 80%|216'
  [BrightGreen]='#A2FF99|162,255,153|115° 100% 80%|156'
  [BrightYellow]='#FFFF99|255,255,153|60° 100% 80%|228'
  [BrightBlue]='#AA99FF|170,153,255|250° 100% 80%|141'
  [BrightMagenta]='#FF99CC|255,153,204|330° 100% 80%|212'
  [BrightCyan]='#99FFEE|153,255,238|170° 100% 80%|123'
  [BrightWhite]='#FFFFFF|255,255,255|0° 0% 100%|231'
  [DimBlack]='#1B1A23|27,26,35|247° 15% 12%|234'
  [DimRed]='#CC7766|204,119,102|10° 50% 60%|173'
  [DimGreen]='#6ECC66|110,204,102|115° 50% 60%|77'
  [DimYellow]='#CCCC66|204,204,102|60° 50% 60%|185'
  [DimBlue]='#7766CC|119,102,204|250° 50% 60%|98'
  [DimMagenta]='#CC6699|204,102,153|330° 50% 60%|168'
  [DimCyan]='#66CCBB|102,204,187|170° 50% 60%|79'
  [DimWhite]='#C6C6C2|198,198,194|60° 3% 77%|251'
  [Background]='#22212C|34,33,44|250° 15% 15%|59'
  [Foreground]='#F8F8F2|248,248,242|60° 30% 96%|231'
  [Comment]='#7970A9|121,112,169|250° 25% 55%|103'
  [Selection]='#454158|69,65,88|250° 15% 30%|60'
  [Cursor]='#7970A9|121,112,169|250° 25% 55%|103'
  [Orange]='#FFCA80|255,202,128|35° 100% 75%|222'
)

# Nosferatu variant (default). A complete palette, not overrides.
declare -gA __DNB_UI_PALETTE_NOSFERATU=(
  [Black]='#1F2326|31,35,38|206° 10% 14%|235'
  [Red]='#FF7D6C|255,125,108|7° 100% 71%|209'
  [Green]='#9BAF84|155,175,132|88° 21% 60%|108'
  [Yellow]='#F2C861|242,200,97|43° 85% 66%|221'
  [Blue]='#8CA3B5|140,163,181|206° 22% 63%|109'
  [Magenta]='#C28FA3|194,143,163|336° 29% 66%|139'
  [Cyan]='#A6BAC0|166,186,192|194° 17% 70%|249'
  [White]='#D2D0CB|210,208,203|43° 7% 81%|252'
  [BrightBlack]='#9EA4AC|158,164,172|214° 8% 65%|248'
  [BrightRed]='#FF9582|255,149,130|9° 100% 75%|210'
  [BrightGreen]='#B3C49C|179,196,156|86° 25% 69%|151'
  [BrightYellow]='#F7D98A|247,217,138|43° 87% 75%|222'
  [BrightBlue]='#A6BACB|166,186,203|208° 26% 72%|146'
  [BrightMagenta]='#D4A6B6|212,166,182|339° 35% 74%|181'
  [BrightCyan]='#BFD0D4|191,208,212|191° 20% 79%|252'
  [BrightWhite]='#F7F4ED|247,244,237|42° 38% 95%|255'
  [DimBlack]='#191C1E|25,28,30|204° 9% 11%|234'
  [DimRed]='#CC6456|204,100,86|7° 54% 57%|167'
  [DimGreen]='#7C8C6A|124,140,106|88° 14% 48%|101'
  [DimYellow]='#C2A04E|194,160,78|42° 49% 53%|143'
  [DimBlue]='#708291|112,130,145|207° 13% 50%|66'
  [DimMagenta]='#9B7282|155,114,130|337° 17% 53%|96'
  [DimCyan]='#85959A|133,149,154|194° 9% 56%|246'
  [DimWhite]='#A8A6A2|168,166,162|40° 3% 65%|248'
  [Background]='#17191B|23,25,27|210° 8% 10%|234'
  [Foreground]='#D2D0CB|210,208,203|43° 7% 81%|252'
  [Comment]='#9EA4AC|158,164,172|214° 8% 65%|248'
  [Selection]='#2E3236|46,50,54|210° 8% 20%|236'
  [Cursor]='#9EA4AC|158,164,172|214° 8% 65%|248'
  [Orange]='#C9A273|201,162,115|33° 44% 62%|179'
)

# Semantic role -> palette name.
declare -gA __DNB_UI_ROLES=(
  [bg]='Background'
  [fg]='Foreground'
  [muted]='Comment'
  [accent]='Cyan'
  [info]='Cyan'
  [accent_alt]='Magenta'
  [success]='Green'
  [warning]='Orange'
  [error]='Red'
  [dry]='Yellow'
  [skip]='Magenta'
  [trace]='DimWhite'
  [border]='BrightBlack'
  [selected]='Selection'
  [cursor]='Cursor'
)

# Semantic role -> basic ANSI foreground SGR number.
declare -gA __DNB_UI_ROLES_BASIC=(
  [bg]='39'
  [fg]='39'
  [muted]='90'
  [accent]='36'
  [info]='36'
  [accent_alt]='35'
  [success]='32'
  [warning]='33'
  [error]='31'
  [dry]='33'
  [skip]='35'
  [trace]='37'
  [border]='90'
  [selected]='7'
  [cursor]='36'
)

# Semantic symbol -> 'UNICODE|ASCII'.
declare -gA __DNB_UI_SYMBOLS=(
  [success]='✓|OK'
  [error]='✗|ERROR'
  [warning]='!|!'
  [action]='→|->'
  [item]='•|*'
  [prompt]='?|?'
  [rule]='─|-'
  [created]='+|+'
  [changed]='~|~'
  [removed]='-|-'
)

# __dnb_ui_theme_name
#
# Print the active theme name. Unknown values fall back to nosferatu.
__dnb_ui_theme_name() {
  case "${DNB_UI_THEME:-nosferatu}" in
  dracula-pro) printf 'dracula-pro\n' ;;
  *) printf 'nosferatu\n' ;;
  esac
}

# __dnb_ui_palette_row NAME [THEME]
#
# Print the raw palette row for NAME in THEME (default: the active theme).
__dnb_ui_palette_row() {
  local name="${1:?palette name required}"
  local theme="${2:-}"
  local row=''

  [[ -n "${theme}" ]] || theme="$(__dnb_ui_theme_name)"
  if [[ "${theme}" == 'dracula-pro' ]]; then
    row="${__DNB_UI_PALETTE_MAIN[${name}]:-}"
  else
    row="${__DNB_UI_PALETTE_NOSFERATU[${name}]:-}"
  fi
  [[ -n "${row}" ]] || return 1
  printf '%s\n' "${row}"
}

# __dnb_ui_palette_field NAME FIELD
#
# Print one field of a palette row for the active theme.
# FIELD: hex, rgb, hsl, 256. The rgb field uses ';' separators for SGR.
__dnb_ui_palette_field() {
  local name="${1:?palette name required}"
  local field="${2:?field required}"
  local row=''
  local hex='' rgb='' hsl='' idx=''

  row="$(__dnb_ui_palette_row "${name}")" || return 1

  IFS='|' read -r hex rgb hsl idx <<<"${row}"
  case "${field}" in
  hex) printf '%s\n' "${hex}" ;;
  rgb) printf '%s\n' "${rgb//,/;}" ;;
  hsl) printf '%s\n' "${hsl}" ;;
  256) printf '%s\n' "${idx}" ;;
  *) return 1 ;;
  esac
}

# __dnb_ui_role_field ROLE FIELD
#
# Resolve a semantic role and print one palette field. FIELD may also be
# `basic` for the standard ANSI SGR number.
__dnb_ui_role_field() {
  local role="${1:?role required}"
  local field="${2:?field required}"
  local name="${__DNB_UI_ROLES[${role}]:-}"

  [[ -n "${name}" ]] || return 1
  if [[ "${field}" == 'basic' ]]; then
    printf '%s\n' "${__DNB_UI_ROLES_BASIC[${role}]}"
    return 0
  fi
  __dnb_ui_palette_field "${name}" "${field}"
}

# dnb_ui_export_tokens
#
# Export the semantic tokens of the active theme as hex values:
# DNB_UI_BG, DNB_UI_FG, DNB_UI_MUTED, DNB_UI_ACCENT, DNB_UI_INFO,
# DNB_UI_ACCENT_ALT, DNB_UI_SUCCESS, DNB_UI_WARNING, DNB_UI_ERROR, DNB_UI_DRY,
# DNB_UI_SKIP, DNB_UI_TRACE, DNB_UI_BORDER, DNB_UI_SELECTED, DNB_UI_CURSOR.
#
# These replace the removed COLOR_* and RED/GREEN/... escape variables. They
# are colour values for tools that take a colour argument, not escapes; print
# styled text through the dnb_ui_* functions instead. Pure Bash: no
# subprocesses, so shell startup may call it.
dnb_ui_export_tokens() {
  local role='' name='' row='' var=''
  local array='__DNB_UI_PALETTE_NOSFERATU'

  [[ "${DNB_UI_THEME:-}" == 'dracula-pro' ]] && array='__DNB_UI_PALETTE_MAIN'
  local -n palette="${array}"
  for role in "${!__DNB_UI_ROLES[@]}"; do
    name="${__DNB_UI_ROLES[${role}]}"
    row="${palette[${name}]}"
    var="DNB_UI_${role^^}"
    printf -v "${var}" '%s' "${row%%|*}"
    export "${var?}"
  done
}
