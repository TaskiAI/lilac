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
end
