# Implementation Plan: Windows Screen Capture Protection

This plan outlines adding native Windows screen capture protection to the desktop assistant, ensuring the overlay is invisible to screenshots and screen recordings (e.g. OBS, Snipping Tool) while remaining visible to the user.

## User Review Required

> [!IMPORTANT]
> **Architectural Decision: C++ Plugin vs. Pure Dart (FFI)**
> You requested a "Full Flutter plugin implementation" with "Windows C++ code". However, because your app already includes the highly robust `win32` Dart package, we can actually implement `SetWindowDisplayAffinity` entirely in Dart using Foreign Function Interface (FFI). 
> 
> **Option A: Pure Dart FFI (Highly Recommended)**
> - Requires 0 lines of C++ code.
> - Instant compilation, no complex Visual Studio build chains.
> - We locate the Flutter Window Handle (HWND) and call the native Win32 API directly from Dart.
>
> **Option B: Native C++ Plugin**
> - Matches your exact prompt literally.
> - We will generate a local plugin (`packages/window_protection`).
> - We will write C++ code (`window_protection_plugin.cpp`) to handle the MethodChannel and Win32 API.
> - Adds build complexity.
>
> **Do you approve using Option A (Pure Dart FFI) for a much cleaner architecture, or do you strictly require Option B (C++ Plugin) for educational/architectural reasons?**

## 1. Core Logic (`SetWindowDisplayAffinity`)
Regardless of the option chosen, the core Win32 API being called is:
```cpp
SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE);
```
This forces the Desktop Window Manager (DWM) to render the window completely black or invisible in all screen captures.

## 2. Implementation Steps (Option A - Dart FFI)
If Option A is selected:
1. Create `lib/services/window_protection_service.dart`.
2. Use `window_manager` or `FindWindow` from `win32` to acquire the `HWND` of the Flutter app.
3. Call `SetWindowDisplayAffinity(hwnd, 0x00000011)` (`WDA_EXCLUDEFROMCAPTURE = 0x11`).
4. Add a toggle in `AssistantNotifier` to turn protection on/off dynamically.

## 3. Implementation Steps (Option B - C++ Plugin)
If Option B is selected:
1. Run `flutter create --template=plugin --platforms=windows packages/window_protection`.
2. Update `windows/window_protection_plugin.cpp`:
   - Intercept method channel call `setProtection`.
   - Extract `HWND` via `registrar->GetView()->GetNativeWindow()`.
   - Call `SetWindowDisplayAffinity(hwnd, enable ? WDA_EXCLUDEFROMCAPTURE : WDA_NONE)`.
3. Add the local package to `pubspec.yaml` (`path: packages/window_protection`).
4. Create the Dart bridging service `WindowProtectionService`.

## 4. Initialization & State Management
- Update `main.dart` or `WindowService` to apply the protection automatically on startup based on a saved user preference.
- Provide a `toggleProtection()` method to the UI state.

## Verification Plan
1. Launch the application.
2. Use the built-in Windows Snipping Tool (`Win + Shift + S`) or OBS Studio to capture the screen.
3. Verify that the Flutter overlay window does not appear in the resulting capture.
