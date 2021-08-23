#!/usr/bin/env sh

# Set window gap in Moom to 20px
defaults write /Users/jamie/Library/Preferences/com.manytricks.Moom "Grid Spacing: Gap" -int 20

# Switch profile in Hocus Focus
defaults write com.uglyapps.HocusFocus.plist kActiveProfileGUIDKey -string 9B2279CB-AA2B-41BE-908E-27BEEEF1C48D
pkill -fl "Hocus Focus"
"/Applications/Hocus Focus.app/Contents/MacOS/Hocus Focus" &

# Set font size in Kitty
/usr/local/bin/kitty @ --to unix:$(/run/current-system/sw/bin/fd socket ~/.local/share/kitty) set-font-size 16
