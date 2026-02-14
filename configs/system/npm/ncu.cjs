/** @type {import('npm-check-updates').RcOptions } */
module.exports = {

  "color": true,

  "cache": true,
  "cacheExpiration": "60",
  "cacheFile": "/home/patrick/github.com/davidsneighbour/dotfiles/cache/npm-ncu.json",

  //"cooldown": 5,

  "format": ["group, ownerChanged, repo, time, installedVersion"],
  "install": "prompt",
  "upgrade": true,

}
