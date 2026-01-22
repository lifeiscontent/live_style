import Config

config :git_ops,
  mix_project: LiveStyle.MixProject,
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/lifeiscontent/live_style",
  manage_mix_version?: true,
  manage_readme_version?: "README.md",
  version_tag_prefix: "v"
