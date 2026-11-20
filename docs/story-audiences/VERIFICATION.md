# Verified prototype

Tested: Apple Silicon, Xcode 27.2, iOS 27.2 Simulator, iPhone 17 / 402×874pt. The prebuilt app is arm64 for iOS Simulator; it is not a device IPA or a macOS app.

Release build 76 built successfully and launched on the review simulator. The results below are historical UI coverage from build 68.

| Scenario | Time |
| --- | --- |
| `testFigmaDefaultBackdropDrag` | 46.769s |
| `testFigmaDefaultFinalPolish` | 45.809s |
| `testFigmaDefaultSevenEightAudienceThreshold` | 63.550s |

Repeated deep drags, cancellation/rebound, dismissal/reopening, list creation, icon changes, original publication, original viewers, compact/full audience sheets and horizontal detail navigation were exercised. Actual Simulator recordings were reviewed by frame; a green build alone was not used as visual acceptance.

Revision68 deep-drag samples50.4–57.0s showed no independently moving tint edge. Photo samples before/after dismissal had zero mean/peak RGB difference. Published full-sheet progress controls are covered by the same native clipped viewport. Compact card appearance was reviewed. Revision67 publication frames145.027–145.380s showed the original photo-to-avatar transition over chats without residual tint; the Display implementation is identical in68.

Earlier revision64 checked all16 supplied custom icons and the removal alert; revision66 checked actual story rewinding between custom and standard audiences. All published badges measured45×27pt, with20pt glyph frames, builtin4.5pt/custom5pt left inset. Row glyph frames are28pt; detail glyphs72pt; picker glyphs32pt.

## Re-run

Run the model check from the repository root:

```sh
python3 build-system/story-audiences-demo/check-model.py
```

After installing/building the demo, generate the separate native XCTest runner:

```sh
python3 build-system/story-audiences-demo/prepare-ui-tests.py
xcodebuild test \
  -project build-system/story-audiences-demo/NativeFlowTests.xcodeproj \
  -scheme NativeFlowTests \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID' \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:NativeFlowTests/NativeFlowTests/testFigmaDefaultBackdropDrag \
  -only-testing:NativeFlowTests/NativeFlowTests/testFigmaDefaultFinalPolish \
  -only-testing:NativeFlowTests/NativeFlowTests/testFigmaDefaultSevenEightAudienceThreshold
```

These FigmaDefault scenarios use isolated UUID fixture accounts. They preserve the ordinary demo lists. Network observations and the inert engine boundary are scenario evidence, not a security audit of every client feature. Other toolchains/runtimes and real-account privacy have not been validated.
