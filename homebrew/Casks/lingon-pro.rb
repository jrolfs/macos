cask "lingon-pro" do
  version "10.2.4"
  sha256 "21d214de420d191b21413c53c2b50d8a5aef33fbc4c89dc0729faddc8064393b"

  url "https://www.peterborgapps.com/downloads/LingonPro#{version.major}.zip"
  name "Lingon Pro"
  desc "Interface for launchd"
  homepage "https://www.peterborgapps.com/lingon/"

  app "Lingon Pro.app"
end
