# PROPUESTAS.md

Propuestas pendientes de revision, generadas por agentes automaticos. Ninguna entrada esta aplicada; quedan a la espera de revision humana.

## [2026-10-18 00:51] — PR #1: Bolt: Optimize WKWebView rendering and reduce SwiftUI re-renders
> **Estado:** aplicado

- **Archivos afectados:** Barrioteca/Barrioteca/ContentView.swift
- **Motivo:** What: The optimization implemented Set WKWebView to be opaque with a solid background color, and added conditional checks before modifying @Published properties in the view model. Why: The performance problem it solves 1. WKWebView by default may be treated as having transparency, invoking the alpha blending pass which strains the GPU, especially during scrolling or heavy content repaints. 2. The WKWebView delegate callbacks frequently trigger state updates. Assigning a value to an @Published property always calls objectWillChange.send(), forcing any observing ContentView bodies to re-evaluate unnecessarily. Impact: Expected performance improvement - Speeds up GPU rendering pass by skipping alpha blending, leading to a smoother scroll and web view presentation. - Reduces unnecessary CPU cycles and ContentView body evaluations caused by redundant state assignments. Measurement: How to verify the improvement - Use Xcode Instruments (Core Animation/SwiftUI templates) to profile the view hierarchy and observe reduced redraws, fewer SwiftUI layout cycles, and lower overall rendering overhead.
- **Riesgo:** bajo
- **Validación:** medir con profiling/DevTools antes y despues del cambio

