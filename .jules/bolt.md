## 2023-10-17 - SwiftUI Published Property Re-renders
**Learning:** Assigning the same value to an `@Published` property in an `ObservableObject` triggers `objectWillChange.send()`, which causes any observing SwiftUI Views to unnecessarily re-evaluate their `body`. In our WKWebView coordinator, navigation events frequently fire with redundant state (e.g., setting `isLoading = true` multiple times during initial load).
**Action:** Always check the current value before assigning to an `@Published` property to prevent unnecessary view re-renders, especially in delegate callbacks that fire frequently.

## 2023-10-17 - WKWebView Rendering Performance
**Learning:** Transparent views require the GPU to perform alpha blending with layers beneath them. `WKWebView` can sometimes be treated with transparency overhead.
**Action:** Explicitly set `webView.isOpaque = true` and provide a solid background color to eliminate alpha blending overhead during rendering, freeing up GPU cycles for scrolling and content rendering.
