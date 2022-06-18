# git-pile

TODO

## Usage

TODO

## Installation

### On macOS with [homebrew](https://brew.sh)

```
brew install keith/formulae/git-pile
```

### Manually

1. Add this repo's `bin` directory to your `PATH`
2. Install [gh](https://cli.github.com/)

## Setup

- Run `gh auth status` to make sure you have a valid login with `gh`,
  otherwise you'll need to sign in with it, run `gh auth` for
  instructions.
- Optionally set `GIT_PILE_PREFIX` in your shell environment if you'd
  like to use a consistent prefix in the underlying branch names
  git-pile creates. For example `export GIT_PILE_PREFIX=ks/`. Note if
  you change this after using git-pile to create a PR, your PRs created
  before setting the prefix will not be updatable with the other
  commands.
