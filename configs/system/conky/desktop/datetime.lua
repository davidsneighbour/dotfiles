
-- https://conky.cc/config_settings
conky.config = {
  --[[
    Shows a watch and date on the desktop.
  ]]

  background = true, -- fork to the background, NOT colour
  color1 = 'ff79c6',
  -- window specifications
	own_window = true,
	own_window_type = 'normal',
	own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
  -- for transparency
	own_window_transparent = true,
	own_window_argb_visual = true,
	own_window_argb_value = 144,
  -- positioning
  alignment = 'top_right',
	gap_x = 30,
	gap_y = 30,
  -- helpers
	draw_shades = false,
	-- default_shade_color = 'red',
	draw_outline = false,
	-- default_outline_color = 'green',
	draw_borders = false, -- set to true to debug container
	draw_graph_borders = false,
  border_width = 1,
  -- output formatting
	font = 'Ubuntu:pixelsize=24',
	use_xft = true,
  short_units = true,
	update_interval = 10,
  use_spacer = 'left',

	xftalpha = 0.1,
	total_run_times = 0,

};

-- https://conky.cc/variables

conky.text = [[
${alignc}${color EAEAEA}${font Ubuntu:pixelsize=180}${time %I:%M}${font}
${alignc}${voffset -5}${color1}${font Ubuntu:pixelsize=58}${time %d %B %Y}${font}${color}
${alignc}${voffset -10}${font Ubuntu:pixelsize=74}${time %A}${font}
]];
