cask "rquickshare" do
  arch arm: "aarch64", intel: "x64"

  depends_on macos: ">= :high_sierra"

  version "0.11.5"
  sha256 arm:   "0a30c11e9b476af75a780156119b3caacec894211e72905952b97c4eecaa8f22",
         intel: "e54e63e449d4ea1b2266acff238f0eaaa38acb896b6e0153e67db99e83afc420"

  url "https://github.com/Martichou/rquickshare/releases/download/v#{version}/r-quick-share-main_v0.11.5_#{arch}.dmg"
  name "RQuickShare"
  desc "Rust implementation of NearbyShare/QuickShare from Android"
  homepage "https://github.com/Martichou/rquickshare"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "RQuickShare.app"

  zap trash: [
    "~/Library/Application Support/dev.mandre.rquickshare",
    "~/Library/Caches/dev.mandre.rquickshare",
    "~/Library/LaunchAgents/dev.mandre.rquickshare.plist",
    "~/Library/Logs/dev.mandre.rquickshare",
    "~/Library/Preferences/dev.mandre.rquickshare.plist",
    "~/Library/Saved Application State/dev.mandre.rquickshare.savedState",
    "~/Library/WebKit/dev.mandre.rquickshare",
  ]
end
