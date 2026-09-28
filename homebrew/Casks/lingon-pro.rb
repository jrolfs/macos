cask "lingon-pro" do
  version "10.3"
  sha256 "03af45a3294e0524a6f987b7f9fea7fd953a3a855b77c9617b8f371870c50008"

  url "https://www.peterborgapps.com/downloads/LingonPro#{version.major}.zip"
  name "Lingon Pro"
  desc "Interface for launchd"
  homepage "https://www.peterborgapps.com/lingon/"

  app "Lingon Pro.app"
end