```diff
diff --git a/Barrioteca/Barrioteca/ContentView.swift b/Barrioteca/Barrioteca/ContentView.swift
index 05d193c..0f0190a 100644
--- a/Barrioteca/Barrioteca/ContentView.swift
+++ b/Barrioteca/Barrioteca/ContentView.swift
@@ -1,201 +1,231 @@
-import SwiftUI
-import UIKit
-import WebKit
-
-private let appURL = URL(string: "https://www.corrientelebeche.es/barrioteca/")!
-private let appHost = "www.corrientelebeche.es"
-// Host antiguo: se acepta durante la transición para no romper enlaces guardados.
-private let legacyHost = "pelotxo.synology.me"
-
-struct ContentView: View {
-    @StateObject private var model = WebViewModel()
-
-    var body: some View {
-        ZStack {
-            WebView(url: appURL, model: model)
-                .ignoresSafeArea()
-
-            if model.isLoading {
-                ProgressView()
-                    .progressViewStyle(.circular)
-            }
-
-            if let error = model.error {
-                VStack(spacing: 16) {
-                    Text("No se pudo cargar la Barrioteca")
-                        .font(.headline)
-                        .multilineTextAlignment(.center)
-                    Text(error.localizedDescription)
-                        .font(.footnote)
-                        .foregroundColor(.secondary)
-                        .multilineTextAlignment(.center)
-                    Button("Reintentar") {
-                        model.reload?()
-                    }
-                    .buttonStyle(.borderedProminent)
-                }
-                .padding(24)
-            }
-        }
-    }
-}
-
-final class WebViewModel: ObservableObject {
-    @Published var isLoading = true
-    @Published var error: Error?
-    var reload: (() -> Void)?
-}
-
-struct WebView: UIViewRepresentable {
-    let url: URL
-    @ObservedObject var model: WebViewModel
-
-    func makeCoordinator() -> Coordinator {
-        Coordinator()
-    }
-
-    func makeUIView(context: Context) -> WKWebView {
-        let config = WKWebViewConfiguration()
-        config.allowsInlineMediaPlayback = true
-
-        let prefs = WKWebpagePreferences()
-        prefs.allowsContentJavaScript = true
-        config.defaultWebpagePreferences = prefs
-
-        let webView = WKWebView(frame: .zero, configuration: config)
-        webView.uiDelegate = context.coordinator
-        webView.navigationDelegate = context.coordinator
-        webView.allowsBackForwardNavigationGestures = true
-        webView.scrollView.contentInsetAdjustmentBehavior = .always
-
-        context.coordinator.model = model
-        model.reload = { [weak webView] in
-            webView?.reload()
-        }
-        model.error = nil
-        model.isLoading = true
-        webView.load(URLRequest(url: url))
-        return webView
-    }
-
-    func updateUIView(_ webView: WKWebView, context: Context) {}
-
-    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate,
-        UIImagePickerControllerDelegate, UINavigationControllerDelegate {
-
-        weak var model: WebViewModel?
-        private var openPanelCompletion: (([URL]?) -> Void)?
-
-        // MARK: - Cámara (getUserMedia del escáner)
-
-        func webView(
-            _ webView: WKWebView,
-            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
-            initiatedByFrame frame: WKFrameInfo,
-            type: WKMediaCaptureType,
-            decisionHandler: @escaping (WKPermissionDecision) -> Void
-        ) {
-            decisionHandler(.grant)
-        }
-
-        // MARK: - Selector de archivo (botón "Foto" del escáner)
-
-        @available(iOS 18.4, *)
-        func webView(
-            _ webView: WKWebView,
-            runOpenPanelWith parameters: WKOpenPanelParameters,
-            initiatedByFrame frame: WKFrameInfo,
-            completionHandler: @escaping ([URL]?) -> Void
-        ) {
-            openPanelCompletion = completionHandler
-
-            guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
-                completionHandler(nil)
-                openPanelCompletion = nil
-                return
-            }
-
-            let picker = UIImagePickerController()
-            picker.sourceType = .photoLibrary
-            picker.delegate = self
-            picker.modalPresentationStyle = .fullScreen
-
-            let presenter = webView.window?.rootViewController
-            presenter?.present(picker, animated: true)
-        }
-
-        func imagePickerController(
-            _ picker: UIImagePickerController,
-            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
-        ) {
-            picker.dismiss(animated: true)
-            let url = info[.imageURL] as? URL
-            openPanelCompletion?(url.map { [$0] } ?? [])
-            openPanelCompletion = nil
-        }
-
-        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
-            picker.dismiss(animated: true)
-            openPanelCompletion?(nil)
-            openPanelCompletion = nil
-        }
-
-        // MARK: - Enlaces externos → Safari
-
-        func webView(
-            _ webView: WKWebView,
-            decidePolicyFor navigationAction: WKNavigationAction,
-            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
-        ) {
-            guard let url = navigationAction.request.url,
-                  navigationAction.navigationType == .linkActivated else {
-                decisionHandler(.allow)
-                return
-            }
-
-            if url.host == appHost || url.host == legacyHost || url.host == nil {
-                decisionHandler(.allow)
-            } else {
-                decisionHandler(.cancel)
-                UIApplication.shared.open(url)
-            }
-        }
-
-        func webView(
-            _ webView: WKWebView,
-            createWebViewWith configuration: WKWebViewConfiguration,
-            for navigationAction: WKNavigationAction,
-            windowFeatures: WKWindowFeatures
-        ) -> WKWebView? {
-            if let url = navigationAction.request.url, navigationAction.targetFrame == nil {
-                UIApplication.shared.open(url)
-            }
-            return nil
-        }
-
-        // MARK: - Progreso y errores
-
-        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
-            model?.isLoading = true
-            model?.error = nil
-        }
-
-        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
-            model?.isLoading = false
-        }
-
-        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
-            model?.isLoading = false
-            model?.error = error
-        }
-
-        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
-            model?.isLoading = false
-            model?.error = error
-        }
-    }
-}
-
-#Preview {
-    ContentView()
-}
+import SwiftUI
+import UIKit
+import WebKit
+
+private let appURL = URL(string: "https://www.corrientelebeche.es/barrioteca/")!
+private let appHost = "www.corrientelebeche.es"
+// Host antiguo: se acepta durante la transición para no romper enlaces guardados.
+private let legacyHost = "pelotxo.synology.me"
+
+struct ContentView: View {
+    @StateObject private var model = WebViewModel()
+
+    var body: some View {
+        ZStack {
+            WebView(url: appURL, model: model)
+                .ignoresSafeArea()
+
+            if model.isLoading {
+                ProgressView()
+                    .progressViewStyle(.circular)
+            }
+
+            if let error = model.error {
+                VStack(spacing: 16) {
+                    Text("No se pudo cargar la Barrioteca")
+                        .font(.headline)
+                        .multilineTextAlignment(.center)
+                    Text(error.localizedDescription)
+                        .font(.footnote)
+                        .foregroundColor(.secondary)
+                        .multilineTextAlignment(.center)
+                    Button("Reintentar") {
+                        model.reload?()
+                    }
+                    .buttonStyle(.borderedProminent)
+                }
+                .padding(24)
+            }
+        }
+    }
+}
+
+final class WebViewModel: ObservableObject {
+    @Published var isLoading = true
+    @Published var error: Error?
+    var reload: (() -> Void)?
+}
+
+struct WebView: UIViewRepresentable {
+    let url: URL
+    @ObservedObject var model: WebViewModel
+
+    func makeCoordinator() -> Coordinator {
+        Coordinator()
+    }
+
+    func makeUIView(context: Context) -> WKWebView {
+        let config = WKWebViewConfiguration()
+        config.allowsInlineMediaPlayback = true
+
+        let prefs = WKWebpagePreferences()
+        prefs.allowsContentJavaScript = true
+        config.defaultWebpagePreferences = prefs
+
+        let webView = WKWebView(frame: .zero, configuration: config)
+
+        // ⚡ Bolt: Performance optimization
+        // Eliminates alpha blending overhead for the GPU by ensuring the view is opaque.
+        // This speeds up the rendering pass, especially during scrolling.
+        webView.isOpaque = true
+        webView.backgroundColor = .systemBackground
+        webView.scrollView.backgroundColor = .systemBackground
+
+        webView.uiDelegate = context.coordinator
+        webView.navigationDelegate = context.coordinator
+        webView.allowsBackForwardNavigationGestures = true
+        webView.scrollView.contentInsetAdjustmentBehavior = .always
+
+        context.coordinator.model = model
+        model.reload = { [weak webView] in
+            webView?.reload()
+        }
+
+        // ⚡ Bolt: Prevent unnecessary re-renders
+        // Only trigger @Published state changes if the values actually changed
+        if model.error != nil {
+            model.error = nil
+        }
+        if !model.isLoading {
+            model.isLoading = true
+        }
+
+        webView.load(URLRequest(url: url))
+        return webView
+    }
+
+    func updateUIView(_ webView: WKWebView, context: Context) {}
+
+    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate,
+        UIImagePickerControllerDelegate, UINavigationControllerDelegate {
+
+        weak var model: WebViewModel?
+        private var openPanelCompletion: (([URL]?) -> Void)?
+
+        // MARK: - Cámara (getUserMedia del escáner)
+
+        func webView(
+            _ webView: WKWebView,
+            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
+            initiatedByFrame frame: WKFrameInfo,
+            type: WKMediaCaptureType,
+            decisionHandler: @escaping (WKPermissionDecision) -> Void
+        ) {
+            decisionHandler(.grant)
+        }
+
+        // MARK: - Selector de archivo (botón "Foto" del escáner)
+
+        @available(iOS 18.4, *)
+        func webView(
+            _ webView: WKWebView,
+            runOpenPanelWith parameters: WKOpenPanelParameters,
+            initiatedByFrame frame: WKFrameInfo,
+            completionHandler: @escaping ([URL]?) -> Void
+        ) {
+            openPanelCompletion = completionHandler
+
+            guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
+                completionHandler(nil)
+                openPanelCompletion = nil
+                return
+            }
+
+            let picker = UIImagePickerController()
+            picker.sourceType = .photoLibrary
+            picker.delegate = self
+            picker.modalPresentationStyle = .fullScreen
+
+            let presenter = webView.window?.rootViewController
+            presenter?.present(picker, animated: true)
+        }
+
+        func imagePickerController(
+            _ picker: UIImagePickerController,
+            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
+        ) {
+            picker.dismiss(animated: true)
+            let url = info[.imageURL] as? URL
+            openPanelCompletion?(url.map { [$0] } ?? [])
+            openPanelCompletion = nil
+        }
+
+        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
+            picker.dismiss(animated: true)
+            openPanelCompletion?(nil)
+            openPanelCompletion = nil
+        }
+
+        // MARK: - Enlaces externos → Safari
+
+        func webView(
+            _ webView: WKWebView,
+            decidePolicyFor navigationAction: WKNavigationAction,
+            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
+        ) {
+            guard let url = navigationAction.request.url,
+                  navigationAction.navigationType == .linkActivated else {
+                decisionHandler(.allow)
+                return
+            }
+
+            if url.host == appHost || url.host == legacyHost || url.host == nil {
+                decisionHandler(.allow)
+            } else {
+                decisionHandler(.cancel)
+                UIApplication.shared.open(url)
+            }
+        }
+
+        func webView(
+            _ webView: WKWebView,
+            createWebViewWith configuration: WKWebViewConfiguration,
+            for navigationAction: WKNavigationAction,
+            windowFeatures: WKWindowFeatures
+        ) -> WKWebView? {
+            if let url = navigationAction.request.url, navigationAction.targetFrame == nil {
+                UIApplication.shared.open(url)
+            }
+            return nil
+        }
+
+        // MARK: - Progreso y errores
+
+        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
+            // ⚡ Bolt: Prevent unnecessary SwiftUI view re-renders
+            if model?.isLoading != true {
+                model?.isLoading = true
+            }
+            if model?.error != nil {
+                model?.error = nil
+            }
+        }
+
+        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
+            // ⚡ Bolt: Prevent unnecessary SwiftUI view re-renders
+            if model?.isLoading != false {
+                model?.isLoading = false
+            }
+        }
+
+        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
+            // ⚡ Bolt: Prevent unnecessary SwiftUI view re-renders
+            if model?.isLoading != false {
+                model?.isLoading = false
+            }
+            model?.error = error
+        }
+
+        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
+            // ⚡ Bolt: Prevent unnecessary SwiftUI view re-renders
+            if model?.isLoading != false {
+                model?.isLoading = false
+            }
+            model?.error = error
+        }
+    }
+}
+
+#Preview {
+    ContentView()
+}
```

