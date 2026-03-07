# Hugo + PaperMod Website

Production-ready Hugo project using the [PaperMod theme](https://github.com/adityatelange/hugo-PaperMod), configured for multilingual content (`en` default, `id` optional) and automatic GitHub Pages deployment.

## Project Setup

This project is a standard Hugo site with:
- Hugo configuration in YAML (`hugo.yaml`)
- YAML front matter defaults via `archetypes/default.md`
- PaperMod theme installed as a Git submodule at `themes/PaperMod`
- English (`en`) as default language
- Indonesian (`id`) enabled for multilingual posts
- Dark mode as the default theme appearance

## Local Installation

1. Clone with submodules:

```bash
git clone --recurse-submodules <your-repo-url>
cd <your-repo-folder>
```

2. If you already cloned without submodules:

```bash
git submodule update --init --recursive
```

3. Ensure Hugo Extended is installed:

```bash
hugo version
```

Use Hugo Extended (recommended to match CI workflow).

## Run Locally

```bash
hugo server -D
```

Open `http://localhost:1313`.

## Create New Posts

### Option A: Hugo commands

```bash
hugo new content/posts/my-post.en.md
hugo new content/posts/my-post.id.md
```

### Option B: Helper script (creates both language files)

```bash
./scripts/new-post.sh my-post
```

Then edit the generated files under `content/posts/`.

## Multilingual Content (`en` and `id`)

- English is default (`defaultContentLanguage: en`), so default URLs are rooted at `/`.
- Indonesian content is served under `/id/`.
- Pair translated posts using the same `translationKey` in front matter.
- Use filename suffixes for language variants:
  - `post-name.en.md`
  - `post-name.id.md`

Example files are included:
- `content/posts/hello-world.en.md`
- `content/posts/hello-world.id.md`

## PaperMod Theme via Git Submodule

Theme is tracked as a submodule (recommended):

```bash
git submodule add https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod
```

When updating the theme:

```bash
git submodule update --remote --merge
git add themes/PaperMod
git commit -m "chore(theme): update PaperMod"
```

## Enabled PaperMod Settings

In `hugo.yaml`:
- `params.defaultTheme: dark` sets dark mode as default.
- `params.disableThemeToggle: false` keeps user toggle available.
- `ShowReadingTime`, `ShowPostNavLinks`, `ShowBreadCrumbs`, `ShowCodeCopyButtons`, `ShowWordCount` improve post UX.
- `outputs.home` includes `JSON`, useful for search/index features in PaperMod.

## GitHub Pages Auto Deployment (GitHub Actions)

Workflow file: `.github/workflows/deploy.yml`

Behavior:
- Triggers on every push to `main` and manual runs (`workflow_dispatch`).
- Checks out repository with submodules (`submodules: recursive`).
- Builds the site with Hugo.
- Publishes `public/` to GitHub Pages via official Pages actions.

### One-time GitHub repository settings

1. Push this project to GitHub.
2. In **Settings -> Pages**, set **Source** to **GitHub Actions**.
3. Ensure your default branch is `main`.

After that, each push to `main` (including new posts/content edits) automatically rebuilds and deploys the site.

## Useful Commands

```bash
# Build production output locally
hugo --gc --minify

# Create a draft post
hugo new content/posts/example.en.md

# Initialize/update submodules
git submodule update --init --recursive
```
