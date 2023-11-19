import themer from "themer";
import fs from 'fs-extra';

//import colors from "./themer-colors";
//import template from "./themer-template";

// Example usage: generate Vim themes, 1440x900 wallpapers, and custom files
// from themer's "Night Sky" color set and a custom color set.
const files = themer(
    [
        "night-sky", //colors
    ],
    [
        "alacritty",
        "alfred",
        "bbedit",
        "brave",
        "chrome",
        "cmd",
        "conemu",
        "css",
        "emacs",
        "firefox-addon",
        "firefox-color",
        "hyper",
        "iterm",
        "kde-plasma-colors",
        "keypirinha",
        "kitty",
        "konsole",
        "prism",
        "sketch-palettes",
        "slack",
        "sublime-text",
        "terminal",
        "terminator",
        "vim-lightline",
        "vim",
        "visual-studio",
        "vs-code",
        "wallpaper-block-wave",
        "wallpaper-burst",
        "wallpaper-circuits",
        "wallpaper-diamonds",
        "wallpaper-dot-grid",
        "wallpaper-octagon",
        "wallpaper-shirts",
        "wallpaper-triangles",
        "wallpaper-trianglify",
        "warp",
        "windows-terminal",
        "wox",
        "xcode",
        "xresources",
        //template
    ],
    {
        wallpaperSizes: [
            { w: 1440, h: 900 },
            { w: 1920, h: 1080 },
            { w: 2560, h: 1440 },
            { w: 3840, h: 2160 },
            { w: 1366, h: 768 },
            { w: 2560, h: 1600 },
            { w: 3840, h: 2160 },
            { w: 2048, h: 2732 },
        ]
    }
);

for await (const file of files) {
    const path = './themer/' + file.path;
    const data = file.content;
    fs.ensureFileSync(path);
    fs.writeFile(path, data, function (err) {
        if (err) throw err;
        console.log("Saved " + file.path);
    });
}