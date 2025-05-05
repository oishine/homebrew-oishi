## homebrew-oishi
oishine's Homebrew repository

### Adding the Tap

To add this tap to your Homebrew installation:

```bash
brew tap oishine/homebrew-oishine
```

### App Installation

```bash
brew install --cask oishine/oishi/appname
```

### Removing the Tap

> [!NOTE]
> You should remove any installed apps from this tap before removing the tap.

To remove this tap from your Homebrew installation:
```bash
brew untap oishine/homebrew-oishine
```

### Fixing Conflicts
1. Go to `/usr/local/Homebrew/Library/Taps/oishine/homebrew-oishine`.
2. Abort rebase operation by running `git rebase --abort`.
3. Reset the repository by running `git reset --hard HEAD~1`.
4. Pull the latest changes from the tap by running `git pull`.
