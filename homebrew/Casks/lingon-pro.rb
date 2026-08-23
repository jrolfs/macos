cask "lingon-pro" do
  version "10.2.6"
  sha256 "8f75e54e58617d41e971d65416227f84be163ed12ee4e2d738781bc82d69f1c0"

  url "https://www.peterborgapps.com/downloads/LingonPro#{version.major}.zip"
  name "Lingon Pro"
  desc "Interface for launchd"
  homepage "https://www.peterborgapps.com/lingon/"

  app "Lingon Pro.app"
end
