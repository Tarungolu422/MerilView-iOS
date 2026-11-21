import SwiftUI

/// Settings view for PACS configuration, storage management, and diagnostics.
public struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var host: String
    @State private var port: String
    @State private var aeTitle: String
    @State private var callingAeTitle: String
    @State private var useSsl: Bool
    
    @State private var isTesting = false
    @State private var testResult: Bool?
    @State private var showCachePurgedAlert = false
    
    public init() {
        let cfg = PacsServerConfig()
        self._host = State(initialValue: cfg.host)
        self._port = State(initialValue: "\(cfg.port)")
        self._aeTitle = State(initialValue: cfg.aeTitle)
        self._callingAeTitle = State(initialValue: cfg.callingAeTitle)
        self._useSsl = State(initialValue: cfg.useSsl)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MerilTheme.background.ignoresSafeArea()
                
                Form {
                    Section(header: Text("PACS Server Connection").foregroundColor(MerilTheme.accent)) {
                        HStack {
                            Text("Host / IP Address")
                            Spacer()
                            TextField("127.0.0.1", text: $host)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(MerilTheme.accent)
                        }
                        
                        HStack {
                            Text("Port")
                            Spacer()
                            TextField("3001", text: $port)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .foregroundColor(MerilTheme.accent)
                        }
                        
                        HStack {
                            Text("Called AE Title")
                            Spacer()
                            TextField("MERIL_PACS", text: $aeTitle)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(MerilTheme.accent)
                        }
                        
                        HStack {
                            Text("Calling AE Title")
                            Spacer()
                            TextField("MERIL_VIEW_IOS", text: $callingAeTitle)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(MerilTheme.accent)
                        }
                        
                        Toggle("Use Secure TLS (HTTPS)", isOn: $useSsl)
                            .tint(MerilTheme.accent)
                        
                        Button(action: testConnection) {
                            HStack {
                                if isTesting {
                                    ProgressView().tint(MerilTheme.accent)
                                } else {
                                    Image(systemName: "network")
                                    Text("Test Connection")
                                }
                                
                                Spacer()
                                
                                if let res = testResult {
                                    Text(res ? "ONLINE" : "OFFLINE")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(res ? MerilTheme.success : MerilTheme.danger)
                                }
                            }
                        }
                    }
                    .listRowBackground(MerilTheme.surface)
                    
                    Section(header: Text("Memory & Storage Management").foregroundColor(MerilTheme.accent)) {
                        Button(action: {
                            MerilCacheManager.shared.clearAll()
                            MerilDicomDecoder.clearCache()
                            MerilMprReslicer.clearCache()
                            showCachePurgedAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Purge In-Memory Image Caches")
                            }
                            .foregroundColor(MerilTheme.warning)
                        }
                    }
                    .listRowBackground(MerilTheme.surface)
                    
                    Section(header: Text("Session & Account").foregroundColor(MerilTheme.accent)) {
                        Button(action: {
                            appState.isAuthenticated = false
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Logout Clinician")
                            }
                            .foregroundColor(MerilTheme.danger)
                        }
                    }
                    .listRowBackground(MerilTheme.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Workstation Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                    .foregroundColor(MerilTheme.accent)
                }
            }
            .alert("Caches Cleared", isPresented: $showCachePurgedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("All in-memory rendered slices, decoded raw pixels, and resliced MPR plates have been evicted.")
            }
        }
    }
    
    private func testConnection() {
        isTesting = true
        testResult = nil
        let portInt = Int(port) ?? 3001
        let newCfg = PacsServerConfig(host: host, port: portInt, aeTitle: aeTitle, callingAeTitle: callingAeTitle, useSsl: useSsl)
        appState.pacsClient.updateConfig(newCfg)
        
        Task {
            let ok = await appState.pacsClient.checkHealth()
            await MainActor.run {
                self.testResult = ok
                self.isTesting = false
            }
        }
    }
    
    private func saveSettings() {
        let portInt = Int(port) ?? 3001
        let newCfg = PacsServerConfig(host: host, port: portInt, aeTitle: aeTitle, callingAeTitle: callingAeTitle, useSsl: useSsl)
        appState.pacsClient.updateConfig(newCfg)
    }
}
