const defaultStandardVersion = require('@davidsneighbour/release-config');
const localStandardVersion = {
  scripts: {
    prerelease: "./bashrc/helpers/prerelease",
  },
  bumpFiles: [
    {
      filename: "package.json",
      type: "json",
    },
  ],
};
const standardVersion = {
  ...defaultStandardVersion,
  ...localStandardVersion,
};
module.exports = standardVersion;
