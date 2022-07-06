# git-pile

`git-pile` is a set of scripts for using a stacked-diff[^1] workflow
with git & GitHub[^2]. There are a lot of different trade-offs for how
this can work, `git-pile` chooses to be mostly not-magical at the cost
of being best at handling multiple commits that _don't conflict_ with
each other instead of chains of pull requests affecting the same code.
This approach was conceived by [Dave
Lee](https://github.com/kastiglione) and I while working at Lyft, you
can read more about that
[here](https://kastiglione.github.io/git/2020/09/11/git-stacked-commits.html).

[^1]: [This](https://jg.gg/2018/09/29/stacked-diffs-versus-pull-requests)
    is a good explainer, or you can just read the [usage](#usage)
    examples.
[^2]: These scripts could be extended to support other Git hosts that
    supported similar workflows without too much work.

## Benefits

1. Never think about branches again
2. Always test all of your changes integrated together on the repo's
   main branch, even if they are submitted as separate pull requests on
   GitHub
3. Avoid thrashing state such as file time stamps or build caches
   when switching between different work

## Usage

### git-submitpr

The `git-submitpr` is the first script you run to interact with
`git-pile`. It will submit a PR on GitHub with just the most recent
commit from your "pile" of commits on your branch. It automatically uses
your commit message to fill in your PR title and description:

```sh
$ git checkout main # always do work on your main branch
$ # do some work
$ git add -A
$ git commit -m "I made some changes"
$ git submitpr
```

Once you submit a PR you are free to move on and start working on other
changes while still on the main branch.

#### Options

- You can pass a different sha for submitting a PR for an older commit
  on the branch (by default `HEAD` is used). This is for the case where
  you forget to submit a PR for a commit, and then make a new commit on
  top of it.
- All other options passed to `git submitpr` are passed through to the
  underlying `gh pr create` invocation
- You can stack a PR using the --onto flag. e.g `git submitpr head --onto 
head~2`
- TODO: support auto-merge with `gh`

### git-updatepr

`git-updatepr` allows you to add more changes to an existing PR. For
example:

```sh
$ git submitpr # Create the intitial PR
$ # get some code review feedback
$ # make more changes
$ git add -A
$ git commit -m "I fixed the code review issue"
$ git updatepr abc123 # pass the sha of the local commit from the original the PR
```

This will push the new commit to the PR you created originally.

#### Options

- Pass `--squash` to squash the new commit into the initial commit on
  the PR, by default the new commit will be pushed directly.

### git-headpr

`git-headpr` is similar to [`git-updatepr`](#git-updatepr) except it
doesn't require you to have committed your changes manually, and it
automatically updates the PR from the most recent commit in your pile,
avoiding you having to grab the specific sha. For example:

```sh
$ git submitpr # Create the intitial PR
$ # get some code review feedback
$ # make more changes
$ git add -A
$ git status
... some changes are shown
$ git headpr
```

In this case `git-pile` will initiate a commit, and then run
`git updatepr` with the most recent sha on your branch. This only works
if you haven't made subsequent commits since the PR you want to update.

#### Options

- You can pass `--squash` to squash the new commit into the initial
  commit from the PR (in this case you will not be promoted for a commit
  message)
- All other options are passed through to `git commit`

### git-absorb

`git-absorb` is a more advanced version of [`git-headpr`](#git-headpr)
copied from the idea of [`hg
absorb`](https://gregoryszorc.com/blog/2018/11/05/absorbing-commit-changes-in-mercurial-4.8/)
(but currently far less advanced). It intelligently chooses which commit
your new changes should be added to based on which files you're changing
and in which commits you changed them in previously.

This is useful for when you have many commits in your pile, and you go
back to make a change to a previous PR. For example:

```sh
$ # change file1
$ # commit + submitpr
$ # change file2
$ # commit + submitpr
$ # go back and change file1 again
$ git status
... shows file1 is changed
$ git absorb
```

In this example `git absorb` will prompt you to commit, and then
automatically run `git updatepr` updating your first commit that changed
`file1`. It is functionally equivalent to:

```sh
$ git commit -m "..."
$ git updatepr sha123 # the sha from the first change
```

In the case that multiple commits in your pile touched the same files,
`git absorb` will prompt you with a fuzzy finder to choose which PR to
update.

If you have staged files, only those will be included in the commit
(like normal), if you don't have any staged files `git absorb` will `git
add` _all_ your currently changed files before committing.

#### Options

- You can pass `--squash` to squash the new commit into the initial
  commit from the PR (in this case you will not be promoted for a commit
  message)
- TODO: all other options should be passed to `git commit`, currently
  only `-s` is accepted

### git-rebasepr

`git-rebasepr` rebases the PR for a given sha. This is useful in the
case that your changes were functionally dependent so CI on your PR was
failing until something else merged, or just in the case your PR is very
old and you want to rebase it to re-run CI against the new state of the
repo.

Example:

```sh
$ git rebasepr abc123 # the sha of the PR you want to rebase
```

## Installation

### On macOS with [homebrew](https://brew.sh)

```
brew install keith/formulae/git-pile
```

### Manually

1. Add this repo's `bin` directory to your `PATH`
2. Install [gh](https://cli.github.com/)
3. Install [fzy](https://github.com/jhawthorn/fzy) and `python3`
   (required for [`git-absorb`](#git-absorb))

## Configuration

### Required

- Run `gh auth status` to make sure you have a valid login with `gh`,
  otherwise you'll need to sign in with it, run `gh auth` for
  instructions.

### Recommended

- Run `git config --global rerere.enabled true` to save conflict
  resolution outcomes so that in the case that you hit conflicts you
  only have to resolve them once.
- Run `git config --global pull.rebase true` to use the rebase strategy
  when pulling from the remote. This way when you run `git pull` you
  will be able to easily skip commits with `git rebase --skip` that were
  landed upstream, but have local conflicts in your pile.
- Run `git config --global advice.skippedCherryPicks false` to disable
  `git` telling you that some local commits where ignored when you `git
  pull`, this is the expected behavior of commits disappearing from your
  local pile after they're merged on GitHub.
- Configure git to stop you from accidentally pushing to your
  main branch with `git config --global branch.main.pushRemote NOPE`. To
  allow pushing to the main branch for specific repos you can set
  config just for that repo with `git config branch.main.pushRemote
  origin`

### Optional

- Set `GIT_PILE_PREFIX` in your shell environment if you'd
  like to use a consistent prefix in the underlying branch names
  `git-pile` creates. For example `export GIT_PILE_PREFIX=ks/`. Note if
  you change this after using `git-pile` to create a PR, your PRs
  created before setting the prefix will not be updatable with the other
  commands.
- Set `GIT_PILE_USE_PR_TEMPLATE` in your shell environment if you'd like
  `git-pile` to attempt to prefill the description of your PR with the [PR
  template][template] file if it exists.

[template]: https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/creating-a-pull-request-template-for-your-repository

## Advanced usage

### Squash and merge

It's best to use `git-pile` with the squash-and-merge GitHub merge
strategy. This is because `git-pile` squashes all commits that you push
to a PR into one on your main branch, as is traditional with stacked
diff workflows where each commit is an independent atomic change.

In the case where this doesn't work for you, either by accident or when
contributing to an open source repo that uses a different merge strategy
there are a few things to note:

- When you `git pull` your commit may not disappear cleanly. In this
  case I often use `git rebase --skip` when I know that the upstream
  should be the source of truth for a commit

### Editing on GitHub

In some cases you receive code review comments that you want to commit
directly in the GitHub UI, if you do this your local commit becomes out
of sync with the underlying branch that was created. In this case there
are 2 important things to note:

- When you `git pull` you might have conflicts with your local commit,
  and it won't disappear cleanly. In this case I often `git rebase
  --skip` and accept the remote commit instead.
- If you want to push more changes to the same PR locally `git updatepr`
  will identify that changes were made on the upstream branch, and
  confirm that you want to pull them before pushing your own changes.

### Conflicting changes

Using `git-pile` is easier in the case your changes do not conflict, but
`git-pile` still does its best to handle resolving conflicts in the case
they arise. For example if you submit 2 PRs that have conflicting
changes, when you run `git submitpr` conflicts will arise when the
commit is being cherry picked. In this case you must resolve the
conflicts and run `git cherry-pick --continue`. Then when you are
merging the PRs on GitHub, likely you will have to rebase one of the PRs
after the first one merges to resolve the conflicts yet again. In this
case I often run `git rebasepr` locally after one of the PRs merges to
resolve the conflicts. If you have `rerere.enabled` set globally in your
`git` config, you may only have to resolve the conflicts once.

### Dropping changes

Sometimes you might submit a PR, and realize it wasn't the right
approach. Or you might want to submit multiple PRs touching related
areas just for testing CI, or showing an example. In this case you might
not want these commits sitting around on your pile forever. To avoid
this I often "drop" commits from my pile, either by using `git rebase
-i` and deleting the lines from the file, or by using [this
script](https://github.com/keith/dotfiles/blob/2ae59b8f2afbb2a2cea2b55ef1b37da55bd5c1d3/bin/git-droplast).
Be careful not to drop any un-submitted work when doing this.

## Under the hood

As stated above one of the advantages of `git-pile` over other stacked
diff workflows is relative simplicity. Here's how `git-pile` works when
you run `git submitpr`:

1. It creates a [`git worktree`](https://git-scm.com/docs/git-worktree)
   in `~/.cache/git-pile` for the current repository
2. It derives a branch name from your commit message's title
3. It branches off the upstream of your currently checked out branch
4. It checks out the new branch in the worktree, and cherry picks your
   commit onto the branch
5. It pushes the branch to the remote
6. It submits a PR using `gh pr create`

While this is a lot of steps, the nice part of this is that if you hit
an issue with `git-pile`, or want fall back to a workflow you're more
comfortable with, you can `git switch` to the underlying branch that
`git-pile` created, and use normal `git` as normal. You can even swap
between the `git-pile` workflow and not, as long as you're aware of the
potential for introducing conflicts you'll have to resolve later.

Once the steps above have been done, all other commands like
`git updatepr` follow steps similar to:

1. Checkout the previously created branch in the worktree
2. Cherry pick the new commit to the branch, squashing if requested (in
   the case of conflicts, you resolve them as usual and run `git
   cherry-pick --continue`)
3. Push the new branch state to the remote
4. Squash the new commit into the original commit on your main branch,
   treating it as a single change.