## [2026-10-18 00:55] — PR #2: Sentinel: [HIGH] Restrict media capture permissions to trusted hosts
> **Estado:** aplicado

- **Archivos afectados:** Barrioteca/Barrioteca/ContentView.swift
- **Motivo:** Severity: HIGH Vulnerability: The WKWebView explicitly granted WKMediaCaptureType permissions (such as camera and microphone access) unconditionally for any web origin. If a malicious link or ad were loaded, it could automatically abuse device hardware capabilities. Impact: An untrusted domain embedded in the web view could eavesdrop or capture camera footage without user consent. Fix: Validated that origin.host matches our trusted endpoints (appHost or legacyHost) before executing decisionHandler(.grant). It now safely falls back to decisionHandler(.deny) for unknown origins. Verification: Verify that the camera works successfully for the scanner component within the main app URL, but denied when attempting to capture media from an external loaded link.
- **Riesgo:** alto
- **Validación:** revisar el parche y verificar que la vulnerabilidad queda cerrada

```diff
diff --git a/Barrioteca/Barrioteca/ContentView.swift b/Barrioteca/Barrioteca/ContentView.swift
index 05d193c..1dd8a92 100644
--- a/Barrioteca/Barrioteca/ContentView.swift
+++ b/Barrioteca/Barrioteca/ContentView.swift
@@ -1,201 +1,206 @@
-import SwiftUI
-import UIKit
-import WebKit
-
-private let appURL = URL(string: "https://www.corrientelebeche.es/barrioteca/")!
-private let appHost = "www.corrientelebeche.es"
-// Host antiguo: se acepta durante la transición para no romper enlaces guardados.
-private let legacyHost = "pelotxo.synology.me"
-
-struct ContentView: View {
-    @StateObject private var model = WebViewModel()
-
-    var body: some View {
-        ZStack {
-            WebView(url: appURL, model: model)
-                .ignoresSafeArea()
-
-            if model.isLoading {
-                ProgressView()
-                    .progressViewStyle(.circular)
-            }
-
-            if let error = model.error {
-                VStack(spacing: 16) {
-                    Text("No se pudo cargar la Barrioteca")
-                        .font(.headline)
-                        .multilineTextAlignment(.center)
-                    Text(error.localizedDescription)
-                        .font(.footnote)
-                        .foregroundColor(.secondary)
-                        .multilineTextAlignment(.center)
-                    Button("Reintentar") {
-                        model.reload?()
-                    }
-                    .buttonStyle(.borderedProminent)
-                }
-                .padding(24)
-            }
-        }
-    }
-}
-
-final class WebViewModel: ObservableObject {
-    @Published var isLoading = true
-    @Published var error: Error?
-    var reload: (() -> Void)?
-}
-
-struct WebView: UIViewRepresentable {
-    let url: URL
-    @ObservedObject var model: WebViewModel
-
-    func makeCoordinator() -> Coordinator {
-        Coordinator()
-    }
-
-    func makeUIView(context: Context) -> WKWebView {
-        let config = WKWebViewConfiguration()
-        config.allowsInlineMediaPlayback = true
-
-        let prefs = WKWebpagePreferences()
-        prefs.allowsContentJavaScript = true
-        config.defaultWebpagePreferences = prefs
-
-        let webView = WKWebView(frame: .zero, configuration: config)
-        webView.uiDelegate = context.coordinator
-        webView.navigationDelegate = context.coordinator
-        webView.allowsBackForwardNavigationGestures = true
-        webView.scrollView.contentInsetAdjustmentBehavior = .always
-
-        context.coordinator.model = model
-        model.reload = { [weak webView] in
-            webView?.reload()
-        }
-        model.error = nil
-        model.isLoading = true
-        webView.load(URLRequest(url: url))
-        return webView
-    }
-
-    func updateUIView(_ webView: WKWebView, context: Context) {}
-
-    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate,
-        UIImagePickerControllerDelegate, UINavigationControllerDelegate {
-
-        weak var model: WebViewModel?
-        private var openPanelCompletion: (([URL]?) -> Void)?
-
-        // MARK: - Cámara (getUserMedia del escáner)
-
-        func webView(
-            _ webView: WKWebView,
-            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
-            initiatedByFrame frame: WKFrameInfo,
-            type: WKMediaCaptureType,
-            decisionHandler: @escaping (WKPermissionDecision) -> Void
-        ) {
-            decisionHandler(.grant)
-        }
-
-        // MARK: - Selector de archivo (botón "Foto" del escáner)
-
-        @available(iOS 18.4, *)
-        func webView(
-            _ webView: WKWebView,
-            runOpenPanelWith parameters: WKOpenPanelParameters,
-            initiatedByFrame frame: WKFrameInfo,
-            completionHandler: @escaping ([URL]?) -> Void
-        ) {
-            openPanelCompletion = completionHandler
-
-            guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
-                completionHandler(nil)
-                openPanelCompletion = nil
-                return
-            }
-
-            let picker = UIImagePickerController()
-            picker.sourceType = .photoLibrary
-            picker.delegate = self
-            picker.modalPresentationStyle = .fullScreen
-
-            let presenter = webView.window?.rootViewController
-            presenter?.present(picker, animated: true)
-        }
-
-        func imagePickerController(
-            _ picker: UIImagePickerController,
-            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
-        ) {
-            picker.dismiss(animated: true)
-            let url = info[.imageURL] as? URL
-            openPanelCompletion?(url.map { [$0] } ?? [])
-            openPanelCompletion = nil
-        }
-
-        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
-            picker.dismiss(animated: true)
-            openPanelCompletion?(nil)
-            openPanelCompletion = nil
-        }
-
-        // MARK: - Enlaces externos → Safari
-
-        func webView(
-            _ webView: WKWebView,
-            decidePolicyFor navigationAction: WKNavigationAction,
-            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
-        ) {
-            guard let url = navigationAction.request.url,
-                  navigationAction.navigationType == .linkActivated else {
-                decisionHandler(.allow)
-                return
-            }
-
-            if url.host == appHost || url.host == legacyHost || url.host == nil {
-                decisionHandler(.allow)
-            } else {
-                decisionHandler(.cancel)
-                UIApplication.shared.open(url)
-            }
-        }
-
-        func webView(
-            _ webView: WKWebView,
-            createWebViewWith configuration: WKWebViewConfiguration,
-            for navigationAction: WKNavigationAction,
-            windowFeatures: WKWindowFeatures
-        ) -> WKWebView? {
-            if let url = navigationAction.request.url, navigationAction.targetFrame == nil {
-                UIApplication.shared.open(url)
-            }
-            return nil
-        }
-
-        // MARK: - Progreso y errores
-
-        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
-            model?.isLoading = true
-            model?.error = nil
-        }
-
-        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
-            model?.isLoading = false
-        }
-
-        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
-            model?.isLoading = false
-            model?.error = error
-        }
-
-        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
-            model?.isLoading = false
-            model?.error = error
-        }
-    }
-}
-
-#Preview {
-    ContentView()
-}
+import SwiftUI
+import UIKit
+import WebKit
+
+private let appURL = URL(string: "https://www.corrientelebeche.es/barrioteca/")!
+private let appHost = "www.corrientelebeche.es"
+// Host antiguo: se acepta durante la transición para no romper enlaces guardados.
+private let legacyHost = "pelotxo.synology.me"
+
+struct ContentView: View {
+    @StateObject private var model = WebViewModel()
+
+    var body: some View {
+        ZStack {
+            WebView(url: appURL, model: model)
+                .ignoresSafeArea()
+
+            if model.isLoading {
+                ProgressView()
+                    .progressViewStyle(.circular)
+            }
+
+            if let error = model.error {
+                VStack(spacing: 16) {
+                    Text("No se pudo cargar la Barrioteca")
+                        .font(.headline)
+                        .multilineTextAlignment(.center)
+                    Text(error.localizedDescription)
+                        .font(.footnote)
+                        .foregroundColor(.secondary)
+                        .multilineTextAlignment(.center)
+                    Button("Reintentar") {
+                        model.reload?()
+                    }
+                    .buttonStyle(.borderedProminent)
+                }
+                .padding(24)
+            }
+        }
+    }
+}
+
+final class WebViewModel: ObservableObject {
+    @Published var isLoading = true
+    @Published var error: Error?
+    var reload: (() -> Void)?
+}
+
+struct WebView: UIViewRepresentable {
+    let url: URL
+    @ObservedObject var model: WebViewModel
+
+    func makeCoordinator() -> Coordinator {
+        Coordinator()
+    }
+
+    func makeUIView(context: Context) -> WKWebView {
+        let config = WKWebViewConfiguration()
+        config.allowsInlineMediaPlayback = true
+
+        let prefs = WKWebpagePreferences()
+        prefs.allowsContentJavaScript = true
+        config.defaultWebpagePreferences = prefs
+
+        let webView = WKWebView(frame: .zero, configuration: config)
+        webView.uiDelegate = context.coordinator
+        webView.navigationDelegate = context.coordinator
+        webView.allowsBackForwardNavigationGestures = true
+        webView.scrollView.contentInsetAdjustmentBehavior = .always
+
+        context.coordinator.model = model
+        model.reload = { [weak webView] in
+            webView?.reload()
+        }
+        model.error = nil
+        model.isLoading = true
+        webView.load(URLRequest(url: url))
+        return webView
+    }
+
+    func updateUIView(_ webView: WKWebView, context: Context) {}
+
+    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate,
+        UIImagePickerControllerDelegate, UINavigationControllerDelegate {
+
+        weak var model: WebViewModel?
+        private var openPanelCompletion: (([URL]?) -> Void)?
+
+        // MARK: - Cámara (getUserMedia del escáner)
+
+        func webView(
+            _ webView: WKWebView,
+            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
+            initiatedByFrame frame: WKFrameInfo,
+            type: WKMediaCaptureType,
+            decisionHandler: @escaping (WKPermissionDecision) -> Void
+        ) {
+            // 🛡️ Sentinel: Only grant media capture to trusted hosts
+            if origin.host == appHost || origin.host == legacyHost {
+                decisionHandler(.grant)
+            } else {
+                decisionHandler(.deny)
+            }
+        }
+
+        // MARK: - Selector de archivo (botón "Foto" del escáner)
+
+        @available(iOS 18.4, *)
+        func webView(
+            _ webView: WKWebView,
+            runOpenPanelWith parameters: WKOpenPanelParameters,
+            initiatedByFrame frame: WKFrameInfo,
+            completionHandler: @escaping ([URL]?) -> Void
+        ) {
+            openPanelCompletion = completionHandler
+
+            guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
+                completionHandler(nil)
+                openPanelCompletion = nil
+                return
+            }
+
+            let picker = UIImagePickerController()
+            picker.sourceType = .photoLibrary
+            picker.delegate = self
+            picker.modalPresentationStyle = .fullScreen
+
+            let presenter = webView.window?.rootViewController
+            presenter?.present(picker, animated: true)
+        }
+
+        func imagePickerController(
+            _ picker: UIImagePickerController,
+            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
+        ) {
+            picker.dismiss(animated: true)
+            let url = info[.imageURL] as? URL
+            openPanelCompletion?(url.map { [$0] } ?? [])
+            openPanelCompletion = nil
+        }
+
+        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
+            picker.dismiss(animated: true)
+            openPanelCompletion?(nil)
+            openPanelCompletion = nil
+        }
+
+        // MARK: - Enlaces externos → Safari
+
+        func webView(
+            _ webView: WKWebView,
+            decidePolicyFor navigationAction: WKNavigationAction,
+            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
+        ) {
+            guard let url = navigationAction.request.url,
+                  navigationAction.navigationType == .linkActivated else {
+                decisionHandler(.allow)
+                return
+            }
+
+            if url.host == appHost || url.host == legacyHost || url.host == nil {
+                decisionHandler(.allow)
+            } else {
+                decisionHandler(.cancel)
+                UIApplication.shared.open(url)
+            }
+        }
+
+        func webView(
+            _ webView: WKWebView,
+            createWebViewWith configuration: WKWebViewConfiguration,
+            for navigationAction: WKNavigationAction,
+            windowFeatures: WKWindowFeatures
+        ) -> WKWebView? {
+            if let url = navigationAction.request.url, navigationAction.targetFrame == nil {
+                UIApplication.shared.open(url)
+            }
+            return nil
+        }
+
+        // MARK: - Progreso y errores
+
+        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
+            model?.isLoading = true
+            model?.error = nil
+        }
+
+        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
+            model?.isLoading = false
+        }
+
+        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
+            model?.isLoading = false
+            model?.error = error
+        }
+
+        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
+            model?.isLoading = false
+            model?.error = error
+        }
+    }
+}
+
+#Preview {
+    ContentView()
+}
```

