import type { ColorSet } from "themer";

// Color Key	Typical Usage	Conventional Color*
// accent0	error, VCS deletion	Red
// accent1	syntax	Orange
// accent2	warning, VCS modification	Yellow
// accent3	success, VCS addition	Green
// accent4	syntax	Cyan
// accent5	syntax	Blue
// accent6	syntax, caret/cursor
// accent7	syntax, special	Magenta
// shade0	background color
// shade1	UI
// shade2	UI, text selection
// shade3	UI, code comments
// shade4	UI
// shade5	UI
// shade6	foreground text
// shade7	foreground text

const myColorSet: ColorSet = {
    // Color sets should provide a human-readable name.
    name: "My Color Set",

    // Color sets can define a dark variant, a light variant, or both.
    // Each variant provides two or eight shades and eight accent colors in hex format.
    variants: {
        // In a dark variant, shade0 should be the darkest and shade7 should be
        // the lightest.
        dark: {
            shade0: "#333333",
            // Note: you can define shades 1 through 6 yourself, or you can omit
            // them; if omitted, they will be calculated automatically by
            // interpolating between shade0 and shade7.
            shade7: "#eeeeee",
            accent0: "#ff4050",
            accent1: "#f28144",
            accent2: "#ffd24a",
            accent3: "#a4cc35",
            accent4: "#26c99e",
            accent5: "#66bfff",
            accent6: "#cc78fa",
            accent7: "#f553bf",
        },

        // In a light variant, shade7 should be the darkest and shade0 should be
        // the lightest.
        light: {
            shade0: "#eeeeee",
            shade7: "#333333",
            accent0: "#f03e4d",
            accent1: "#f37735",
            accent2: "#eeba21",
            accent3: "#97bd2d",
            accent4: "#1fc598",
            accent5: "#53a6e1",
            accent6: "#bf65f0",
            accent7: "#ee4eb8",
        },
    },
};

export default myColorSet;


// import type { ColorSet } from './index.js';

// const colors: ColorSet = {
//   name: 'Solarized',
//   variants: {
//     dark: {
//       accent0: '#DC322F',
//       accent1: '#CB4B16',
//       accent2: '#B58900',
//       accent3: '#859900',
//       accent4: '#2AA198',
//       accent5: '#268BD2',
//       accent6: '#6C71C4',
//       accent7: '#D33682',
//       shade0: '#002B36',
//       shade1: '#073642',
//       shade2: '#586E75',
//       shade3: '#657B83',
//       shade4: '#839496',
//       shade5: '#93A1A1',
//       shade6: '#EEE8D5',
//       shade7: '#FDF6E3',
//     },
//     light: {
//       accent0: '#DC322F',
//       accent1: '#CB4B16',
//       accent2: '#B58900',
//       accent3: '#859900',
//       accent4: '#2AA198',
//       accent5: '#268BD2',
//       accent6: '#6C71C4',
//       accent7: '#D33682',
//       shade0: '#FDF6E3',
//       shade1: '#EEE8D5',
//       shade2: '#93A1A1',
//       shade3: '#839496',
//       shade4: '#657B83',
//       shade5: '#586E75',
//       shade6: '#073642',
//       shade7: '#002B36',
//     },
//   },
// };

// export default colors;