---
layout: default
title: Publish GitHub Pages
parent: How-to guides
nav_order: 4
---

# Publish GitHub Pages

Use this guide to publish the documentation from the repository's `docs` folder.
You need permission to change the repository's Pages settings.
The site uses the same Just the Docs theme and section structure as
[AI Prepare Commit Message](https://github.com/electrocucaracha/ai-prepare-commit-msg/tree/main/docs).

## 1. Review The Site Configuration

`docs/_config.yml` defines the title, theme, search, code-copy buttons,
and repository link.
The canonical site settings are:

```yaml
url: https://electrocucaracha.github.io
baseurl: /infra-lab
```

For a fork, change `url` to the owner's Pages origin
and `baseurl` to the repository path.
Update the repository link under `aux_links` too.
Keep `jekyll-remote-theme` and `jekyll-relative-links` enabled
so the theme loads and local Markdown links resolve to rendered pages.

## 2. Select The Publishing Source

1. Publish the documentation changes to the branch you want GitHub Pages to build.
2. Open the repository's **Settings**, then **Pages**.
3. Under **Build and deployment**, select **Deploy from a branch**.
4. Choose the branch containing the documentation and the `/docs` folder.
5. Save the settings and inspect the Pages build in the **Actions** tab.

This setup uses GitHub's branch-based Jekyll build.
It does not require a separate deployment workflow in this repository.
If your organization restricts Pages publishing, follow its repository policy.

## 3. Verify The Published Site

Open the address reported by the successful Pages deployment.
For this repository, the expected address is:

<https://electrocucaracha.github.io/infra-lab/>

Confirm the sidebar shows Home, Tutorials, How-to guides, Reference, and Explanations.
Open a child page from each section,
check a cross-link,
and search for `TopoLVM`.

## Maintain Navigation

Each page has YAML front matter containing `layout`, `title`, and `nav_order`.
Section index pages use `has_children: true`.
Child pages set `parent` to the exact section title.
Keep navigation at two levels and link new pages from their section index.

Use semantic line breaks in prose and keep commands grounded in the current scripts.
See the [documentation home](../index.md) for the content map.
