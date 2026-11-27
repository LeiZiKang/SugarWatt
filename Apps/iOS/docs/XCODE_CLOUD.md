# Xcode Cloud Setup (SugarWatt)

Both `KangCharge` (macOS) and `KangCharge-iOS` (iOS + watchOS) include ready-to-run Xcode Cloud hooks at `ci_scripts/ci_post_clone.sh`.

## 1. Required Xcode Cloud Environment Variable

Because `Config/Local.xcconfig` is git-ignored in our public MIT repositories, configure this environment variable in **Xcode → Integrate → Xcode Cloud → Manage Workflows → Environment** (or in App Store Connect):

| Name | Value | Secret? |
| --- | --- | --- |
| `KC_DEVELOPMENT_TEAM` | Your 10-character Apple Developer Team ID | Yes |
| `KC_BUNDLE_ID_PREFIX` | *(Optional — defaults to `io.github.leizikang`)* | No |

## 2. Creating the Workflow (One-Time, ~60s)
1. Open `KangChargeiOS.xcodeproj` in Xcode (`KangChargeiOS` scheme automatically embeds both the iOS Widget and the Apple Watch app + Watch Widget in a single Archive).
2. Choose **Integrate → Xcode Cloud → Create Workflow…**, select the **SugarWatt** App record (`io.github.leizikang.kangcharge`), and authorize GitHub repository access when prompted.
3. Under **Archive**, set deployment preparation to **App Store Connect** (required for External TestFlight and App Store Review).
4. Under **Environment**, add `KC_DEVELOPMENT_TEAM` (marked **Secret**).
5. Save & click **Start Build**.

## 3. What `ci_post_clone.sh` Automates
1. **Generates `Config/Local.xcconfig`** with `CODE_SIGN_STYLE = Automatic` & `IOS_CODE_SIGN_STYLE = Automatic` before Xcode resolves signing.
2. **Auto-increments `CURRENT_PROJECT_VERSION`** using Xcode Cloud's `CI_BUILD_NUMBER`, preventing duplicate TestFlight/App Store build-number rejections on frequent releases.
3. **Skips SPM macro fingerprint prompts** for unattended headless builds.
