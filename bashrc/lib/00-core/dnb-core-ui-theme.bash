# shellcheck shell=bash

# Canonical terminal theme for the DNB UI facade.
#
# This file only defines data and pure lookup functions. It does not print,
# prompt, start tools, or change shell options on source.
#
# Palette rows use the format 'HEX|R,G,B|HSL|256' and preserve the supplied
# Dracula Pro values verbatim. `scripts/build-terminal-theme.ts` parses the
# `[Name]='…'` rows below; keep one row per line.
#
# Selectors:
#   DNB_UI_THEME=dracula-pro|dracula-pro-dark   (default: dracula-pro)
#   DNB_UI_SYMBOLS=auto|unicode|ascii           (default: auto)

# Main palette (default).
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

# Darker variant: overrides only these rows. Black stays unchanged.
declare -gA __DNB_UI_PALETTE_DARK=(
  [Background]='#0B0D0F|11,13,15|210° 15% 5%|16'
  [Comment]='#708CA9|112,140,169|210° 25% 55%|109'
  [Selection]='#414D58|65,77,88|210° 15% 30%|66'
  [Cursor]='#708CA9|112,140,169|210° 25% 55%|109'
  [BrightBlack]='#364049|54,64,73|208° 15% 25%|66'
  [DimBlack]='#090A0C|9,10,12|220° 15% 4%|232'
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
# Print the active theme name. Unknown values fall back to dracula-pro.
__dnb_ui_theme_name() {
  case "${DNB_UI_THEME:-dracula-pro}" in
  dracula-pro-dark) printf 'dracula-pro-dark\n' ;;
  *) printf 'dracula-pro\n' ;;
  esac
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

  if [[ "$(__dnb_ui_theme_name)" == 'dracula-pro-dark' && -n "${__DNB_UI_PALETTE_DARK[${name}]:-}" ]]; then
    row="${__DNB_UI_PALETTE_DARK[${name}]}"
  else
    row="${__DNB_UI_PALETTE_MAIN[${name}]:-}"
  fi
  [[ -n "${row}" ]] || return 1

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

  for role in "${!__DNB_UI_ROLES[@]}"; do
    name="${__DNB_UI_ROLES[${role}]}"
    row="${__DNB_UI_PALETTE_MAIN[${name}]}"
    if [[ "${DNB_UI_THEME:-}" == 'dracula-pro-dark' && -n "${__DNB_UI_PALETTE_DARK[${name}]:-}" ]]; then
      row="${__DNB_UI_PALETTE_DARK[${name}]}"
    fi
    var="DNB_UI_${role^^}"
    printf -v "${var}" '%s' "${row%%|*}"
    export "${var?}"
  done
}
