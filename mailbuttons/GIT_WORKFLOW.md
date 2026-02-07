# Git Workflow Crib Sheet

## Remotes

| Remote     | URL                                          | Purpose              |
|------------|----------------------------------------------|----------------------|
| `origin`   | `git@github.com:rhalldearn/kanidm.git`       | Your fork            |
| `upstream` | `https://github.com/kanidm/kanidm.git`       | Main kanidm project  |

## Branches

| Branch               | Purpose                                           |
|----------------------|---------------------------------------------------|
| `master`             | Kept in sync with upstream. Base for contributions |
| `fix/*`, `feat/*`    | Short-lived branches for upstream PRs              |
| `custom/mailbuttons` | Long-lived branch for branding + deploy scripts    |

## Sync master with upstream

```bash
git checkout master
git pull upstream master
git push origin master
```

## Contribute a bug fix or feature upstream

```bash
git checkout master
git pull upstream master
git checkout -b fix/describe-the-fix
# ... make changes ...
git push origin fix/describe-the-fix
# Open PR on GitHub against kanidm/kanidm master
```

## Update custom/mailbuttons with latest upstream

```bash
git checkout master
git pull upstream master
git push origin master
git checkout custom/mailbuttons
git merge master
# Resolve any conflicts, then:
git push origin custom/mailbuttons
```

## Cherry-pick a specific upstream fix into custom branch

```bash
git checkout custom/mailbuttons
git cherry-pick <commit-hash>
git push origin custom/mailbuttons
```

## Build and test

```bash
cargo build                     # Build everything
cargo test                      # Run all tests
cargo test -p <crate> <name>    # Run a single test
cargo fmt --check               # Check formatting
cargo clippy                    # Lint
make precommit                  # Full pre-commit check
```

## Run dev server

```bash
cd server/daemon
./run_insecure_dev_server.sh
./run_insecure_dev_server.sh recover-account admin
```
