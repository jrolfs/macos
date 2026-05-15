cask "lingon-pro" do
  version "10.2.2"
  sha256 "dbb77bc399931b1e1634d5c2e446eb953193fee1355d8de0453a1dfea15071b8"

  url "https://www.peterborgapps.com/downloads/LingonPro#{version.major}.zip"
  name "Lingon Pro"
  desc "Interface for launchd"
  homepage "https://www.peterborgapps.com/lingon/"

  app "Lingon Pro.app"
end