## [2026-10-18 00:57] — PR #3: Palette: ProgressView accessibility & error view UX polish
> **Estado:** aplicado

- **Archivos afectados:** Barrioteca/Barrioteca/ContentView.swift
- **Motivo:** What: Added accessibility label and increased size for the loading ProgressView. Enhanced the error view with a system image icon on the 'Reintentar' button, and applied a regularMaterial background, corner radius, and shadow to create a clear overlay card. Why: Improves VoiceOver support for the loading state and makes the error state visually distinct and easier to read above the WebView. Accessibility: Added '.accessibilityLabel("Cargando la Barrioteca")' to the loading spinner.
- **Riesgo:** medio
- **Validación:** revisar con lector de pantalla / Lighthouse a11y

```diff
diff --git a/Barrioteca/Barrioteca/ContentView.swift b/Barrioteca/Barrioteca/ContentView.swift
index 05d193c..6403a07 100644
--- a/Barrioteca/Barrioteca/ContentView.swift
+++ b/Barrioteca/Barrioteca/ContentView.swift
@@ -1,201 +1,209 @@
-import SwiftUI
-import UIKit
-import WebKit
-
-private let appURL = URL(string: "https://www.corrientelebeche.es/barrioteca/")!
-private let appHost = "www.corrientelebeche.es"
-// Host antiguo: se acepta durante la transición para no romper enlaces guardados.
-private let legacyHost = "pelotxo.synology.me"
-
-struct ContentView: View {
-    @StateObject private var model = WebViewModel()
-
-    var body: some View {
-        ZStack {
-            WebView(url: appURL, model: model)
-                .ignoresSafeArea()
-
-            if model.isLoading {
-                ProgressView()
-                    .progressViewStyle(.circular)
-            }
-
-            if let error = model.error {
-                VStack(spacing: 16) {
-                    Text("No se pudo cargar la Barrioteca")
-                        .font(.headline)
-                        .multilineTextAlignment(.center)
-                    Text(error.localizedDescription)
-                        .font(.footnote)
-                        .foregroundColor(.secondary)
-                        .multilineTextAlignment(.center)
-                    Button("Reintentar") {
-                        model.reload?()
-                    }
-                    .buttonStyle(.borderedProminent)
-                }
-                .padding(24)
-            }
-        }
-    }
-}
-
-final class WebViewModel: ObservableObject {
-    @Published var isLoading = true
-    @Published var error: Error?
-    var reload: (() -> Void)?
-}
-
-struct WebView: UIViewRepresentable {
-    let url: URL
-    @ObservedObject var model: WebViewModel
-
-    func makeCoordinator() -> Coordinator {
-        Coordinator()
-    }
-
-    func makeUIView(context: Context) -> WKWebView {
-        let config = WKWebViewConfiguration()
-        config.allowsInlineMediaPlayback = true
-
-        let prefs = WKWebpagePreferences()
-        prefs.allowsContentJavaScript = true
-        config.defaultWebpagePreferences = prefs
-
-        let webView = WKWebView(frame: .zero, configuration: config)
-        webView.uiDelegate = context.coordinator
-        webView.navigationDelegate = context.coordinator
-        webView.allowsBackForwardNavigationGestures = true
-        webView.scrollView.contentInsetAdjustmentBehavior = .always
-
-        context.coordinator.model = model
-        model.reload = { [weak webView] in
-            webView?.reload()
-        }
-        model.error = nil
-        model.isLoading = true
-        webView.load(URLRequest(url: url))
-        return webView
-    }
-
-    func updateUIView(_ webView: WKWebView, context: Context) {}
-
-    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate,
-        UIImagePickerControllerDelegate, UINavigationControllerDelegate {
-
-        weak var model: WebViewModel?
-        private var openPanelCompletion: (([URL]?) -> Void)?
-
-        // MARK: - Cámara (getUserMedia del escáner)
-
-        func webView(
-            _ webView: WKWebView,
-            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
-            initiatedByFrame frame: WKFrameInfo,
-            type: WKMediaCaptureType,
-            decisionHandler: @escaping (WKPermissionDecision) -> Void
-        ) {
-            decisionHandler(.grant)
-        }
-
-        // MARK: - Selector de archivo (botón "Foto" del escáner)
-
-        @available(iOS 18.4, *)
-        func webView(
-            _ webView: WKWebView,
-            runOpenPanelWith parameters: WKOpenPanelParameters,
-            initiatedByFrame frame: WKFrameInfo,
-            completionHandler: @escaping ([URL]?) -> Void
-        ) {
-            openPanelCompletion = completionHandler
-
-            guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
-                completionHandler(nil)
-                openPanelCompletion = nil
-                return
-            }
-
-            let picker = UIImagePickerController()
-            picker.sourceType = .photoLibrary
-            picker.delegate = self
-            picker.modalPresentationStyle = .fullScreen
-
-            let presenter = webView.window?.rootViewController
-            presenter?.present(picker, animated: true)
-        }
-
-        func imagePickerController(
-            _ picker: UIImagePickerController,
-            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
-        ) {
-            picker.dismiss(animated: true)
-            let url = info[.imageURL] as? URL
-            openPanelCompletion?(url.map { [$0] } ?? [])
-            openPanelCompletion = nil
-        }
-
-        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
-            picker.dismiss(animated: true)
-            openPanelCompletion?(nil)
-            openPanelCompletion = nil
-        }
-
-        // MARK: - Enlaces externos → Safari
-
-        func webView(
-            _ webView: WKWebView,
-            decidePolicyFor navigationAction: WKNavigationAction,
-            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
-        ) {
-            guard let url = navigationAction.request.url,
-                  navigationAction.navigationType == .linkActivated else {
-                decisionHandler(.allow)
-                return
-            }
-
-            if url.host == appHost || url.host == legacyHost || url.host == nil {
-                decisionHandler(.allow)
-            } else {
-                decisionHandler(.cancel)
-                UIApplication.shared.open(url)
-            }
-        }
-
-        func webView(
-            _ webView: WKWebView,
-            createWebViewWith configuration: WKWebViewConfiguration,
-            for navigationAction: WKNavigationAction,
-            windowFeatures: WKWindowFeatures
-        ) -> WKWebView? {
-            if let url = navigationAction.request.url, navigationAction.targetFrame == nil {
-                UIApplication.shared.open(url)
-            }
-            return nil
-        }
-
-        // MARK: - Progreso y errores
-
-        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
-            model?.isLoading = true
-            model?.error = nil
-        }
-
-        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
-            model?.isLoading = false
-        }
-
-        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
-            model?.isLoading = false
-            model?.error = error
-        }
-
-        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
-            model?.isLoading = false
-            model?.error = error
-        }
-    }
-}
-
-#Preview {
-    ContentView()
-}
+import SwiftUI
+import UIKit
+import WebKit
+
+private let appURL = URL(string: "https://www.corrientelebeche.es/barrioteca/")!
+private let appHost = "www.corrientelebeche.es"
+// Host antiguo: se acepta durante la transición para no romper enlaces guardados.
+private let legacyHost = "pelotxo.synology.me"
+
+struct ContentView: View {
+    @StateObject private var model = WebViewModel()
+
+    var body: some View {
+        ZStack {
+            WebView(url: appURL, model: model)
+                .ignoresSafeArea()
+
+            if model.isLoading {
+                ProgressView()
+                    .progressViewStyle(.circular)
+                    .controlSize(.large)
+                    .accessibilityLabel("Cargando la Barrioteca")
+            }
+
+            if let error = model.error {
+                VStack(spacing: 16) {
+                    Text("No se pudo cargar la Barrioteca")
+                        .font(.headline)
+                        .multilineTextAlignment(.center)
+                    Text(error.localizedDescription)
+                        .font(.footnote)
+                        .foregroundColor(.secondary)
+                        .multilineTextAlignment(.center)
+                    Button(action: {
+                        model.reload?()
+                    }) {
+                        Label("Reintentar", systemImage: "arrow.clockwise")
+                    }
+                    .buttonStyle(.borderedProminent)
+                }
+                .padding(24)
+                .background(.regularMaterial)
+                .cornerRadius(16)
+                .shadow(radius: 10)
+                .padding(.horizontal, 32)
+            }
+        }
+    }
+}
+
+final class WebViewModel: ObservableObject {
+    @Published var isLoading = true
+    @Published var error: Error?
+    var reload: (() -> Void)?
+}
+
+struct WebView: UIViewRepresentable {
+    let url: URL
+    @ObservedObject var model: WebViewModel
+
+    func makeCoordinator() -> Coordinator {
+        Coordinator()
+    }
+
+    func makeUIView(context: Context) -> WKWebView {
+        let config = WKWebViewConfiguration()
+        config.allowsInlineMediaPlayback = true
+
+        let prefs = WKWebpagePreferences()
+        prefs.allowsContentJavaScript = true
+        config.defaultWebpagePreferences = prefs
+
+        let webView = WKWebView(frame: .zero, configuration: config)
+        webView.uiDelegate = context.coordinator
+        webView.navigationDelegate = context.coordinator
+        webView.allowsBackForwardNavigationGestures = true
+        webView.scrollView.contentInsetAdjustmentBehavior = .always
+
+        context.coordinator.model = model
+        model.reload = { [weak webView] in
+            webView?.reload()
+        }
+        model.error = nil
+        model.isLoading = true
+        webView.load(URLRequest(url: url))
+        return webView
+    }
+
+    func updateUIView(_ webView: WKWebView, context: Context) {}
+
+    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate,
+        UIImagePickerControllerDelegate, UINavigationControllerDelegate {
+
+        weak var model: WebViewModel?
+        private var openPanelCompletion: (([URL]?) -> Void)?
+
+        // MARK: - Cámara (getUserMedia del escáner)
+
+        func webView(
+            _ webView: WKWebView,
+            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
+            initiatedByFrame frame: WKFrameInfo,
+            type: WKMediaCaptureType,
+            decisionHandler: @escaping (WKPermissionDecision) -> Void
+        ) {
+            decisionHandler(.grant)
+        }
+
+        // MARK: - Selector de archivo (botón "Foto" del escáner)
+
+        @available(iOS 18.4, *)
+        func webView(
+            _ webView: WKWebView,
+            runOpenPanelWith parameters: WKOpenPanelParameters,
+            initiatedByFrame frame: WKFrameInfo,
+            completionHandler: @escaping ([URL]?) -> Void
+        ) {
+            openPanelCompletion = completionHandler
+
+            guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
+                completionHandler(nil)
+                openPanelCompletion = nil
+                return
+            }
+
+            let picker = UIImagePickerController()
+            picker.sourceType = .photoLibrary
+            picker.delegate = self
+            picker.modalPresentationStyle = .fullScreen
+
+            let presenter = webView.window?.rootViewController
+            presenter?.present(picker, animated: true)
+        }
+
+        func imagePickerController(
+            _ picker: UIImagePickerController,
+            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
+        ) {
+            picker.dismiss(animated: true)
+            let url = info[.imageURL] as? URL
+            openPanelCompletion?(url.map { [$0] } ?? [])
+            openPanelCompletion = nil
+        }
+
+        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
+            picker.dismiss(animated: true)
+            openPanelCompletion?(nil)
+            openPanelCompletion = nil
+        }
+
+        // MARK: - Enlaces externos → Safari
+
+        func webView(
+            _ webView: WKWebView,
+            decidePolicyFor navigationAction: WKNavigationAction,
+            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
+        ) {
+            guard let url = navigationAction.request.url,
+                  navigationAction.navigationType == .linkActivated else {
+                decisionHandler(.allow)
+                return
+            }
+
+            if url.host == appHost || url.host == legacyHost || url.host == nil {
+                decisionHandler(.allow)
+            } else {
+                decisionHandler(.cancel)
+                UIApplication.shared.open(url)
+            }
+        }
+
+        func webView(
+            _ webView: WKWebView,
+            createWebViewWith configuration: WKWebViewConfiguration,
+            for navigationAction: WKNavigationAction,
+            windowFeatures: WKWindowFeatures
+        ) -> WKWebView? {
+            if let url = navigationAction.request.url, navigationAction.targetFrame == nil {
+                UIApplication.shared.open(url)
+            }
+            return nil
+        }
+
+        // MARK: - Progreso y errores
+
+        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
+            model?.isLoading = true
+            model?.error = nil
+        }
+
+        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
+            model?.isLoading = false
+        }
+
+        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
+            model?.isLoading = false
+            model?.error = error
+        }
+
+        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
+            model?.isLoading = false
+            model?.error = error
+        }
+    }
+}
+
+#Preview {
+    ContentView()
+}
```

