cask "pcsx2" do
  version "2.3.274"
  sha256 "f620bbb1ff420aa52a2c30729867511ab849e5f67c8eb1e7042c049ebd79a368"
  url "https://github.com/PCSX2/pcsx2/releases/download/v#{version}/pcsx2-v#{version}-macos-Qt.tar.xz",
    verified: "https://github.com/PCSX2/pcsx2/releases/download"
  name "PCSX2"
  desc "Open Source PS2 Emulator"
  homepage "https://pcsx2.net"

  livecheck do
      url :url
      regex(/^v?(\d+\.\d+\.\d+(-[\w.]+)?)/i)
      strategy :github_releases do |json, regex|
        json.map do |release|
          next if release["draft"] || release["prerelease"]

          match = release["tag_name"]&.match(regex)
          next if match.blank?

          match[1]
        end
      end
    end

  auto_updates true

  app "PCSX2-v#{version}.app", target: "PCSX2.app"

  zap trash: [
    "~/Library/Preferences/net.pcsx2.pcsx2.plist",
    "~/Library/Saved Application State/net.pcsx2.pcsx2.savedState"
  ]
end
