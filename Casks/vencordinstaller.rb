cask "vencordinstaller" do
  version "1.4.0"
  sha256 "b7b4d38643223df94f3af937ad05cd25c68d0b1aa5b6da52b71aee4593da8817"
  url "https://github.com/Vencord/Installer/releases/download/v#{version}/VencordInstaller.MacOS.zip"
  name "VencordInstaller"
  desc "A cross platform app for installing Vencord"
  homepage "https://github.com/Vencord/Installer"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true

  app "VencordInstaller.app"

  zap trash: [ "~/Library/Application Support/Vencord" ]
end
