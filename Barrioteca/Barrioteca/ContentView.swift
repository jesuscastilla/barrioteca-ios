import SwiftUI
import UIKit
import WebKit

private let appURL = URL(string: "https://www.corrientelebeche.es/barrioteca/")!
private let appHost = "www.corrientelebeche.es"
// Host antiguo: se acepta durante la transición para no romper enlaces guardados.
private let legacyHost = "pelotxo.synology.me"

struct ContentView: View {
    @StateObject private var model = WebViewModel()

    var body: some View {
        ZStack {
            WebView(url: appURL, model: model)
                .ignoresSafeArea()

            if model.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            }

            if let error = model.error {
                VStack(spacing: 16) {
                    Text("No se pudo cargar la Barrioteca")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text(error.localizedDescription)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Reintentar") {
                        model.reload?()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
            }
        }
    }
}

final class WebViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var error: Error?
    var reload: (() -> Void)?
}

struct WebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var model: WebViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)

        // ⚡ Bolt: Performance optimization
        // Eliminates alpha blending overhead for the GPU by ensuring the view is opaque.
        // This speeds up the rendering pass, especially during scrolling.
        webView.isOpaque = true
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground

        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .always

        context.coordinator.model = model
        model.reload = { [weak webView] in
            webView?.reload()
        }

        // ⚡ Bolt: Prevent unnecessary re-renders
        // Only trigger @Published state changes if the values actually changed
        if model.error != nil {
            model.error = nil
        }
        if !model.isLoading {
            model.isLoading = true
        }

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate,
        UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        weak var model: WebViewModel?
        private var openPanelCompletion: (([URL]?) -> Void)?

        // MARK: - Cámara (getUserMedia del escáner)

        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            decisionHandler(.grant)
        }

        // MARK: - Selector de archivo (botón "Foto" del escáner)

        @available(iOS 18.4, *)
        func webView(
            _ webView: WKWebView,
            runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping ([URL]?) -> Void
        ) {
            openPanelCompletion = completionHandler

            guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
                completionHandler(nil)
                openPanelCompletion = nil
                return
            }

            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.modalPresentationStyle = .fullScreen

            let presenter = webView.window?.rootViewController
            presenter?.present(picker, animated: true)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            let url = info[.imageURL] as? URL
            openPanelCompletion?(url.map { [$0] } ?? [])
            openPanelCompletion = nil
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            openPanelCompletion?(nil)
            openPanelCompletion = nil
        }

        // MARK: - Enlaces externos → Safari

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url,
                  navigationAction.navigationType == .linkActivated else {
                decisionHandler(.allow)
                return
            }

            if url.host == appHost || url.host == legacyHost || url.host == nil {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
                UIApplication.shared.open(url)
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url, navigationAction.targetFrame == nil {
                UIApplication.shared.open(url)
            }
            return nil
        }

        // MARK: - Progreso y errores

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // ⚡ Bolt: Prevent unnecessary SwiftUI view re-renders
            if model?.isLoading != true {
                model?.isLoading = true
            }
            if model?.error != nil {
                model?.error = nil
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // ⚡ Bolt: Prevent unnecessary SwiftUI view re-renders
            if model?.isLoading != false {
                model?.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // ⚡ Bolt: Prevent unnecessary SwiftUI view re-renders
            if model?.isLoading != false {
                model?.isLoading = false
            }
            model?.error = error
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            // ⚡ Bolt: Prevent unnecessary SwiftUI view re-renders
            if model?.isLoading != false {
                model?.isLoading = false
            }
            model?.error = error
        }
    }
}

#Preview {
    ContentView()
}
