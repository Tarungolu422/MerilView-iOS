import SwiftUI
import LocalAuthentication

/// Clinical authentication view for medical practitioners.
public struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var username = "radiologist@meril.com"
    @State private var password = "••••••••"
    @State private var pacsHost = "127.0.0.1"
    @State private var pacsPort = "3001"
    @State private var isAuthenticating = false
    @State private var errorMessage: String?
    
    public init() {}
    
    public var body: some View {
        ZStack {
            MerilTheme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    // Meril Logo & Brand
                    VStack(spacing: 10) {
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 54))
                            .foregroundColor(MerilTheme.accent)
                        
                        Text("MERILVIEW")
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .foregroundColor(MerilTheme.textPrimary)
                            .tracking(2.0)
                        
                        Text("Clinical DICOM & 3D MPR Workstation")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(MerilTheme.textSecondary)
                    }
                    .padding(.top, 40)
                    
                    // Login Card
                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Clinician ID / Email")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(MerilTheme.textSecondary)
                            TextField("Clinician ID", text: $username)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding()
                                .background(MerilTheme.surface)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(MerilTheme.border, lineWidth: 1))
                                .foregroundColor(MerilTheme.textPrimary)
                                .autocapitalization(.none)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(MerilTheme.textSecondary)
                            SecureField("Password", text: $password)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding()
                                .background(MerilTheme.surface)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(MerilTheme.border, lineWidth: 1))
                                .foregroundColor(MerilTheme.textPrimary)
                        }
                        
                        // PACS Host Quick Settings
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PACS Host")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(MerilTheme.textMuted)
                                TextField("127.0.0.1", text: $pacsHost)
                                    .font(.system(size: 13, design: .monospaced))
                                    .padding(8)
                                    .background(MerilTheme.surface)
                                    .cornerRadius(6)
                                    .foregroundColor(MerilTheme.textSecondary)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Port")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(MerilTheme.textMuted)
                                TextField("3001", text: $pacsPort)
                                    .font(.system(size: 13, design: .monospaced))
                                    .frame(width: 80)
                                    .padding(8)
                                    .background(MerilTheme.surface)
                                    .cornerRadius(6)
                                    .foregroundColor(MerilTheme.textSecondary)
                            }
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(MerilTheme.danger)
                        }
                        
                        // Sign In Button
                        Button(action: handleLogin) {
                            HStack {
                                if isAuthenticating {
                                    ProgressView().tint(MerilTheme.background)
                                } else {
                                    Text("Authenticate Clinician")
                                        .font(.system(size: 15, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(MerilTheme.accent)
                            .foregroundColor(MerilTheme.background)
                            .cornerRadius(10)
                        }
                        .disabled(isAuthenticating)
                        
                        // Biometric Login Button
                        Button(action: handleBiometricAuth) {
                            HStack(spacing: 8) {
                                Image(systemName: "faceid")
                                    .font(.system(size: 18))
                                Text("Sign In with Face ID / Touch ID")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(MerilTheme.accent)
                            .padding(.vertical, 8)
                        }
                        
                        Divider().background(MerilTheme.border)
                        
                        // Offline Clinical Mode Bypass
                        Button(action: {
                            appState.isAuthenticated = true
                        }) {
                            Text("Work Offline (Local Storage & PACS Cache)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(MerilTheme.textSecondary)
                        }
                    }
                    .padding(24)
                    .background(MerilTheme.surface.opacity(0.8))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(MerilTheme.border, lineWidth: 1))
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    private func handleLogin() {
        isAuthenticating = true
        errorMessage = nil
        
        let portInt = Int(pacsPort) ?? 3001
        appState.pacsClient.updateConfig(PacsServerConfig(host: pacsHost, port: portInt))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isAuthenticating = false
            appState.isAuthenticated = true
        }
    }
    
    private func handleBiometricAuth() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to access MerilView clinical studies") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        appState.isAuthenticated = true
                    }
                }
            }
        } else {
            // Simulator or device without biometrics fallback
            appState.isAuthenticated = true
        }
    }
}
