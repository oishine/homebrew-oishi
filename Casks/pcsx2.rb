cask "pcsx2" do
  version "2.3.344"
  sha256 "c67a303f6b1c13626c4fbf15ac97b76b21d5c706465b4310bbacac53a78a457b"
  url "https://github.com/PCSX2/pcsx2/releases/download/v#{version}/pcsx2-v#{version}-macos-Qt.tar.xz",
    verified: "https://github.com/PCSX2/pcsx2/releases/download"
  name "PCSX2"
  desc "Open Source PS2 Emulator"
  homepage "https://pcsx2.net"

  livecheck do
    url :url
    regex(/^v?(\d+\.\d+\.\d+(?:-[\w.]+)?)$/i)
    strategy :github_releases do |json, regex|
      json.map do |release|
        next if release["draft"]
        match = release["tag_name"]&.match(regex)
        match[1] if match
      end.compact
    end
  end

  auto_updates true

  app "PCSX2-v#{version}.app", target: "PCSX2.app"

  zap trash: [
    "~/Library/Preferences/net.pcsx2.pcsx2.plist",
    "~/Library/Saved Application State/net.pcsx2.pcsx2.savedState"
  ]
end
