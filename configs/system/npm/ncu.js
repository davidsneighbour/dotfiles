import { defineConfig } from 'npm-check-updates'

export default defineConfig({

  "cache": true,
  "cacheExpiration": "60",

  "color": true,
  "enginesNode": true,
  // 1: exits with error code 0 if no errors occur.
  // 2: exits with error code 0 if no packages need updating
  "errorLevel": 1,

  "install": "prompt",
  "upgrade": true,

})
