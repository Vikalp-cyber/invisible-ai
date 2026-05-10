# Production Deployment Blueprint

## Production Architecture

- **App shell**: Flutter Desktop (Windows) with Riverpod state graph.
- **Native integration**: Win32 runner + channel bridges for speech/audio and protection.
- **Data/security boundary**:
  - local settings in `SharedPreferences`
  - API keys stored encrypted-at-rest through `SecureStorageService`
- **Observability**:
  - structured JSON logs (`logs/app.log`)
  - crash dumps (`crashes/*.log`)
  - analytics events captured via `AnalyticsService`
- **Release artifacts**:
  - portable zip package
  - signed installer (`Inno Setup`)

## Implemented Production Components

- Logging service: `lib/core/production/app_logger.dart`
- Crash capture: `lib/core/production/crash_reporting_service.dart`
- Analytics event stub: `lib/core/production/analytics_service.dart`
- Settings model (theme/offline/plugins): `lib/core/production/settings_service.dart`
- Plugin hook registry: `lib/core/production/plugin_registry_service.dart`
- Auto-update checker scaffold: `lib/core/production/auto_update_service.dart`

## CI/CD (GitHub Actions)

Workflow: `.github/workflows/windows-release.yml`

- Trigger on tags `v*` or manual dispatch.
- Build Windows release.
- Create portable zip.
- Build installer with Inno Setup.
- Upload workflow artifacts.
- Publish GitHub release assets on tag push.

## Installer Configuration

Installer script: `installer/invisible_ai_assistant.iss`

- Installs to `Program Files`.
- Creates start menu and optional desktop shortcut.
- Launches app post-install.

## Deployment Scripts

- `scripts/build_release.ps1` – build + zip package
- `scripts/create_installer.ps1` – compile Inno Setup installer
- `scripts/sign_binary.ps1` – Authenticode signing helper

## Security Improvements Applied

- Removed hardcoded API keys from startup code.
- Added encrypted-at-rest API key storage in `SecureStorageService`.
- Added crash and audit logging for incident triage.
- Added binary signing path for release trust.
- Added release pipeline boundary around artifacts.

## Native Hardening Baseline

`windows/CMakeLists.txt` should include release-specific hardening flags:

- Control Flow Guard (`/guard:cf`)
- Spectre mitigations (`/Qspectre`) where supported
- ASLR-compatible linker defaults

## Anti-Debugging Basics (Recommended)

Add lightweight checks in runner startup:

- `IsDebuggerPresent()` early exit/log
- `CheckRemoteDebuggerPresent()`
- timing anomaly checks around sensitive operations

Keep these non-invasive to avoid false positives for dev builds.

## Offline Mode Strategy

- Use `SettingsService.offlineMode`.
- If enabled:
  - skip network providers
  - route to local fallback provider (for example Ollama/local cache)
  - queue analytics locally for later flush

## Theme Customization Strategy

- Persist `ThemeMode` in `SettingsService`.
- Add theme provider + dynamic app theme selection.
- Optional: custom accent color preference.

## Plugin System Strategy

- `PluginRegistryService` handles optional runtime hooks.
- Gate plugin loading using `SettingsService.pluginsEnabled`.
- Provide plugin capability manifest and validation in future iteration.

