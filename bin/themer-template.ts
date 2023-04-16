import type { Template } from "themer";

const template: Template = {
    // Templates should provide a human-readable name.
    name: "My Template",

    // The render async generator function takes a color set and the render
    // options, and yields one or more output files. The color set is fully
    // expanded (e.g., if the color set did not include shades 1 through 6
    // when originally authored, those intermediary shades will have already
    // been calculated and included).
    render: async function* (colorSet, options) {
        // The yielded output file has two properties: a string path (relative)
        // and a Buffer of the file's content.
        yield {
            path: "my-file.txt",
            content: Buffer.from("Hello, world!", "utf8"),
        };
    },

    // The renderInstructions function takes an array of paths generated from
    // the render function and should return a Markdown string, which will be
    // included in the generated README.md file.
    renderInstructions: (paths) =>
        `Copy the files (${paths.join(" and ")}) to your home directory.`,
};

export default template;