# Cloudflare Pages deployment

GitHub Actions builds Hugo with the locked Nix devenv, then uploads `public/`
to Cloudflare Pages. Cloudflare does not run the build. The workflow checks out
the website and Obsidian side by side, keeping the existing content mounts and
the Obsidian `obsidian-publish` dispatch.

The account is `8a253dc844b35e546f5c0a8ef2f0e89f`. The Direct Upload project
defaults to `phuchoang2603`; the workflow creates it on its first run if needed.
Optional Actions variables `CLOUDFLARE_ACCOUNT_ID` and
`CLOUDFLARE_PAGES_PROJECT` override those defaults.

## Credentials

Save a Cloudflare API token as the website repository's Actions secret
`CLOUDFLARE_API_TOKEN`. Give it **Account → Cloudflare Pages → Edit**, scoped to
this account. R2 S3 access keys cannot deploy Pages. The existing
`OBSIDIAN_REPO_TOKEN` is still required to check out the private content repo.

## Production and previews

Pushes to `main`, Obsidian publish events, and manual workflow runs deploy to
the project's production branch, `main`. Hugo's production base URL is
`https://phuchoang.sbs/`.

Pull requests from this repository deploy to `pr-<number>`. The workflow reads
the actual Pages hostname from the API, builds with the branch alias as its
base URL, and updates one preview comment per PR. Fork PR deployments are
skipped because the private content and deployment secrets are unavailable.

## Domain cutover

After the first successful production deployment, open the Pages project's
**Custom domains**, add `phuchoang.sbs`, and confirm the DNS change from GitHub
Pages to the Pages hostname. The domain is already managed by Cloudflare.
Associate the domain through Pages before changing its DNS record. Wait for
the domain to become active and verify the homepage, posts, and tags.

After Cloudflare serves the custom domain successfully, disable the old
GitHub Pages site in the repository's Pages settings. The workflow no longer
writes to `gh-pages`; its old deployment can remain available until cutover.

The public R2 media domain `images.phuchoang.sbs` is independent of website
hosting and needs no changes.
