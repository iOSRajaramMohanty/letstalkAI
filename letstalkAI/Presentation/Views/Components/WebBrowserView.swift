//
//  WebBrowserView.swift
//  letstalkAI
//
//  In-app web browser for viewing sources - Cross-platform (iOS/macOS)
//

import SwiftUI
import WebKit

struct WebBrowserView: View {
    let url: URL
    
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var pageTitle = ""
    @State private var canGoBack = false
    @State private var canGoForward = false
    
    @State private var webViewNavigator = WebViewNavigator()
    
    var body: some View {
        NavigationStack {
            ZStack {
                WebViewWrapper(
                    url: url,
                    navigator: webViewNavigator,
                    isLoading: $isLoading,
                    pageTitle: $pageTitle,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward
                )
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        #if os(iOS)
                        .background(Color(.systemBackground).opacity(0.5))
                        #elseif os(macOS)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                        #endif
                }
            }
            .navigationTitle(pageTitle.isEmpty ? "Loading..." : pageTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .bottomBar) {
                    navigationButtons
                }
            }
            #elseif os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .primaryAction) {
                    navigationButtons
                }
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 400)
        #endif
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            Button {
                webViewNavigator.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!canGoBack)
            
            Button {
                webViewNavigator.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!canGoForward)
            
            Button {
                webViewNavigator.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            
            ShareLink(item: url) {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }
}

class WebViewNavigator: ObservableObject {
    var webView: WKWebView?
    
    func goBack() {
        webView?.goBack()
    }
    
    func goForward() {
        webView?.goForward()
    }
    
    func reload() {
        webView?.reload()
    }
}

// MARK: - iOS WebView Wrapper

#if os(iOS)
struct WebViewWrapper: UIViewRepresentable {
    let url: URL
    let navigator: WebViewNavigator
    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        navigator.webView = webView
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewWrapper
        
        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.pageTitle = webView.title ?? ""
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}
#endif

// MARK: - macOS WebView Wrapper

#if os(macOS)
struct WebViewWrapper: NSViewRepresentable {
    let url: URL
    let navigator: WebViewNavigator
    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        navigator.webView = webView
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewWrapper
        
        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.pageTitle = webView.title ?? ""
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}
#endif
