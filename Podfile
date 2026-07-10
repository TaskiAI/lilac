# CocoaPods dependency for on-device handwriting recognition (Google ML Kit
# Digital Ink). ML Kit has no reliable SwiftPM distribution for Digital Ink, so
# it's integrated via CocoaPods.
#
# Workflow (macOS):
#   1. xcodegen generate        # (re)creates Lilac.xcodeproj
#   2. pod install              # integrates ML Kit, creates Lilac.xcworkspace
#   3. open Lilac.xcworkspace   # build/run from the WORKSPACE, not the project
#
# IMPORTANT: `xcodegen generate` rewrites the .xcodeproj and drops the pods
# integration, so re-run `pod install` after every regenerate.
#
# The app builds and runs WITHOUT this pod — `MLKitHandwritingRecognizer` is
# guarded by `#if canImport(MLKitDigitalInkRecognition)` and the extractor falls
# back to Apple Vision. Adding the pod upgrades handwriting recognition.

platform :ios, '17.0'

target 'Lilac' do
  use_frameworks!
  pod 'GoogleMLKit/DigitalInkRecognition'

  # OPTIONAL — "Sign in with Google" on the account screen.
  # The button + `GoogleSignInCoordinator` are guarded by
  # `#if canImport(GoogleSignIn)`, so the app builds and runs without this.
  # To enable it:
  #   1. Uncomment the pod below and run `pod install`.
  #   2. Create an iOS OAuth client in Google Cloud Console.
  #   3. Add `GIDClientID` (your client ID) to the app's Info.plist, and a URL
  #      scheme equal to your REVERSED client ID.
  # Until then the Google button shows a "needs setup" prompt.
  # pod 'GoogleSignIn'
end
