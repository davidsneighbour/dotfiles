# Changelog

## [2.36.1](https://github.com/davidsneighbour/dotfiles/compare/v2.36.0...v2.36.1) (2026-11-13)

### Build

* **deps:** update caddy:2 docker digest to 9c1b76f ([#616](https://github.com/davidsneighbour/dotfiles/issues/616)) ([efaf3c2](https://github.com/davidsneighbour/dotfiles/commit/efaf3c2222bd26f19e33ff9e21fdddf6422f1204))
* **deps:** update dgtlmoon/sockpuppetbrowser:latest docker digest to 453381b ([#617](https://github.com/davidsneighbour/dotfiles/issues/617)) ([4ceccf7](https://github.com/davidsneighbour/dotfiles/commit/4ceccf7067a7bd71ae3697752b8eb242263946cf))

## [2.36.0](https://github.com/davidsneighbour/dotfiles/compare/v2.35.1...v2.36.0) (2026-11-13)

### Feat

* add hourly tracking reminders ([77deef4](https://github.com/davidsneighbour/dotfiles/commit/77deef47fb4869d5b66351b7276d86b80e541bde))
* **bashrc:** add help-driven command completion ([5fdb0dd](https://github.com/davidsneighbour/dotfiles/commit/5fdb0dd94f13510de6385d1acd0fcc1e013447ed))
* **bashrc:** register help-driven completion for dmarc ([b951d87](https://github.com/davidsneighbour/dotfiles/commit/b951d87f628e9708c8b2202e97053c3d147986c1))
* **configs:** establish local npm CLI linking ([75e5cff](https://github.com/davidsneighbour/dotfiles/commit/75e5cff046543cee3ade34914efdc3edeb006950))

### Refactor

* **ai:** modularise global agent instructions ([088e066](https://github.com/davidsneighbour/dotfiles/commit/088e0668a77d2a2825783b4283daad07cec5ab3d))
* **ai:** move decision adjudication rules to a topic file ([70edb0e](https://github.com/davidsneighbour/dotfiles/commit/70edb0e1271d25007a1a7893260750d4949bd7d7))

### Build

* **skills:** add gh skills ([a999ff6](https://github.com/davidsneighbour/dotfiles/commit/a999ff6c82f07cda55319c26b8c89f4969e2aa71))

## [2.35.1](https://github.com/davidsneighbour/dotfiles/compare/v2.35.0...v2.35.1) (2026-11-12)

### Fix

* **ai:** update humanizer skill hash in skills lockfile ([2e2208d](https://github.com/davidsneighbour/dotfiles/commit/2e2208dfcfd7ca59c554e1e0ceb4137313b0d546))
* **session:** use the documented green in polybar colours ([e6e56a1](https://github.com/davidsneighbour/dotfiles/commit/e6e56a1960d8100d4494b8039373ef038ff4481e)), references [#7C8C6A](https://github.com/davidsneighbour/dotfiles/issues/7C8C6A) [#9BAF84](https://github.com/davidsneighbour/dotfiles/issues/9BAF84)

### Docs

* **ai:** write "front matter" in global agent instructions ([62d6c74](https://github.com/davidsneighbour/dotfiles/commit/62d6c749246aca00c8a760dcde9d94a5b2837d40))
* remove pre-2.0.0 releases from changelog ([677941e](https://github.com/davidsneighbour/dotfiles/commit/677941eb3bf34f7c2a359ba89e5578b68440105d))

## [2.35.0](https://github.com/davidsneighbour/dotfiles/compare/v2.34.2...v2.35.0) (2026-11-11)

### Feat

* **session:** configure wallpaper and lock screen images centrally ([ef9087d](https://github.com/davidsneighbour/dotfiles/commit/ef9087d77db8b3516b3899b6556a4bf15d2d0380))

### Fix

* add DO_NOT_TRACK env variable ([523a76a](https://github.com/davidsneighbour/dotfiles/commit/523a76ac8ddf84de492e9b9ee530df3554bd796c))
* **ai:** update global skills ([1452020](https://github.com/davidsneighbour/dotfiles/commit/1452020f4b1c977a2aab0585996cf169ae257337))
* **session:** scale lock screen image to cover each screen ([fe35a6c](https://github.com/davidsneighbour/dotfiles/commit/fe35a6c18e912f131f39da958818fb5fdd3b2d27))
* **session:** use the JPEG lock screen image as LightDM background ([36e7df8](https://github.com/davidsneighbour/dotfiles/commit/36e7df88fa1b7e43a2bcf2e256b3f2a17373755e))
* update lockscreen and background wallpaper ([a015f3a](https://github.com/davidsneighbour/dotfiles/commit/a015f3a2aded1f90ed6d916f3af4f305460eaa05))

### Chore

* **session:** resize wallpaper and lock screen images to 2000px ([5035f02](https://github.com/davidsneighbour/dotfiles/commit/5035f026191634ed50288661e470960249ea78de))

## [2.34.2](https://github.com/davidsneighbour/dotfiles/compare/v2.34.1...v2.34.2) (2026-11-10)

### Fix

* **tools:** stop echoing non-Error values in storage server responses ([fbbc76f](https://github.com/davidsneighbour/dotfiles/commit/fbbc76f14fbb94bdb1367759a5c391441cf4251a))

### Build

* **deps:** fix vulnerable dependencies via updates and overrides ([e186444](https://github.com/davidsneighbour/dotfiles/commit/e18644497f043e06a643d6f7c3b92f3adb779929))
* **deps:** remove unused deepmerge ([02c4af4](https://github.com/davidsneighbour/dotfiles/commit/02c4af42269d875b483fc1bcb48af326c5d77214))

### Chore

* **configs:** disable heading case lint and skip scratch directories ([8b4568f](https://github.com/davidsneighbour/dotfiles/commit/8b4568f29afc3c28dd89603d4b1324b7ca0a52de))

## [2.34.1](https://github.com/davidsneighbour/dotfiles/compare/v2.34.0...v2.34.1) (2026-11-10)

### Fix

* **bashrc:** guard missing state entries in OpenRouter helper ([88310da](https://github.com/davidsneighbour/dotfiles/commit/88310da940a44bd953188da522dee5a451adec3a))
* **configs:** skip Node.js pre-releases in the Current update job ([eb69afb](https://github.com/davidsneighbour/dotfiles/commit/eb69afb4b218fa1b47df06a8ab1692fcd20c60f1))

### Chore

* **configs:** remove mise and use nvm as the only Node manager ([fd27256](https://github.com/davidsneighbour/dotfiles/commit/fd27256ae0427ac563a363302e451f15a8eb9bb8))
* **deps:** update caddy:2 docker digest to ce773ec ([#610](https://github.com/davidsneighbour/dotfiles/issues/610)) ([b6be16e](https://github.com/davidsneighbour/dotfiles/commit/b6be16e280b04dab9b64d3cce329d4f5179f04dc))
* **deps:** update docker.io/library/redis:8 docker digest to 1f88291 ([#614](https://github.com/davidsneighbour/dotfiles/issues/614)) ([6a2172f](https://github.com/davidsneighbour/dotfiles/commit/6a2172fe5200d49f273291bc9e17e8f06a4fbe31))
* **deps:** update ghcr.io/alexta69/metube:latest docker digest to 96dfbf0 ([#611](https://github.com/davidsneighbour/dotfiles/issues/611)) ([4d1faba](https://github.com/davidsneighbour/dotfiles/commit/4d1faba94e7cc72cc3dfd54a2ccc264134ae704f))
* **deps:** update ghcr.io/dgtlmoon/changedetection.io:latest docker digest to 47b1e9c ([#612](https://github.com/davidsneighbour/dotfiles/issues/612)) ([8dc5b38](https://github.com/davidsneighbour/dotfiles/commit/8dc5b384f0eb6a8917b829285a18b5d831abfcaf))
* **deps:** update ghcr.io/paperless-ngx/paperless-ngx:latest docker digest to d704e84 ([#613](https://github.com/davidsneighbour/dotfiles/issues/613)) ([d29b14a](https://github.com/davidsneighbour/dotfiles/commit/d29b14a13a151f50dc2b675648cea3d3bac4b0ef))
* **deps:** update louislam/uptime-kuma:2 docker digest to e88415a ([#615](https://github.com/davidsneighbour/dotfiles/issues/615)) ([d35c749](https://github.com/davidsneighbour/dotfiles/commit/d35c74998668f68e4cc481e95ee74e203e07c16f))

## [2.34.0](https://github.com/davidsneighbour/dotfiles/compare/v2.33.1...v2.34.0) (2026-11-09)

### Feat

* add Paper Mono font ([3e95034](https://github.com/davidsneighbour/dotfiles/commit/3e9503463cf12f8648b64b7340df2c95b737eb6f))
* **agents:** add and adopt skills with the agent-skills command ([9747e95](https://github.com/davidsneighbour/dotfiles/commit/9747e9513eeb4e7648c7f9aa8085ccc03334e76c))
* **agents:** manage third-party skills through a tracked lockfile ([c762db3](https://github.com/davidsneighbour/dotfiles/commit/c762db30f919b4a2c555c624824bf12032b4ddb7))
* **bashrc:** use eza with icons and long listings for ls shortcuts ([ac64d54](https://github.com/davidsneighbour/dotfiles/commit/ac64d54a9ec330fb05ea22f5053544bbaf8c96d3))
* **containers:** add OpenSEO and OpenProject stacks for hal2026 ([13ae372](https://github.com/davidsneighbour/dotfiles/commit/13ae372ae9e2795beed553f49a0b42376bd417bc))
* **containers:** serve FreshRSS over HTTPS on the LAN address ([a706aee](https://github.com/davidsneighbour/dotfiles/commit/a706aeecc2ac2505b010c3ac86536905f9df4724))
* **session:** manage eza theme through dotbot ([65973c3](https://github.com/davidsneighbour/dotfiles/commit/65973c3e20160016256b6c542eb5e11ae35ff755))

### Fix

* **bashrc:** clearout unused particles in bashrc ([28233f2](https://github.com/davidsneighbour/dotfiles/commit/28233f29df20fb40e0edd064f1d3d77501fab14a))
* **bashrc:** keep the skillz cleanup step from failing on managed links ([a53201c](https://github.com/davidsneighbour/dotfiles/commit/a53201c2a22222e3f701fddaf94b55e856ebbbdc))
* **bashrc:** report all skillz name conflicts in one run ([26bc369](https://github.com/davidsneighbour/dotfiles/commit/26bc36969fe698b47cc5240ea83ddf375015a900))
* **dotbot:** use cron Node runtime for log cleanup ([3808558](https://github.com/davidsneighbour/dotfiles/commit/3808558e75cc0067baaeb04a387dfc773e384e4f))
* **session:** normalise Thunar accelerator map header in Git ([ab52318](https://github.com/davidsneighbour/dotfiles/commit/ab52318e272e4fabd94bdfaf8231e736aaffd137))

### Docs

* **agents:** commit completed changes without asking ([94c7a81](https://github.com/davidsneighbour/dotfiles/commit/94c7a81022ccfe3e9298d6c82b2980018c0ff076))

### Build

* **deps:** update dependencies ([354d7e5](https://github.com/davidsneighbour/dotfiles/commit/354d7e5ba5350f9f8d2dd4fa8729074124a12ff5))
* **vscode:** use Monaspace Argon NF for terminal icons ([551f2e3](https://github.com/davidsneighbour/dotfiles/commit/551f2e31b8404b494d8871f6141680324a06ef2e))

### Chore

* **agents:** track 229 more third-party skills ([a5139c8](https://github.com/davidsneighbour/dotfiles/commit/a5139c8d0ea2b60d6ad9037307543386b7d449f6))
* **agents:** track the GSAP skills in the skills lockfile ([5539ca9](https://github.com/davidsneighbour/dotfiles/commit/5539ca9a9c97dcac8bc6a27821496da85e62f0df))
* **bashrc:** link the skills repository through skillz again ([f4e6469](https://github.com/davidsneighbour/dotfiles/commit/f4e6469f32220bfc5501b81d58b8d41e94271a67))
* **containers:** remove OpenSEO stack from hal2026 ([88f6fca](https://github.com/davidsneighbour/dotfiles/commit/88f6fca01b954f45d22ce6dd349dbd61b8702a34))

## [2.33.1](https://github.com/davidsneighbour/dotfiles/compare/v2.33.0...v2.33.1) (2026-11-05)

### Chore

* **deps:** pin dependencies ([#606](https://github.com/davidsneighbour/dotfiles/issues/606)) ([29219bb](https://github.com/davidsneighbour/dotfiles/commit/29219bb198b09d0b7ed66bd58bcb27f4c1281cd3))
* **deps:** update binwiederhier/ntfy:latest docker digest to 1875ddc ([#607](https://github.com/davidsneighbour/dotfiles/issues/607)) ([c4c885d](https://github.com/davidsneighbour/dotfiles/commit/c4c885dacee22cb02df5c5168cf33fb0aaa68ca9))
* **deps:** update docker.io/library/redis:8 docker digest to f245f4c ([#608](https://github.com/davidsneighbour/dotfiles/issues/608)) ([8236876](https://github.com/davidsneighbour/dotfiles/commit/82368767c8746f4abec32e6558bbe8cef931ad2e))
* **deps:** update ghcr.io/alexta69/metube:latest docker digest to a97f455 ([#609](https://github.com/davidsneighbour/dotfiles/issues/609)) ([687f8b3](https://github.com/davidsneighbour/dotfiles/commit/687f8b3419f814e0f77649357fc05bd658c72bea))

## [2.33.0](https://github.com/davidsneighbour/dotfiles/compare/v2.32.0...v2.33.0) (2026-11-05)

### Feat

* **tools:** add Clockify tag classes ([d6b3ea6](https://github.com/davidsneighbour/dotfiles/commit/d6b3ea61d1cdadcd6fdffc69f56f3e3694a8017e))

### Fix

* **tools:** isolate i3 validation runtime ([01ef31c](https://github.com/davidsneighbour/dotfiles/commit/01ef31c957dcd02090e598b5a9a91e01beef84d5))

## [2.32.0](https://github.com/davidsneighbour/dotfiles/compare/v2.31.2...v2.32.0) (2026-11-04)

### Feat

* **config:** add central configuration tools ([af2ceea](https://github.com/davidsneighbour/dotfiles/commit/af2ceea3262c34727d06de2f98a262f613ba3d10))

### Fix

* **session:** use i3lock-color for the themed lock screen ([6757b1f](https://github.com/davidsneighbour/dotfiles/commit/6757b1f47aa44058fd9988e397c34dd5c5b22b43))

### Refactor

* **agents:** rename global instruction source ([25f183d](https://github.com/davidsneighbour/dotfiles/commit/25f183de76087932e8625c0cc6ef3537ad75667c))

### Docs

* **agents:** update global working instructions ([2d6cd7a](https://github.com/davidsneighbour/dotfiles/commit/2d6cd7a8c22061244cda0d8ada4d078a65b33ccc))

### Build

* **deps:** update development dependencies ([859d204](https://github.com/davidsneighbour/dotfiles/commit/859d2040dcd118e2ab80d7e029ccf219dd0b9c01))

### Chore

* **editor:** configure schema and workspace colour ([aab8fc6](https://github.com/davidsneighbour/dotfiles/commit/aab8fc667cfd69f7ffd2654c7e4303b3736d3ca1))

## [2.31.2](https://github.com/davidsneighbour/dotfiles/compare/v2.31.1...v2.31.2) (2026-11-03)

### Fix

* **polybar:** greener green ([28e24f4](https://github.com/davidsneighbour/dotfiles/commit/28e24f42697477cc81d9ca188dfac1655a33dbf5))
* purge atuin docs ([50b86ee](https://github.com/davidsneighbour/dotfiles/commit/50b86eee26b7c22192d31c8f8f87cab3c5c89435))
* **session:** detach browser during gdrive reauth ([c665c83](https://github.com/davidsneighbour/dotfiles/commit/c665c8350a6c5a63a45f92e0fbff0229f7526033))

### Refactor

* keep shared agent instructions in dotfiles ([ba3ca0c](https://github.com/davidsneighbour/dotfiles/commit/ba3ca0c86baa8c2f4b646c43d53514478c7e9543))

### Test

* redirect colour checks explicitly ([96ac92f](https://github.com/davidsneighbour/dotfiles/commit/96ac92f875d68e5fb69abb4ac4820aa634410c48))

## [2.31.1](https://github.com/davidsneighbour/dotfiles/compare/v2.31.0...v2.31.1) (2026-11-01)

### Docs

* **ai:** add ubuntu wiki mcp setup ([e41fa4c](https://github.com/davidsneighbour/dotfiles/commit/e41fa4cdc227c570db5cbf6f14d34f4eac0192bc))

### Build

* **deps:** update dependencies ([17c43d5](https://github.com/davidsneighbour/dotfiles/commit/17c43d5007653abd4ac10e94465b9dd96594b5da))

## [2.31.0](https://github.com/davidsneighbour/dotfiles/compare/v2.30.1...v2.31.0) (2026-10-31)

### Feat

* **bashrc:** add a row counter to git-repos-status ([bab23f8](https://github.com/davidsneighbour/dotfiles/commit/bab23f83b8d07983879aaa74124f58417ea9cfa8))
* **bashrc:** default git-repos-status to the current directory ([f8c1953](https://github.com/davidsneighbour/dotfiles/commit/f8c19539f9c66300c40d80505240df4651df4ae2))
* **bashrc:** let git-repos-status check a single repository root ([cab73d7](https://github.com/davidsneighbour/dotfiles/commit/cab73d7266d02f78b995be251bd85958c5c72094))

### Build

* **containers:** pin hal2025 images by digest and let Renovate update them ([eeb0fae](https://github.com/davidsneighbour/dotfiles/commit/eeb0fae1b8460fbf28de51c40f4fc84d37f52a7f))
* **containers:** update locutus images to latest versions ([5313562](https://github.com/davidsneighbour/dotfiles/commit/5313562f450db97e771d91913e10802dfdaf3675))

### Chore

* **configs:** archive hal2026 Argon ONE V2 setup scripts ([7e09acd](https://github.com/davidsneighbour/dotfiles/commit/7e09acd2e9dc0c425bba0ba4439ff4942bba200a))
* **deps:** update dependency lucide-react to v1.62.0 ([#605](https://github.com/davidsneighbour/dotfiles/issues/605)) ([b538038](https://github.com/davidsneighbour/dotfiles/commit/b538038b22f73a886a4fba7bd7408d43b4547bc9))
* **linting:** remove markdownlint ignore for deleted theme folder ([c4accf2](https://github.com/davidsneighbour/dotfiles/commit/c4accf2d13c4bea6460f27b4f46fbbb3b5ee3a62))

## [2.30.1](https://github.com/davidsneighbour/dotfiles/compare/v2.30.0...v2.30.1) (2026-10-30)

### Fix

* **workspaces:** add icon rules for new VS Code class and ChatGPT app ([662aa8a](https://github.com/davidsneighbour/dotfiles/commit/662aa8a8abae2f355f6994fbcedcf091ff537166))

### Docs

* **fix:** update tools README.md ([7ed138f](https://github.com/davidsneighbour/dotfiles/commit/7ed138f2d836ff564dc0c44167895b6ed34f33f9))

### Build

* **deps:** update lockfile dependencies ([#604](https://github.com/davidsneighbour/dotfiles/issues/604)) ([6db509a](https://github.com/davidsneighbour/dotfiles/commit/6db509ac6397d5d4280d646d02de4b75598b8401))

### Chore

* **git:** align delta syntax theme with the DNB terminal theme ([dc08306](https://github.com/davidsneighbour/dotfiles/commit/dc08306904324a8ebce12848010e82e9d5513773)), closes [#602](https://github.com/davidsneighbour/dotfiles/issues/602)

## [2.30.0](https://github.com/davidsneighbour/dotfiles/compare/v2.29.0...v2.30.0) (2026-10-29)

### Feat

* add gdrive PATH wrapper and profile listing ([471dd09](https://github.com/davidsneighbour/dotfiles/commit/471dd098a960439dfdb13184cc4e09a4f9004618))
* **bashrc:** add DNB terminal UI facade with Dracula Pro theme ([2f7d11f](https://github.com/davidsneighbour/dotfiles/commit/2f7d11faffa61356103d73398005aaff1c47d3f2)), references [#602](https://github.com/davidsneighbour/dotfiles/issues/602)
* **bashrc:** add OpenRouter model catalogue helper ([d0ea4e0](https://github.com/davidsneighbour/dotfiles/commit/d0ea4e0bc685ae141c981916c1f024c3e7a966f8))
* **bashrc:** keep mailbox history in a gitignored data directory ([fa7380f](https://github.com/davidsneighbour/dotfiles/commit/fa7380f8995b90495a4486b0d954760df356f5ad))
* **bashrc:** log mailbox quota history and add history analyser ([2e4b26f](https://github.com/davidsneighbour/dotfiles/commit/2e4b26f0e79cd19d906452433ea0a0ca7d06494e))
* **bashrc:** switch to the Dracula Pro Nosferatu palette ([57f8d98](https://github.com/davidsneighbour/dotfiles/commit/57f8d987c0bf557ad1dcbad9d8877e83be4ca279))
* **configs:** maintain a stable LTS runtime for cron ([f4a25f8](https://github.com/davidsneighbour/dotfiles/commit/f4a25f81f9ccd96492fe584a38e367505b309372))

### Fix

* **starship:** use Nosferatu colours for git status dots ([0d06471](https://github.com/davidsneighbour/dotfiles/commit/0d06471f5095ae2e608e1dea5ff08e79546a0572))
* **workspace:** launch WhatsApp on a dynamic workspace ([2c284a9](https://github.com/davidsneighbour/dotfiles/commit/2c284a96026025369f695a6c702313a01734ea95))

### Docs

* add Tailscale network reference ([02b5cb4](https://github.com/davidsneighbour/dotfiles/commit/02b5cb42a99e22c6a0c83d201d760c859dd0d552))
* align and optimise agent instructions ([2c24f3e](https://github.com/davidsneighbour/dotfiles/commit/2c24f3e01c43fd1baef7c9ee92f4d2a7ad136320))

### Build

* **deps:** update dependencies ([77f0cc0](https://github.com/davidsneighbour/dotfiles/commit/77f0cc0164f38b9bdec4ca2a092a5cca79a34259))
* **deps:** update secretlint to 13.1.0 and @types/node to 26.6.6 ([5668f92](https://github.com/davidsneighbour/dotfiles/commit/5668f923396cf38c1158974b531c30aa354ec1bb))

### Chore

* **bashrc:** remove mailbox monitor export.html ([9ef6ca7](https://github.com/davidsneighbour/dotfiles/commit/9ef6ca75217f95f5fc64248e4bf1037ba39a0823))
* **fonts:** update Lucide icon font ([b4af093](https://github.com/davidsneighbour/dotfiles/commit/b4af093e392357c21319220109f97c1cd6884c1a))

## [2.29.0](https://github.com/davidsneighbour/dotfiles/compare/v2.28.2...v2.29.0) (2026-10-27)

### Feat

* **session:** add dedicated WhatsApp browser app ([0f852a8](https://github.com/davidsneighbour/dotfiles/commit/0f852a8ade82068c2f1204e484a871e300eab911))

### Style

* **polybar:** pad status indicators ([86dc037](https://github.com/davidsneighbour/dotfiles/commit/86dc03762ceec86e05a5efbd58dad4f3d9226853))

## [2.28.2](https://github.com/davidsneighbour/dotfiles/compare/v2.28.1...v2.28.2) (2026-10-25)

### Fix

* update package.json for mailbox monitor ([59104f9](https://github.com/davidsneighbour/dotfiles/commit/59104f92e4619f7007ece57e4c2d458a871f77c7))

### Refactor

* **bashrc:** read mailbox quotas over SSH instead of the Pair panel ([7ba59b8](https://github.com/davidsneighbour/dotfiles/commit/7ba59b8c3ab85d28ba9bd73289ebf355bd66c4c4))

## [2.28.1](https://github.com/davidsneighbour/dotfiles/compare/v2.28.0...v2.28.1) (2026-10-25)

### Docs

* **session:** document the current desktop setup only ([70861bc](https://github.com/davidsneighbour/dotfiles/commit/70861bc575baaea40ac909fbe416553b6d1e52ae))

## [2.28.0](https://github.com/davidsneighbour/dotfiles/compare/v2.27.0...v2.28.0) (2026-10-25)

### Feat

* **packages:** add --depends-only option to tree and why ([a6078c0](https://github.com/davidsneighbour/dotfiles/commit/a6078c097733c3944daef6efb641491e7b92e9bb)), closes [#585](https://github.com/davidsneighbour/dotfiles/issues/585)
* **packages:** add --json, --version, history, and Graphviz export ([45726cf](https://github.com/davidsneighbour/dotfiles/commit/45726cfa3779691b139648a4817b4a70c9e5b009)), closes [#586](https://github.com/davidsneighbour/dotfiles/issues/586)

### Refactor

* **configs:** move remaining configs/system into configs/session ([bc9ffd9](https://github.com/davidsneighbour/dotfiles/commit/bc9ffd975fabe4c76fb2268289f33e38894b20f5))

### Build

* **biome:** exclude markdown files ([079f3f1](https://github.com/davidsneighbour/dotfiles/commit/079f3f1fca14b9dde1d3a4c16bef595984bd4f9b))
* **deps:** bump the npm_and_yarn group across 1 directory with 2 updates ([#601](https://github.com/davidsneighbour/dotfiles/issues/601)) ([43ed310](https://github.com/davidsneighbour/dotfiles/commit/43ed3106e29745a40934ecee80dda2e023224a63))
* **deps:** update dependencies ([6bcfe94](https://github.com/davidsneighbour/dotfiles/commit/6bcfe9497024665e614a2fd9b5e6dbf67e7f06db))

### Chore

* **deps:** update dependency lucide-react to v1.61.0 ([#599](https://github.com/davidsneighbour/dotfiles/issues/599)) ([85f78f7](https://github.com/davidsneighbour/dotfiles/commit/85f78f7ac0caf6201b78703c03c60f99495eb5ba))
* **deps:** update dependency vite to v8.3.5 ([#600](https://github.com/davidsneighbour/dotfiles/issues/600)) ([899cac2](https://github.com/davidsneighbour/dotfiles/commit/899cac25a14d6593886803b65e1e370793726c50))
* **deps:** update react monorepo to v19.3.1 ([#598](https://github.com/davidsneighbour/dotfiles/issues/598)) ([28dab00](https://github.com/davidsneighbour/dotfiles/commit/28dab00c72f812ac8a18885e5a46d4e463ff44d2))

## [2.27.0](https://github.com/davidsneighbour/dotfiles/compare/v2.26.0...v2.27.0) (2026-10-25)

### Feat

* **git-collection:** accept expected missing repositories ([eff1f95](https://github.com/davidsneighbour/dotfiles/commit/eff1f95116250ff8f7f68f7f1730c57e7a241c6a))
* **session:** start Obsidian with gnome-libsecret password store ([2a68804](https://github.com/davidsneighbour/dotfiles/commit/2a68804c9e2a50094f50c4bf3796a4aaf7a819a6))

### Fix

* update lucide font preview list ([af0581d](https://github.com/davidsneighbour/dotfiles/commit/af0581d6a2317767e5db75c43abe26acd41cf017))

### Build

* **deps:** update dependencies ([4e76f2e](https://github.com/davidsneighbour/dotfiles/commit/4e76f2ee6d8d1f06bf8108b5f2654343b7f7fcd2))

### Chore

* **fonts:** link Nagasaki font from protected repository ([e5bfdbe](https://github.com/davidsneighbour/dotfiles/commit/e5bfdbe27569c8b68ccc1eeb94d22db887bba585))
* **fonts:** update Lucide icon font ([cabd297](https://github.com/davidsneighbour/dotfiles/commit/cabd297755550af37afbe86a8333256220bf1e00))
* **session:** add VoiceStudio 0.5.6 launcher ([6908397](https://github.com/davidsneighbour/dotfiles/commit/690839795134f8a44bea538b4895438b67454f0c))
* **session:** register Claude launcher for MCP bundle and skill files ([69ad7e9](https://github.com/davidsneighbour/dotfiles/commit/69ad7e90036f8484f95581ee3c323ee922789c55))

## [2.26.0](https://github.com/davidsneighbour/dotfiles/compare/v2.25.0...v2.26.0) (2026-10-23)

### Feat

* **session:** start Discord minimised at login ([2c26901](https://github.com/davidsneighbour/dotfiles/commit/2c26901a2646d7d8c5d11bf5b828264df7bda342))
* **tools:** add storage catalogue and search ([9f459ba](https://github.com/davidsneighbour/dotfiles/commit/9f459ba153281be817ac172a0988326d690a8b13))

### Fix

* **bashrc:** restore Pair mailbox monitoring with 2FA ([0698e7b](https://github.com/davidsneighbour/dotfiles/commit/0698e7bb5e6ea53713d94b19fb9eabbb985c7475))

### Chore

* **session:** update Recordly launcher to 1.4.0 ([64190ae](https://github.com/davidsneighbour/dotfiles/commit/64190ae9394af0509a89f80ddd2622fb434bbd02))

## [2.25.0](https://github.com/davidsneighbour/dotfiles/compare/v2.24.0...v2.25.0) (2026-10-21)

### Feat

* **session:** add floating tasks app window on Ctrl+Shift+Alt+P ([d631bff](https://github.com/davidsneighbour/dotfiles/commit/d631bffb5958defa703d1cac20f7b77d60529c4e))

### Build

* **containers:** update locutus images to latest versions ([9b2ae51](https://github.com/davidsneighbour/dotfiles/commit/9b2ae51e25144e434522fece6ac4a8b19473f601))

### Chore

* **containers:** stop tracking stirling data directory ([9baf693](https://github.com/davidsneighbour/dotfiles/commit/9baf693c8d04daff6d15e03cb864b2114358212a))
* **mise:** pin node 26 for mise ([950e9f7](https://github.com/davidsneighbour/dotfiles/commit/950e9f73bde6ad714d5c53d28a20ce2f91a57980))
* **vscode:** sort dictionary and add truecolor terms ([63e6955](https://github.com/davidsneighbour/dotfiles/commit/63e6955b790c9edc41b37b4af7afa6513b7cf203))

## [2.24.0](https://github.com/davidsneighbour/dotfiles/compare/v2.23.1...v2.24.0) (2026-10-18)

### Feat

* **git:** add git-repos-status helper for multi-repository overview ([f2f33f5](https://github.com/davidsneighbour/dotfiles/commit/f2f33f50724fc0da8fca7f17ad86c5f70b8c248d))

### Build

* **deps:** bump source-map-js ([#592](https://github.com/davidsneighbour/dotfiles/issues/592)) ([1ca5b61](https://github.com/davidsneighbour/dotfiles/commit/1ca5b61c1022c8197f21b1555147339cd9d7d256))
* **deps:** update dependencies ([cb32579](https://github.com/davidsneighbour/dotfiles/commit/cb32579ca33f0b03f59d32c9028e0ce00f5725ae))
* **deps:** update dependency @types/node to v26.6.5 ([#593](https://github.com/davidsneighbour/dotfiles/issues/593)) ([b121217](https://github.com/davidsneighbour/dotfiles/commit/b121217791b643bf39376235f3d65d4a10915bb4))
* **deps:** update dependency @types/node to v26.6.5 ([#594](https://github.com/davidsneighbour/dotfiles/issues/594)) ([5c9b1ca](https://github.com/davidsneighbour/dotfiles/commit/5c9b1cabd399c8f1680ddab1dec0215f7334dcf0))
* **deps:** update dependency @vitejs/plugin-react to v6.1.2 ([#588](https://github.com/davidsneighbour/dotfiles/issues/588)) ([421c647](https://github.com/davidsneighbour/dotfiles/commit/421c64795216bd86038a053d0d2729c7a85caee9))
* **deps:** update dependency lucide-react to v1.57.0 ([#590](https://github.com/davidsneighbour/dotfiles/issues/590)) ([1cb8e68](https://github.com/davidsneighbour/dotfiles/commit/1cb8e686fd276269b5fefe851c18fe3d3df524cb))
* **deps:** update dependency playwright to v1.64.1 ([#595](https://github.com/davidsneighbour/dotfiles/issues/595)) ([fc22329](https://github.com/davidsneighbour/dotfiles/commit/fc223290b3f8d746e4c1c76eb5dba2ab02cad560))
* **deps:** update dependency playwright to v1.64.1 ([#596](https://github.com/davidsneighbour/dotfiles/issues/596)) ([2096533](https://github.com/davidsneighbour/dotfiles/commit/2096533e3998200dc74d284de90778aa5f9ec28f))
* **deps:** update dependency vite to v8.3.4 ([#589](https://github.com/davidsneighbour/dotfiles/issues/589)) ([acf3482](https://github.com/davidsneighbour/dotfiles/commit/acf3482c315e4591aab4b5d445971e18d39ca6cd))
* **deps:** update radix-ui-primitives monorepo ([#591](https://github.com/davidsneighbour/dotfiles/issues/591)) ([6da0ac7](https://github.com/davidsneighbour/dotfiles/commit/6da0ac7f5b3e8be010179f120c9a1956111fa781))

## [2.23.1](https://github.com/davidsneighbour/dotfiles/compare/v2.23.0...v2.23.1) (2026-10-18)

### Fix

* **dotbot:** update node version for cronjobs ([bfc87aa](https://github.com/davidsneighbour/dotfiles/commit/bfc87aae2d9d13a2c50d5f441a8efb351a4762d0))

## [2.23.0](https://github.com/davidsneighbour/dotfiles/compare/v2.22.0...v2.23.0) (2026-10-15)

### Feat

* **i3:** toggle Myna dictation with Ctrl+Shift+Alt+Q ([d20ad54](https://github.com/davidsneighbour/dotfiles/commit/d20ad547b0e0dcea627b7f90160f39e8fccd3a23))

### Fix

* **containers:** remove readeck ([0c322de](https://github.com/davidsneighbour/dotfiles/commit/0c322de96a33a7e73a9420b025cf7517e960abf3))
* **i3:** float Chrome dropdown and popup menus without borders ([d1b7fc3](https://github.com/davidsneighbour/dotfiles/commit/d1b7fc3a0c267d30c90c63b81434fcf626ccda68))
* **session:** start a graphical authentication agent in i3 ([856cf9a](https://github.com/davidsneighbour/dotfiles/commit/856cf9a174adbbd39dbe189d1c34b7a5224a6f3b))

### Style

* **workspaces:** remove trailing blank line in cookie clicker launcher ([f28eaa1](https://github.com/davidsneighbour/dotfiles/commit/f28eaa1c05aeb032343a5f32d84b7d53cd82252a))

### Chore

* **i3:** add content review layout for Independence Yacht Charter ([b578771](https://github.com/davidsneighbour/dotfiles/commit/b57877195a4bf2fecaa7c857d9d71124086e35dd))

## [2.22.0](https://github.com/davidsneighbour/dotfiles/compare/v2.21.0...v2.22.0) (2026-10-14)

### Feat

* **i3:** add workspace layout save and restore ([9793608](https://github.com/davidsneighbour/dotfiles/commit/9793608ade9da91280eb36ccffcbb71f69b085de))
* **i3:** move focused window to next workspace with Ctrl+Super+Right ([f179fc0](https://github.com/davidsneighbour/dotfiles/commit/f179fc0d09e9a8c5eb79f7272b9473898222b759))
* lucide font downloader ([76de8a6](https://github.com/davidsneighbour/dotfiles/commit/76de8a608a3c32e6239cc77fdec9d1550275cfe4))
* **packages:** add read-only APT package inspection tool ([7995ca4](https://github.com/davidsneighbour/dotfiles/commit/7995ca4595604f96abc68855ad6bd54324c74879))
* **polybar:** update Clockify icons and use standard icon size ([11e8a54](https://github.com/davidsneighbour/dotfiles/commit/11e8a5411824df8a86f5b05ac164cfdb8cdd5877))
* **session:** add system checkup with Polybar alert ([3c75342](https://github.com/davidsneighbour/dotfiles/commit/3c75342bfd3494ff5d7860c66a23b79ae2ae7afd))
* **session:** move session health checks into system checkup ([aed95cd](https://github.com/davidsneighbour/dotfiles/commit/aed95cd9fb9dffee25a3ccca5ff31056a9ad3f84))

### Fix

* add ai file check to system checkup ([a41727d](https://github.com/davidsneighbour/dotfiles/commit/a41727d3cd55f14aca556ebe5b8b52c51651ff18))
* commit without linting contents of lucide font package ([747ad54](https://github.com/davidsneighbour/dotfiles/commit/747ad54921a80114317f400ff1cb87f8feaa7ff9))
* open new window on subl call ([8a9b1f7](https://github.com/davidsneighbour/dotfiles/commit/8a9b1f794360d883f29e243b4ccc3cc4db5173d0))
* remove obsolete interface restart ([44f3a4e](https://github.com/davidsneighbour/dotfiles/commit/44f3a4e85e499954fd7822a8a6f0eaa2a46dc6d1))
* **session:** start xss-lock only from the i3 session ([b3c3f83](https://github.com/davidsneighbour/dotfiles/commit/b3c3f83caefc0dbee0959b567ef1b6bbf50063df))
* **session:** stop stale gdrive auth process blocking reauth ([725c158](https://github.com/davidsneighbour/dotfiles/commit/725c158a0c651aaf78d0c1da7ee93b2256baea1c))
* **subl:** update sublime edit configuration ([9891430](https://github.com/davidsneighbour/dotfiles/commit/98914301ccb30a24beca579e976f2dc93da933d3))
* **workspaces:** cookieclicker icon ([6e4d233](https://github.com/davidsneighbour/dotfiles/commit/6e4d2330be18c0a900ce0cf26a1bd238c86dff30))
* **workspaces:** update enpass icon setup ([a9fd077](https://github.com/davidsneighbour/dotfiles/commit/a9fd077ada76b3a818f9ba0236b02402c0d2c4ff))
* **workspaces:** write icons as escapes and add a Chrome icon ([9a525c3](https://github.com/davidsneighbour/dotfiles/commit/9a525c3199b23a48ea4c10f62304ede05743bdf4))

### Docs

* **packages:** link the planned additions to their issues ([d5e3667](https://github.com/davidsneighbour/dotfiles/commit/d5e36670080165db46a0d067e75ecd98b1e650e7))

### Build

* **deps:** update dependencies ([f30ce6c](https://github.com/davidsneighbour/dotfiles/commit/f30ce6cac4069bc45c52bb9e00e5ba5132433e3c))
* **deps:** update dependencies ([38fe15d](https://github.com/davidsneighbour/dotfiles/commit/38fe15d4a5c523f712ba206a2132802f69f8c1df))
* **deps:** update dependencies ([8d69545](https://github.com/davidsneighbour/dotfiles/commit/8d695454702a2f2699c221a8191d387c75959dd8))
* **deps:** update dependencies ([56fac02](https://github.com/davidsneighbour/dotfiles/commit/56fac029657bf07e0a2fc99e924ac90356cdfdb3))

### Chore

* **fonts:** update Lucide icon font ([f7a31d8](https://github.com/davidsneighbour/dotfiles/commit/f7a31d8c88085e0758a8fc43bb6127a7ad645e85))

## [2.21.0](https://github.com/davidsneighbour/dotfiles/compare/v2.20.0...v2.21.0) (2026-10-05)

### Feat

* **skillz:** add typed skill sources with nested tree support ([5f6bc46](https://github.com/davidsneighbour/dotfiles/commit/5f6bc46bad66392796d6c0134428764232e730fe))

### Fix

* weird spelling change in thunar config ([1e6ec36](https://github.com/davidsneighbour/dotfiles/commit/1e6ec3651f4931b27d448abea27c2635c014e71f))

## [2.20.0](https://github.com/davidsneighbour/dotfiles/compare/v2.19.1...v2.20.0) (2026-10-04)

### Feat

* add Git catalogue and update workstation assets ([cf9e2ac](https://github.com/davidsneighbour/dotfiles/commit/cf9e2accef5d43883d8eab16c8a93ae20e011ff8))
* schedule dotfiles Git catalogue updates ([bcf828f](https://github.com/davidsneighbour/dotfiles/commit/bcf828f76a12672f4881bb2f3b85786583a903a2))
* **session:** add dark mode and Enpass overrides ([ac904dd](https://github.com/davidsneighbour/dotfiles/commit/ac904dde3fafc8a64b1926b65fa7ea27402c6bc5))

### Perf

* scale Git reports for the approved repository scope ([4ed1c54](https://github.com/davidsneighbour/dotfiles/commit/4ed1c54aa9ecf168407bfbee866418e3ebfba5ff))

## [2.19.1](https://github.com/davidsneighbour/dotfiles/compare/v2.19.0...v2.19.1) (2026-10-03)

### Fix

* **i3:** adapt to new vscode class name ([a89caf5](https://github.com/davidsneighbour/dotfiles/commit/a89caf5dde0fd8974ce6dd44c21e29bb4d2f4035))

## [2.19.0](https://github.com/davidsneighbour/dotfiles/compare/v2.18.0...v2.19.0) (2026-10-03)

### Feat

* **workspace:** add Git commit archive and cron sync ([eefb033](https://github.com/davidsneighbour/dotfiles/commit/eefb033f67efa9076b2c5ad836389881e4a131ff))

### Fix

* remove git commit log event log ([04aa950](https://github.com/davidsneighbour/dotfiles/commit/04aa950b16b96a4de253fff00c757de3125e16ba))
* update session wallpaper ([fd46ced](https://github.com/davidsneighbour/dotfiles/commit/fd46ced7aa3d7a5abba34e0c652cbfb508170791))

### Build

* **deps:** update dependencies ([f5af07e](https://github.com/davidsneighbour/dotfiles/commit/f5af07ebbb5df2b26e58feb1ac84d1f1f5dbb644))
* **deps:** update dependencies ([2b7def0](https://github.com/davidsneighbour/dotfiles/commit/2b7def0a39908878eac7e6fe83957738d3f15678))

### Chore

* **deps:** update dependency vite to v8.3.1 ([#583](https://github.com/davidsneighbour/dotfiles/issues/583)) ([9726e8c](https://github.com/davidsneighbour/dotfiles/commit/9726e8c15b80024e4dcb8c94001327b1f0b01aba))
* **session:** move i3lock files into i3 config directory ([e2445e8](https://github.com/davidsneighbour/dotfiles/commit/e2445e8280a187126b701c400d07c8fda243151a))

## [2.18.0](https://github.com/davidsneighbour/dotfiles/compare/v2.17.0...v2.18.0) (2026-10-02)

### Feat

* **gh:** add clone-all command to github-manager ([147e80c](https://github.com/davidsneighbour/dotfiles/commit/147e80ccd08224dd8e9b6179b89922d78beb9993))

### Fix

* **rofi:** update power menu design ([bbba32b](https://github.com/davidsneighbour/dotfiles/commit/bbba32b53e85143a9d6ff81a3846507afce0f3d0))

### Build

* **deps:** override basic-ftp to 6.2.1 for get-uri ([0374366](https://github.com/davidsneighbour/dotfiles/commit/037436659193bafbbc232278eab9db152eca459f))

### Chore

* **session:** add Claude desktop launcher and update Thunar shortcuts ([e83ab17](https://github.com/davidsneighbour/dotfiles/commit/e83ab1777815afcdc1239dbb82cf66f7df233aa7))

## [2.17.0](https://github.com/davidsneighbour/dotfiles/compare/v2.16.3...v2.17.0) (2026-09-30)

### Feat

* add interface sounds for notifications ([d5d37d0](https://github.com/davidsneighbour/dotfiles/commit/d5d37d031848ee3fceea9110888a5b360b9948a8))

### Fix

* add statuss alias to git config ([9bcb6dd](https://github.com/davidsneighbour/dotfiles/commit/9bcb6dd0276b3eaf85ec6e509feb096b5b2e8f60))
* **clockify:** hide new tag field behind toggle ([c137dab](https://github.com/davidsneighbour/dotfiles/commit/c137dabaf7f17945b0e8222ea84f188341dbadbb))

### Build

* **deps:** update dependencies ([c45dca1](https://github.com/davidsneighbour/dotfiles/commit/c45dca1d779ba25ee9fe1cd3cf04000e4d10f16a))
* **deps:** update dependencies and fix audit findings ([683aa19](https://github.com/davidsneighbour/dotfiles/commit/683aa19a1e6fc45d1e07b9034b71a831de4110f3)), closes [#286](https://github.com/davidsneighbour/dotfiles/issues/286) [#287](https://github.com/davidsneighbour/dotfiles/issues/287) [#290](https://github.com/davidsneighbour/dotfiles/issues/290)

### Chore

* **session:** remove Kando pie menu and helper ([7849def](https://github.com/davidsneighbour/dotfiles/commit/7849def9702e968d3fd26c01bce0776680fb042e))

## [2.16.3](https://github.com/davidsneighbour/dotfiles/compare/v2.16.2...v2.16.3) (2026-09-30)

### Fix

* **msgvault:** show sync failures in polybar and ignore retired account ([cfe0b3e](https://github.com/davidsneighbour/dotfiles/commit/cfe0b3e9e999eab82cb3b32a9b5a9c5a48e20be5))

## [2.16.2](https://github.com/davidsneighbour/dotfiles/compare/v2.16.1...v2.16.2) (2026-09-29)

### Fix

* **msgvault:** keep synch terminal in the top left ([7baffab](https://github.com/davidsneighbour/dotfiles/commit/7baffab53c373101d5ac285758d2728e9a82ed75))

## [2.16.1](https://github.com/davidsneighbour/dotfiles/compare/v2.16.0...v2.16.1) (2026-09-29)

### Fix

* **clockify:** stop exposing stack trace data in form error responses ([32e45db](https://github.com/davidsneighbour/dotfiles/commit/32e45dbbc8d5cdc01ba2051eca78ba377a8d537d)), closes [#7](https://github.com/davidsneighbour/dotfiles/issues/7)

## [2.16.0](https://github.com/davidsneighbour/dotfiles/compare/v2.15.1...v2.16.0) (2026-09-28)

### Feat

* **i3:** start programs from the launcher on a new workspace ([8fc98e2](https://github.com/davidsneighbour/dotfiles/commit/8fc98e2c5a41987382e95a19f3d90247dedbfec5))
* **session:** manage notification daemon config with dotbot ([7edb17c](https://github.com/davidsneighbour/dotfiles/commit/7edb17c6731fd7356657a098c4ca82e1f8e7f877))

### Fix

* **gdrive:** fix re-authentication process for gdrive ([8248ad4](https://github.com/davidsneighbour/dotfiles/commit/8248ad4b497ee8e428e34904c455daf376975bb5))
* remove conky setup ([275e47b](https://github.com/davidsneighbour/dotfiles/commit/275e47b2d15bf150f7d26583e4979a031d6d1a97))
* **rofi:** header image sizing for all dialogues ([7d8b906](https://github.com/davidsneighbour/dotfiles/commit/7d8b9063fa85480b7ff57d3c8429168f619ad698))
* **skillz:** adapt skillz to new skillwerk repo format ([e387f6d](https://github.com/davidsneighbour/dotfiles/commit/e387f6d1187d2a3716a95a33830be544c0c4e02e))
* use flatter aspect ratio for rofi menu header image ([21a9590](https://github.com/davidsneighbour/dotfiles/commit/21a959053efc6273fd3df98a924422b9b4001609))

### Docs

* **i3:** document notification daemon and remove terminal transparency ([56d7238](https://github.com/davidsneighbour/dotfiles/commit/56d7238993752a5793ceb5caee2dc42c504f971c))
* **i3:** remove compositor references ([fb81829](https://github.com/davidsneighbour/dotfiles/commit/fb8182966e4a0468a4009689c60fd83f942e50ce))

### Build

* **deps:** update dependencies ([45a2a14](https://github.com/davidsneighbour/dotfiles/commit/45a2a148b2ca97078e3105d574f4183a7f4d8fb6))
* **deps:** update dependencies ([5dbf2fc](https://github.com/davidsneighbour/dotfiles/commit/5dbf2fc964be9f12e97cc12e24d92c4dfdeac787))

### Chore

* **deps:** update dependency lucide-react to v1.48.0 ([#582](https://github.com/davidsneighbour/dotfiles/issues/582)) ([efcc6e9](https://github.com/davidsneighbour/dotfiles/commit/efcc6e9c9388bf0cc14bf4151bdaae4480f7c9eb))
* **thunar:** update accelerator map header written by thunar ([1c14b56](https://github.com/davidsneighbour/dotfiles/commit/1c14b560868fd92e02fd31500eb233ad53b8eb7c))

## [2.15.1](https://github.com/davidsneighbour/dotfiles/compare/v2.15.0...v2.15.1) (2026-09-24)

### Fix

* **msgvault:** float and centre manual-sync terminal ([0ddb0f3](https://github.com/davidsneighbour/dotfiles/commit/0ddb0f32789bbbd33d1bcb2a79c9b91a37040002))

## [2.15.0](https://github.com/davidsneighbour/dotfiles/compare/v2.14.1...v2.15.0) (2026-09-24)

### Feat

* **clockify:** add project/title typeahead, end-now button, and tag picker ([5b411ee](https://github.com/davidsneighbour/dotfiles/commit/5b411ee524f6598cc0591a2eb48eb83ca72da03e))
* **i3:** bind Ctrl+Space to trigger the Kando pie menu ([df83871](https://github.com/davidsneighbour/dotfiles/commit/df83871e37d0f5f43f2a956b0c12a873a1f3b6dd))

### Fix

* **i3:** quote the Kando exec payload correctly ([5dbeacb](https://github.com/davidsneighbour/dotfiles/commit/5dbeacbae325e2fdfe9a6624430a9cb790293733))
* **i3:** require Ctrl+Shift+Alt for program-launch bindings ([28359a3](https://github.com/davidsneighbour/dotfiles/commit/28359a30b496152ee6c3ebf5214127e29b62d976))
* **launchers:** consolidate launchers ([2e421f9](https://github.com/davidsneighbour/dotfiles/commit/2e421f973f75f7cb4de72f2eebfe41c7636dcf18))
* **msgvault:** export PATH in backup script for cron runs ([6da449d](https://github.com/davidsneighbour/dotfiles/commit/6da449dc35a5c8156d42acea17e1dcd36e6a3ef3))

### Build

* **deps:** update dependencies ([1a91dad](https://github.com/davidsneighbour/dotfiles/commit/1a91dad9dbd867586d3ad5a1e86fb94dad5b0db1))

## [2.14.1](https://github.com/davidsneighbour/dotfiles/compare/v2.14.0...v2.14.1) (2026-09-22)

### Fix

* **clockify:** stop leaking internal error details to form clients ([cf4cbae](https://github.com/davidsneighbour/dotfiles/commit/cf4cbae1721dc51548e7234fd63bb543894aa2ac)), references [#7](https://github.com/davidsneighbour/dotfiles/issues/7)

### Chore

* **deps:** add overrides to close npm vulnerability alerts ([d82a9be](https://github.com/davidsneighbour/dotfiles/commit/d82a9be6e908c2620d25d26ae497693eb2069b0f))
* **deps:** update dependency @types/node to v26.6.2 ([#581](https://github.com/davidsneighbour/dotfiles/issues/581)) ([74f0c4c](https://github.com/davidsneighbour/dotfiles/commit/74f0c4c947df0e133f5059b6c5240228c592830c))
* **deps:** update dependency playwright to v1.63.0 ([#572](https://github.com/davidsneighbour/dotfiles/issues/572)) ([d58acd8](https://github.com/davidsneighbour/dotfiles/commit/d58acd85283dc76645f7605933e30a5fe359c4dc))

## [2.14.0](https://github.com/davidsneighbour/dotfiles/compare/v2.13.0...v2.14.0) (2026-09-22)

### Feat

* **clockify:** add client and project management to the form and CLI ([1faac87](https://github.com/davidsneighbour/dotfiles/commit/1faac8708b32ac08ee996ce398324fc5ba5e1340))
* **msgvault:** back up every 3 hours, include config and tokens ([06d9b46](https://github.com/davidsneighbour/dotfiles/commit/06d9b46f12501f7e3b25566e5e49f6ad19d1c320))
* **tools:** add single-page unsplash downloader and untrack state ([dd8fc72](https://github.com/davidsneighbour/dotfiles/commit/dd8fc7280f56280b0cf7666ed8b2248889abdf9c))

### Fix

* **clockify:** exit form --restart immediately instead of blocking ([202f401](https://github.com/davidsneighbour/dotfiles/commit/202f401ea527965c2049a50cfca845c07c10dafc))
* **i3:** show VS Code workspace name instead of "code" in alt-tab switcher ([36a0525](https://github.com/davidsneighbour/dotfiles/commit/36a052534132e754eb51deba558f404d76fcd642))
* **i3:** use a darker red for alt-tab switcher window labels ([c4251fd](https://github.com/davidsneighbour/dotfiles/commit/c4251fd1685a7e53abd82fb31b48f02837a8fbe7))

### Refactor

* **msgvault:** drop script-level lock, daemon serializes now ([6b2e211](https://github.com/davidsneighbour/dotfiles/commit/6b2e211941b4c2c0932940ffe93a6fa2f8b96e3e))
* **msgvault:** move bashrc/helpers/msgvault to tools/msgvault ([32673a9](https://github.com/davidsneighbour/dotfiles/commit/32673a9267a57815dd05a88ac57036722f32c6f1))
* **msgvault:** retire dead rsync backup path, track backup duration ([2feff4f](https://github.com/davidsneighbour/dotfiles/commit/2feff4f1ecbb9f2370a0bee6101e208713734710))

### Chore

* cleanup launchers ([5eb8b47](https://github.com/davidsneighbour/dotfiles/commit/5eb8b4788a16aad7f027d7858290d7519ef115d6))

## [2.13.0](https://github.com/davidsneighbour/dotfiles/compare/v2.12.0...v2.13.0) (2026-09-16)

### Feat

* **clockify:** add a --restart flag to the local form server ([4c3dca3](https://github.com/davidsneighbour/dotfiles/commit/4c3dca3a7f1147669a1dffb5c4ef58f43ac97b36)), closes [#578](https://github.com/davidsneighbour/dotfiles/issues/578)
* **clockify:** add quick-fill start date links to the local form ([1605c6e](https://github.com/davidsneighbour/dotfiles/commit/1605c6e04d169f0bede8c70501451f0d16a12a9b)), closes [#579](https://github.com/davidsneighbour/dotfiles/issues/579)
* **clockify:** check the running timer eagerly when the form server starts ([f40db3a](https://github.com/davidsneighbour/dotfiles/commit/f40db3a7e1e04013609c6a9faca927ce51a67e52))
* **clockify:** rebuild local form with shadcn/ui and a Dracula dark theme ([cb9ecdf](https://github.com/davidsneighbour/dotfiles/commit/cb9ecdfc7c3f40933aba0ead636133d500a3e61a)), closes [#576](https://github.com/davidsneighbour/dotfiles/issues/576)
* **clockify:** right-click Polybar icon opens the Clockify tracker overview ([b3e263a](https://github.com/davidsneighbour/dotfiles/commit/b3e263ad74cb2c74e60802dbe598cdba70e1b80c)), closes [#580](https://github.com/davidsneighbour/dotfiles/issues/580)
* **clockify:** tag entries opened or closed via the form with via:form ([ff7c1dc](https://github.com/davidsneighbour/dotfiles/commit/ff7c1dc6ffb4c82660c908181e625c291ca0804d))

### Fix

* **clockify:** add a close button to the local form ([66bad1a](https://github.com/davidsneighbour/dotfiles/commit/66bad1a96695b3f0362a92736ff092330cc01247)), closes [#575](https://github.com/davidsneighbour/dotfiles/issues/575)
* **clockify:** escape inline JSON in the local form page ([60af727](https://github.com/davidsneighbour/dotfiles/commit/60af727f758f575b980ce963cc3fa2b21fab995a))
* **clockify:** lay out start and end date fields 50/50 in the local form ([8f8f953](https://github.com/davidsneighbour/dotfiles/commit/8f8f95372ee755ef93f5b03e84728e37aab53cf0)), closes [#577](https://github.com/davidsneighbour/dotfiles/issues/577)
* **clockify:** sync polybar-clockify colours with the Dracula Pro palette ([0a27293](https://github.com/davidsneighbour/dotfiles/commit/0a272938fb4330d8985ff9903a3252dd24415ba1)), closes [#574](https://github.com/davidsneighbour/dotfiles/issues/574)
* remove stray scratch file ([b3daae1](https://github.com/davidsneighbour/dotfiles/commit/b3daae1e5476632447e4ccbebe4fc0286d68df2a))
* **rofi:** share one theme between the power menu and other rofi surfaces ([1047b29](https://github.com/davidsneighbour/dotfiles/commit/1047b295efe7bc6600c9d32f3e6284e366b516a5)), references [window/#mainbox](https://github.com/davidsneighbour/dotfiles/issues/mainbox) [#header](https://github.com/davidsneighbour/dotfiles/issues/header)

### Build

* **vscode:** update workspace colour-set ([90b9430](https://github.com/davidsneighbour/dotfiles/commit/90b9430ead1c71f5eaf7ce50dbcc66bf2c8ab03f))

### Chore

* **clockify:** remove PLAN.md handoff doc ([e2ec57d](https://github.com/davidsneighbour/dotfiles/commit/e2ec57d5a8bbe82564ce5e55894b4599d5dcd647))

## [2.12.0](https://github.com/davidsneighbour/dotfiles/compare/v2.11.1...v2.12.0) (2026-09-15)

### Feat

* **applications:** add Hermes desktop launcher ([16db422](https://github.com/davidsneighbour/dotfiles/commit/16db422c19b46cfed7d023ff71d614b26748cf85))
* **clockify:** add workstation tracking integration ([7c99a64](https://github.com/davidsneighbour/dotfiles/commit/7c99a64c5ac55fdedd8689dd17865852018b00d3))
* **i3:** promote the focused window to a temporary icon workspace ([7f23223](https://github.com/davidsneighbour/dotfiles/commit/7f23223cece2ab0e686ee013ef70e7668a920738))

### Fix

* **clockify:** reset nudge counter on status cache clear ([e9f00e1](https://github.com/davidsneighbour/dotfiles/commit/e9f00e171dde58a3cbedd91d6ece281e1659c15d))
* **clockify:** show explicit saved state and force-close the form window ([fb3ca4c](https://github.com/davidsneighbour/dotfiles/commit/fb3ca4c19362e4733cd249ddd6e510b8a779ac29))

### Docs

* **clockify:** mention nudge counter reset on form submit ([0d60043](https://github.com/davidsneighbour/dotfiles/commit/0d6004310654e6dda9b18ee8d30b9c3ca1c00c3b))
* **fonts:** add font comparison specimen pages ([e48e4a0](https://github.com/davidsneighbour/dotfiles/commit/e48e4a09eb82394d314630496132d27e26f9853a))

### Chore

* **codex:** add MCP Docs and Netlify MCP servers ([a291fbf](https://github.com/davidsneighbour/dotfiles/commit/a291fbf681805d60ef351531a776c9cb5de4cc0a))
* **thunar:** normalize accelerator map header casing ([c2c8c99](https://github.com/davidsneighbour/dotfiles/commit/c2c8c99f9403b8fb22e92248884e7fe6d9ea3a47))

## [2.11.1](https://github.com/davidsneighbour/dotfiles/compare/v2.11.0...v2.11.1) (2026-09-12)

### Fix

* **fonts:** move session fonts into session directory ([4a2f22f](https://github.com/davidsneighbour/dotfiles/commit/4a2f22f6f9bb56fa60fcb8d2504ae59067200e26))
* **rofi:** switch rofi font to Monaspace ([7548fe3](https://github.com/davidsneighbour/dotfiles/commit/7548fe3282fb55a9806c1f8a6a87a4323629a59b))

## [2.11.0](https://github.com/davidsneighbour/dotfiles/compare/v2.10.0...v2.11.0) (2026-09-12)

### Feat

* add font system ([0d1e8bd](https://github.com/davidsneighbour/dotfiles/commit/0d1e8bdfb2b9614896392f8566de10a6feac037f))
* add launchers to session setup and set up launchers splitting ([47e23fb](https://github.com/davidsneighbour/dotfiles/commit/47e23fb354586faf52e03659fc2cf594351bea6e))
* **i3:** allow target-less dynamic workspace launches ([ce27c45](https://github.com/davidsneighbour/dotfiles/commit/ce27c4510b3dd8eaf63f8fce9d2c486df8eb9a8a))
* **session:** apply settled typography to i3, rofi, and polybar ([ad7d8f4](https://github.com/davidsneighbour/dotfiles/commit/ad7d8f4694eb40801959f9e7e7b6b5479e425062))
* **terminal:** add persistent i3 scratchpad terminal ([d0d0ed2](https://github.com/davidsneighbour/dotfiles/commit/d0d0ed24ad22ba5d1c466395807f50ec3e981596))
* **thunar:** add config to sessions setup ([a29d890](https://github.com/davidsneighbour/dotfiles/commit/a29d890517104450a0f373263f630d19ebf53c23))

### Fix

* **barrier:** move barrier configuration into session setup ([a9e82ce](https://github.com/davidsneighbour/dotfiles/commit/a9e82cee4e161bfabcaf4577c0b7879d5eeb6bd3))
* **i3:** hide scratchpad windows from the alt-tab rofi switcher ([4860074](https://github.com/davidsneighbour/dotfiles/commit/4860074f8ccd8b55f99c1acd367de0df3f283bbf))
* **i3:** update lock session to restart polybar after sleep ([2a0ee3f](https://github.com/davidsneighbour/dotfiles/commit/2a0ee3f4eaf8df830dfddc66095cf77b126d603f))
* **thunar:** capitalise Thunar in accelerator map header comment ([212f0a5](https://github.com/davidsneighbour/dotfiles/commit/212f0a5b1fdf23c80c29382dcdf0a4ede696ecc9))

### Docs

* **fix:** update font instructions ([e503984](https://github.com/davidsneighbour/dotfiles/commit/e50398417ea52a1e8b0e4f7442598da8e15d6003))

### Build

* **vscode:** add mcp configuration for codex ([62c65f7](https://github.com/davidsneighbour/dotfiles/commit/62c65f744e5b425c3e9e6adb92aa30035e974d95))

### Chore

* **repository-updates:** drop stale Wonderland GitLab repos ([68d9f47](https://github.com/davidsneighbour/dotfiles/commit/68d9f47866e163fb2b1f2bfe3c1bb22a15de94c9))

## [2.10.0](https://github.com/davidsneighbour/dotfiles/compare/v2.9.0...v2.10.0) (2026-09-09)

### Feat

* **filemanager:** add canonical two-pane Thunar workspace for i3 ([f6d9d07](https://github.com/davidsneighbour/dotfiles/commit/f6d9d077508bde4aa3b8aeda748d190d76af06bb))

### Fix

* **filemanager:** fix i3 exec syntax for Ctrl+Shift+Alt+F binding ([1924ac0](https://github.com/davidsneighbour/dotfiles/commit/1924ac0481f639c2c7e5660781f9f6f23e090d1b))
* **filemanager:** stop i3_cmd warnings leaking into captured con ids ([71c5169](https://github.com/davidsneighbour/dotfiles/commit/71c5169e887650614172476df39d6b965cc3c877))

### Docs

* **ai:** restructure agent instructions and fix markdownlint repo-wide ([9e21cc5](https://github.com/davidsneighbour/dotfiles/commit/9e21cc5526b73007ae6e4ace00a332fd591a9871))
* **i3:** add instructions for verifying i3 keybindings/workspace commands ([668b42a](https://github.com/davidsneighbour/dotfiles/commit/668b42a20a9d2bf1c9bd8c855ce1370a8dee0e82))

### Chore

* update unsplash plus collection data ([88f432c](https://github.com/davidsneighbour/dotfiles/commit/88f432cd50fa972459106fc99a949424d73ef78e))

## [2.9.0](https://github.com/davidsneighbour/dotfiles/compare/v2.8.0...v2.9.0) (2026-09-09)

### Feat

* **bash:** add wrapper to change background color in ssh command ([83c8356](https://github.com/davidsneighbour/dotfiles/commit/83c83564657f2e70975ae3fe8da0dd31749fb532))
* **dotbot:** add Node updater to host profiles ([f8d5848](https://github.com/davidsneighbour/dotfiles/commit/f8d58482959ae8b4b4a946072760a5bc70364513))
* **dotbot:** schedule weekly Node current update ([e4885c9](https://github.com/davidsneighbour/dotfiles/commit/e4885c91e10727ee97e2ec024bf74431dcf5e507))
* **storage:** add gdrive mounts via ocamlfuse ([7c5f2f8](https://github.com/davidsneighbour/dotfiles/commit/7c5f2f8231bf09f08567d1f8ed4230dbbfa9fcc5))
* **terminator:** configuration added ([2e389de](https://github.com/davidsneighbour/dotfiles/commit/2e389deeecff54310cf5c33636b5c16ab6a9dbcc))

### Fix

* **rofi:** update header image ([33adeac](https://github.com/davidsneighbour/dotfiles/commit/33adeac7b7ccd70d1aa01a0298751b4f2735d2b1))
* **storage:** add gdrive mounts to session start ([623addd](https://github.com/davidsneighbour/dotfiles/commit/623adddfa6470c7373e5058d3990fa2209bc5a3a))
* **terminator:** add dotbot mount ([f5312fe](https://github.com/davidsneighbour/dotfiles/commit/f5312fe32beea8be86c3631ff4415c53b0c8832d))

### Build

* **vscode:** update workspace configuration ([954ec4c](https://github.com/davidsneighbour/dotfiles/commit/954ec4cbeaf983394ccf6e3ae680b507ac46151e))

## [2.8.0](https://github.com/davidsneighbour/dotfiles/compare/v2.7.1...v2.8.0) (2026-09-09)

### Feat

* add argon one config ([f7cee1b](https://github.com/davidsneighbour/dotfiles/commit/f7cee1b014bd83a310c1c983c5e92f3cd330db78))
* **git:** symlink gh CLI config via dotbot ([d552cac](https://github.com/davidsneighbour/dotfiles/commit/d552cac46a2654a5b7107d0337c96af648bf138a))
* **rofi:** unify rounded header-image design across rofi surfaces ([3d70277](https://github.com/davidsneighbour/dotfiles/commit/3d70277d65bba80e0d721d9baedf3bd1b7a52574))

### Fix

* add check for requirements and fix README.md in argon one config ([9c676ac](https://github.com/davidsneighbour/dotfiles/commit/9c676ac50a6124149b24f644cc61f82bb8a418af))
* generate skill dotbot config in cache ([f1c0206](https://github.com/davidsneighbour/dotfiles/commit/f1c0206ba9ab879d089ad4c3fddcde4331980e11))
* restart polybar after i3lock ([46197fe](https://github.com/davidsneighbour/dotfiles/commit/46197fe6372281e7ddd76d0af3c014ef762e644e))

### Build

* **deps:** update dependencies ([e18cf11](https://github.com/davidsneighbour/dotfiles/commit/e18cf112c2ef7c7b45395ab8bb5e8fa2048d6412))
* **vscode:** remove eslint extensions from recommendations ([2fa8a77](https://github.com/davidsneighbour/dotfiles/commit/2fa8a77a54a6783e3212dc1a62504234dbd9ca94))

## [2.7.1](https://github.com/davidsneighbour/dotfiles/compare/v2.7.0...v2.7.1) (2026-09-05)

### Fix

* **polybar:** order in pulseaudio module ([961a62e](https://github.com/davidsneighbour/dotfiles/commit/961a62e9711f175c6accdd7dede3908abbc1b407))

## [2.7.0](https://github.com/davidsneighbour/dotfiles/compare/v2.6.0...v2.7.0) (2026-09-04)

### Feat

* add LightDM greeter configuration and background image ([9c90354](https://github.com/davidsneighbour/dotfiles/commit/9c903547b22e7c2f9fecce26272f3126b203615b))

## [2.6.0](https://github.com/davidsneighbour/dotfiles/compare/v2.5.1...v2.6.0) (2026-09-04)

### Feat

* add window inspector tool for i3 window-rule discovery ([443db2f](https://github.com/davidsneighbour/dotfiles/commit/443db2f3ab637f68d0000c6b3c962d986791b844))
* run Enpass in the i3 scratchpad instead of a normal workspace ([32369ff](https://github.com/davidsneighbour/dotfiles/commit/32369ffaf63bda6395448d26479f29303e141337))

### Fix

* add rules and desktop comments to i3 config ([97f635f](https://github.com/davidsneighbour/dotfiles/commit/97f635f2f88ec07aad76e52cd6173364c5a44f0d))
* resort polybar layout ([b905aec](https://github.com/davidsneighbour/dotfiles/commit/b905aec836bfa9f951b1aa65570dd6eb18d18bf2))

### Refactor

* comments in rules.conf ([108e9af](https://github.com/davidsneighbour/dotfiles/commit/108e9af3dbea0987023b4c9d9297b4fbb1f6d84c))

### Chore

* remove accidental polybar module file ([a3dfcc1](https://github.com/davidsneighbour/dotfiles/commit/a3dfcc1ea687e49d4af56e744be3f2252c772ef2))
* resize window-inspector floating window to 700x540 ([5ed3cb5](https://github.com/davidsneighbour/dotfiles/commit/5ed3cb5cf18baf77be65887feb7a548a868fac01))

## [2.5.1](https://github.com/davidsneighbour/dotfiles/compare/v2.5.0...v2.5.1) (2026-09-04)

### Build

* **fix:** update release configuration ([7feabdf](https://github.com/davidsneighbour/dotfiles/commit/7feabdf236eb4549a01f9ea12398839e0f6ef267))

## [2.5.0](https://github.com/davidsneighbour/dotfiles/compare/v2.4.1...v2.5.0) (2026-09-04)

### Feat

* **session:** support project workspace icons ([4b47305](https://github.com/davidsneighbour/dotfiles/commit/4b473057dd55dde3a2193425e5bb190c844b7a09))

### Instructions

* mark XFCE as legacy session ([c0fd1a9](https://github.com/davidsneighbour/dotfiles/commit/c0fd1a9338b229259c98d6ae80fdce7b10d49c8e))

### Chore

* remove protected submodule ([50820ef](https://github.com/davidsneighbour/dotfiles/commit/50820effad7c2fb62dbc8bef3e308305c4c7fdcd))

## [2.4.1](https://github.com/davidsneighbour/dotfiles/compare/v2.4.0...v2.4.1) (2026-09-04)

### Config

* **i3:** move workspace config under i3 ([f823f6d](https://github.com/davidsneighbour/dotfiles/commit/f823f6df0fe210ac077090aeb24e2c0370548ccc))

## [2.4.0](https://github.com/davidsneighbour/dotfiles/compare/v2.3.1...v2.4.0) (2026-09-04)

### Feat

* **session:** add dynamic i3 workspaces ([3c3939c](https://github.com/davidsneighbour/dotfiles/commit/3c3939c91600217e19f83531691a1536c31c8058))
* **session:** use icon workspace labels ([4ba73ec](https://github.com/davidsneighbour/dotfiles/commit/4ba73ecdfa182772d535806612e9826e1879b7f6))

### Fix

* remove dnbhq skills directory from skillz ([17dcd48](https://github.com/davidsneighbour/dotfiles/commit/17dcd48cd05bf0f496cae6239dc548572b1a6b24))
* remove vale configuration ([041eced](https://github.com/davidsneighbour/dotfiles/commit/041ecedf0d2f7aeebe88fd449c6b01d4db0998f0))

### Build

* **deps-dev:** bump cspell from 10.0.1 to 10.1.1 ([#568](https://github.com/davidsneighbour/dotfiles/issues/568)) ([247d1ca](https://github.com/davidsneighbour/dotfiles/commit/247d1cabd9dc590c061d29dac546df3c50ce3e08))
* **deps-dev:** bump npm-check-updates from 23.0.2 to 23.1.0 ([#569](https://github.com/davidsneighbour/dotfiles/issues/569)) ([e13fc8e](https://github.com/davidsneighbour/dotfiles/commit/e13fc8e556ecc401abae0e9cd5b58f234f4d966f))

## [2.3.1](https://github.com/davidsneighbour/dotfiles/compare/v2.3.0...v2.3.1) (2026-09-02)

### Fix

* **i3:** correct Dracula background colour and start xfsettingsd ([39700a7](https://github.com/davidsneighbour/dotfiles/commit/39700a7b47a08a6169d89c46b62d5abe220b34b9))
* remove actions helper and its config ([1ac1505](https://github.com/davidsneighbour/dotfiles/commit/1ac150552539aa18ae37666bcc14012dfb67d36a))
* remove bashrc/helpers/theme wallpaper scripts ([1c0cee8](https://github.com/davidsneighbour/dotfiles/commit/1c0cee89fb9438b40f02a028375e2116fcf7da24))
* remove color-steps theme script ([ad542b1](https://github.com/davidsneighbour/dotfiles/commit/ad542b103790e69d089db327072e78e142202e5a))
* remove package helper and config ([0620cf0](https://github.com/davidsneighbour/dotfiles/commit/0620cf0555bfb67cd2dc0658093290378a7d045c))
* remove tabdump extension into separate repo ([58550de](https://github.com/davidsneighbour/dotfiles/commit/58550deba2c47afbf4f8528241cb87d8bd11d36a))
* remove unused dnb-dotfiles-tools VS Code extension ([7eb0f51](https://github.com/davidsneighbour/dotfiles/commit/7eb0f51b818cb1b19a84140b960ee43c3ac17d2b))
* remove unused nanny setup ([ea140fa](https://github.com/davidsneighbour/dotfiles/commit/ea140fa736ed8964d71108b5b0bdfcad9e5daa04))
* start barrier server only once at the session start ([4b6e696](https://github.com/davidsneighbour/dotfiles/commit/4b6e696fd546f87443179cacb000c9b764a1028e))
* **theme:** background image ([662a56f](https://github.com/davidsneighbour/dotfiles/commit/662a56ffff005dcc0a1b14d55655b69d53be8a6e))

### Refactor

* **autostart:** remove XDG autostart pool and its actions.sh commands ([7aef239](https://github.com/davidsneighbour/dotfiles/commit/7aef2391071cae99630a3d183002474796a03d5b))
* **devilspie2:** remove Devilspie2 setup ([3f2652e](https://github.com/davidsneighbour/dotfiles/commit/3f2652e990a0e859432e61d470e0be73b296c6a6))
* **i3:** remove legacy workspace helpers ([e44253c](https://github.com/davidsneighbour/dotfiles/commit/e44253c3459f6b4914f591849a718f5ea4dcb796))
* **rofi:** make Rofi i3-only, wire Alt+Tab window switcher ([7ec4a9b](https://github.com/davidsneighbour/dotfiles/commit/7ec4a9bb78217700700b505cee1e5c4aa30451b6))
* **xfce:** remove dotfiles-managed XFCE xfconf settings ([f4d9c05](https://github.com/davidsneighbour/dotfiles/commit/f4d9c0502b856fdcfe3382b1a465079f1ea66cc3))

### Build

* **deps:** update dependencies ([917983d](https://github.com/davidsneighbour/dotfiles/commit/917983d51f4039f1b392ed3cf996014cc4b8e91a))

## [2.3.0](https://github.com/davidsneighbour/dotfiles/compare/v2.2.1...v2.3.0) (2026-09-02)

### Feat

* **containers:** add changedetection.io container ([4211358](https://github.com/davidsneighbour/dotfiles/commit/42113585a8021659d94550ca14373786ae7fc55c))

### Fix

* **i3:** update i3 and i3lock to dracula theme ([eb969b7](https://github.com/davidsneighbour/dotfiles/commit/eb969b7303edb8cb9ac2dbbbf3d112954a2db6d8))

## [2.2.1](https://github.com/davidsneighbour/dotfiles/compare/v2.2.0...v2.2.1) (2026-09-01)

### Fix

* remove polybar symlink from dotbot config ([043798b](https://github.com/davidsneighbour/dotfiles/commit/043798bd16a64bdd266ec029c40def22b748ec6e))

## [2.2.0](https://github.com/davidsneighbour/dotfiles/compare/v2.1.0...v2.2.0) (2026-09-01)

### Feat

* **session:** add VS Code workspace picker keybinding and set wallpaper on start ([7b08d77](https://github.com/davidsneighbour/dotfiles/commit/7b08d7743e61979a14ffca267f172ff49b974c0d))

### Fix

* add bin directory to path ([3abf4ea](https://github.com/davidsneighbour/dotfiles/commit/3abf4ea4591d09b4f30f2577aa9120efe21cdc89))

### Docs

* **ai:** update instructions to create completion file for any particle in _functions ([f0bbc11](https://github.com/davidsneighbour/dotfiles/commit/f0bbc11c4664f3237cf7c26168927a761a213aca))

### Chore

* remove savefiles ([4321f02](https://github.com/davidsneighbour/dotfiles/commit/4321f02c465946de6881650984cbb7b2f134a0d5))

## [2.1.0](https://github.com/davidsneighbour/dotfiles/compare/v2.0.0...v2.1.0) (2026-09-01)

### Feat

* **polybar:** add camera/mic privacy indicator script ([c8745b4](https://github.com/davidsneighbour/dotfiles/commit/c8745b4e15707531fb1ae06d8a09c11584ee16e8))
* **session:** split i3 config into includes and lock the screen via xss-lock ([a397592](https://github.com/davidsneighbour/dotfiles/commit/a39759274e91320380ec4700b3669e38c8dc1305))

### Fix

* add keystore startup registration to i3 session ([253185e](https://github.com/davidsneighbour/dotfiles/commit/253185e5dc4b506a1f0ccfc0764ce6ba9090dd37))
* **launchers:** register Chrome as a handler for about: and unknown scheme links ([da8f7a4](https://github.com/davidsneighbour/dotfiles/commit/da8f7a4985a68b6294d4de228d92048c30dbc944))
* **rofi:** adapt power menu image to 2:1 aspect ratio ([43e8d07](https://github.com/davidsneighbour/dotfiles/commit/43e8d0766422c751f25356ef7075fd67b0012109))
* **rofi:** remove obsolete theme image ([6107667](https://github.com/davidsneighbour/dotfiles/commit/6107667872074e684bab2458a5a97b61968ddc78))
* **session:** make the polybar power menu and Enpass work under i3 ([606f1c3](https://github.com/davidsneighbour/dotfiles/commit/606f1c384637cd1325dd04a426e6588cd6fb7081))
* **session:** route i3 exit through the Rofi power menu ([fc8cd14](https://github.com/davidsneighbour/dotfiles/commit/fc8cd1477b6886a8753e5566750d5fa152ffd75b))

### Docs

* **ai:** add CLAUDE.md pointing to AGENTS.md ([f7afe43](https://github.com/davidsneighbour/dotfiles/commit/f7afe433a5f82e574beffef05b28acd7fab450bd))
* silence markdownlint title-case-style on the MIT License heading ([182f8d4](https://github.com/davidsneighbour/dotfiles/commit/182f8d487fde688c859c2dcf3ece5cd0c80aa29c))

### Style

* **polybar:** remove module padding for icon-only labels ([c4767c5](https://github.com/davidsneighbour/dotfiles/commit/c4767c5c2d01c019e41d12bba53e9f99cbd42c0e))
* **polybar:** switch status modules to icon-only labels ([6734b5f](https://github.com/davidsneighbour/dotfiles/commit/6734b5f8385ebaa1ec7cb49f87dec3e50cdbbe33))

### Chore

* move out old polybar configuration ([ce81da3](https://github.com/davidsneighbour/dotfiles/commit/ce81da39264a71a2d7350c9d6908541e67dec1f4))

## [2.0.0](https://github.com/davidsneighbour/dotfiles/compare/v1.0.0...v2.0.0) (2026-08-31)

### Feat

* **session:** add i3 starter desktop session ([4437d77](https://github.com/davidsneighbour/dotfiles/commit/4437d776c9a72141dacef246a835d9e2d3fcd7cc)), closes [#567](https://github.com/davidsneighbour/dotfiles/issues/567)

### Fix

* **session:** close i3 rework gaps against the original spec ([02bdecf](https://github.com/davidsneighbour/dotfiles/commit/02bdecffbd5042d7725efa45f3942fb6084de44c)), references [#567](https://github.com/davidsneighbour/dotfiles/issues/567)

### Docs

* **fix:** update repo theme image ([2c5d213](https://github.com/davidsneighbour/dotfiles/commit/2c5d21370152493a6a4d8b7c7bbba388bf69d5d7))

## Older releases

Releases before 2.0.0 (versions 2024.x, 2025.x, and 3000.x to 3004.x) were removed from this file. The full history is in [CHANGELOG.md at commit 6fe676e](https://github.com/davidsneighbour/dotfiles/blob/6fe676e1822d/CHANGELOG.md).
