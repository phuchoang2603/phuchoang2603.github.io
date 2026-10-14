{ pkgs, ... }:
{
  # nixpkgs provides the Extended edition required by Blowfish.
  packages = [
    pkgs.git
    pkgs.hugo
    pkgs.watchexec
  ];

  scripts = {
    dev.exec = ''
      # Restart the preview when the published Markdown changes.
      # Hugo continues to watch templates, styles, and other assets itself.
      exec watchexec --watch ../obsidian/publish --exts md \
        --restart --quiet --no-vcs-ignore -- \
        hugo server --buildDrafts --disableFastRender --renderToMemory "$@"
    '';
    build.exec = ''
      exec hugo --minify "$@"
    '';
  };

  # `devenv up` runs the same live-reloading preview as `dev`.
  processes.hugo.exec = "dev";

}
