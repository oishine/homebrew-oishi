## firebrew
Self-maintained [Homebrew](https://brew.sh/) repository.

### Adding the Tap

To add this tap to your Homebrew installation:

```bash
brew tap navialliance/firebrew https://github.com/navialliance/firebrew
```

### App Installation

```bash
brew install --cask navialliance/firebrew/appname
```
or
```
brew install --cask appname #if there's no duplicate casks
```

### Removing the Tap

> [!NOTE]
> You should remove any installed apps from this tap before removing the tap.

To remove this tap from your Homebrew installation:
```bash
brew untap navialliance/firebrew
```

### Fixing Conflicts
1. Go to `/usr/local/Homebrew/Library/Taps/navialliance/homebrew-firebrew`.
2. Abort rebase operation by running `git rebase --abort`.
3. Reset the repository by running `git reset --hard HEAD~1`.
4. Pull the latest changes from the tap by running `git pull`.
