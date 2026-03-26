# FreshRSS Setup && Tailwind Theme Development

## Quick Docker usage

Start FreshRSS:

```bash
docker compose up -d
```

Stop FreshRSS:

```bash
docker compose down
```

Update images:

```bash
docker compose pull
docker compose up -d
```

Logs (optional):

```bash
docker compose logs -f
```

## Project structure

```text
freshrss/
├── config/              # mounted into container (FreshRSS config)
├── freshrss-theme/      # Tailwind-based theme (mounted, https://github.com/davidsneighbour/freshrss-theme)
├── FreshRSS/            # cloned FreshRSS repo (reference only, https://github.com/FreshRSS/FreshRSS)
```

## Theme development workflow

* The theme is developed in `freshrss-theme/`
* Tailwind runs locally and builds CSS into the theme directory
* Docker only consumes the compiled output
* In case of changes not being loaded in FreshRSS - "Did you reboot the container?"

Flow:

```text
src/css → Tailwind build → base.css → Docker → FreshRSS UI
```

## Tailwind build commands

Run inside `freshrss-theme/`:

Install dependencies:

```bash
npm install
```

Build once:

```bash
npm run build:css
```

Watch mode:

```bash
npm run watch:css
```

Stylelint (optional cleanup):

```bash
npm run lint:css
npm run lint:css:fix
```

## Tailwind integration approach

FreshRSS themes are not designed for utility-first HTML usage. Therefore:

* You **do not** sprinkle Tailwind classes into PHP templates
* You **do not** modify core FreshRSS templates

Instead, use:

* `@apply` inside your CSS to compose utilities into existing selectors

Example:

```css
.item {
  @apply flex items-center gap-2 p-2;
}
```

This keeps:

* compatibility with upstream FreshRSS
* clean separation between structure (PHP) and styling (CSS)

## Content scanning

Tailwind scans:

* your theme files (`dnb-theme/`)
* the cloned FreshRSS repo (`freshrss-repo/`)

This allows:

* awareness of existing markup
* better utility generation coverage

## Important notes

### Theme is a copy, not the runtime source

Your theme is based on files copied from the FreshRSS repository.

This means:

* upstream changes are **not automatically reflected**
* your theme can drift from the current FreshRSS version

### Keep reference repo updated

Regularly update your reference:

```bash
cd freshrss-repo
git pull
```

Then:

* review changes in `p/themes/base-theme`
* selectively update your theme if needed

### Do not edit container files

Avoid:

* editing files inside Docker
* copying files from running containers

Always:

* work locally
* rebuild via Tailwind
* let Docker consume mounted files

### Tailwind limitations

Because templates are not Tailwind-driven:

* Tailwind cannot infer all classes automatically
* you may need:

  * `@apply`
  * a safelist file
  * explicit utility usage in CSS
