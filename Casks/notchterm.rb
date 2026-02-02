cask "notchterm" do
  version "0.1.0-alpha.2"
  sha256 "657d9822ee2d27839ac948f7844bd13475567f9b5ee67c1ea8995509a4f34be3"

  url "https://github.com/skywardpixel/NotchTerm/releases/download/v#{version}/NotchTerm-#{version}.zip"
  name "NotchTerm"
  desc "Drop-down terminal for macOS that emerges from the notch area"
  homepage "https://github.com/skywardpixel/NotchTerm"

  depends_on macos: ">= :monterey"

  app "NotchTerm.app"

  zap trash: [
    "~/.config/notchterm",
  ]
end
