import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Form {
                Section("EO Data Sources") {
                    ForEach(EODataSource.allCases) { source in
                        Toggle(source.displayName, isOn: Binding(
                            get: { settings.enabledSources[source] ?? false },
                            set: { settings.enabledSources[source] = $0 }
                        ))
                    }
                }

                Section("Display") {
                    @Bindable var settings = settings
                    Picker("Vegetation Index", selection: $settings.vegetationIndex) {
                        ForEach(VegetationIndex.allCases) { index in
                            Text(index.rawValue).tag(index)
                        }
                    }
                }

                Section {
                    NavigationLink(value: SettingsDestination.apiKeysList) {
                        HStack {
                            Label("Crop Map API Keys", systemImage: "key.fill")
                            Spacer()
                            let configured = APIKeyProvider.allCases.filter { KeychainService.hasKey(for: $0) }.count
                            Text("\(configured)/\(APIKeyProvider.allCases.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("GEOGLAM and USDA CDL require no API keys.")
                }

                #if !os(tvOS)
                Section("Tile Cache") {
                    @Bindable var settings = settings
                    HStack {
                        Text("Disk limit")
                        Spacer()
                        Stepper(settings.cacheSizeMB >= 1024 ? String(format: "%.1f GB", Double(settings.cacheSizeMB) / 1024) : "\(settings.cacheSizeMB) MB",
                                value: $settings.cacheSizeMB, in: 256...5120, step: 256)
                    }
                    let usedMB = Double(WMSTileOverlay.tileCache.currentDiskUsage) / (1024 * 1024)
                    let capMB = Double(WMSTileOverlay.tileCache.diskCapacity) / (1024 * 1024)
                    LabeledContent("Disk usage", value: String(format: "%.1f / %.0f MB", usedMB, capMB))
                    let memMB = Double(WMSTileOverlay.tileCache.currentMemoryUsage) / (1024 * 1024)
                    LabeledContent("Memory usage", value: String(format: "%.1f MB", memMB))
                    Button("Clear Cache") {
                        WMSTileOverlay.tileCache.removeAllCachedResponses()
                    }
                }
                #endif

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Build", value: "1")
                }
            }
            .navigationTitle("Settings")
            #if !os(tvOS)
            .toolbarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(for: SettingsDestination.self) { dest in
                switch dest {
                case .apiKeysList:
                    APIKeysListView()
                case .apiKeySetup(let provider):
                    APIKeySetupView(provider: provider) {
                        // After saving, apply the pending source and go back to the map
                        if let pending = settings.pendingCropMapSource, pending.isAvailable {
                            settings.selectedCropMap = pending
                        }
                        settings.pendingCropMapSource = nil
                        settings.apiKeySetupProvider = nil
                        settings.selectedTab = .map
                    }
                }
            }
            .onAppear {
                // Deep-link: if the map sent us here for a specific provider, navigate straight in
                if let provider = settings.apiKeySetupProvider {
                    navigationPath = NavigationPath([SettingsDestination.apiKeySetup(provider)])
                }
            }
            .onChange(of: settings.apiKeySetupProvider) {
                if let provider = settings.apiKeySetupProvider {
                    navigationPath = NavigationPath([SettingsDestination.apiKeySetup(provider)])
                }
            }
        }
    }
}

enum SettingsDestination: Hashable {
    case apiKeysList
    case apiKeySetup(APIKeyProvider)
}

// MARK: - API Keys List

struct APIKeysListView: View {
    @State private var refreshToken = UUID()

    var body: some View {
        Form {
            ForEach(APIKeyProvider.allCases, id: \.rawValue) { provider in
                NavigationLink(value: SettingsDestination.apiKeySetup(provider)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.rawValue)
                            Text(provider.usedBy)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        switch provider.credentialType {
                        case .none:
                            Text("Public")
                                .font(.caption)
                                .foregroundStyle(.green)
                        case .apiKey, .usernamePassword:
                            if KeychainService.hasKey(for: provider) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("API Keys")
        .id(refreshToken)
        #if !os(tvOS)
        .toolbarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Single API Key Setup

struct APIKeySetupView: View {
    let provider: APIKeyProvider
    var onSave: (() -> Void)?

    @State private var keyText: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isConfigured: Bool = false
    @State private var showDeleteConfirm = false
    @State private var showSavedToast = false
    @State private var showKey = false

    var body: some View {
        Form {
            // MARK: Status
            Section {
                if provider.credentialType == .none {
                    Label("No credentials needed — public access", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if isConfigured {
                    Label("Configured — ready to use", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Not configured — follow the steps below", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Status")
            } footer: {
                Text("Used by: \(provider.usedBy)")
            }

            // MARK: Instructions
            Section {
                Text((try? AttributedString(markdown: provider.instructions)) ?? AttributedString(provider.instructions))
                    .font(.callout)
                    .tint(.blue)
            } header: {
                Text("About")
            }

            // MARK: Credential entry (skip for .none)
            if provider.credentialType != .none {

                // MARK: Step 1
                Section {
                    Link(destination: URL(string: provider.registrationURL)!) {
                        Label("Open Registration Page", systemImage: "safari")
                    }
                } header: {
                    Text("Step 1 — Create an Account")
                } footer: {
                    Text(provider.registrationHint)
                }

                // MARK: Step 2
                Section {
                    Link(destination: URL(string: provider.signupURL)!) {
                        Label("Open Credentials Page", systemImage: "safari")
                    }
                } header: {
                    Text("Step 2 — Get Credentials")
                } footer: {
                    if provider.credentialType == .usernamePassword {
                        Text("You will need your username and password.")
                    } else {
                        Text("Copy the key/token, then come back to this app.")
                    }
                }

                // MARK: Step 3 — credential input
                Section {
                    switch provider.credentialType {
                    case .apiKey:
                        apiKeyEntryView
                    case .usernamePassword:
                        usernamePasswordEntryView
                    case .none:
                        EmptyView()
                    }

                    Button {
                        saveCredentials()
                    } label: {
                        Label("Save to Keychain", systemImage: "square.and.arrow.down")
                            .bold()
                    }
                    .disabled(!canSave)

                    if isConfigured {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Stored Credentials", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("Step 3 — Enter & Save")
                } footer: {
                    Text("Stored securely in the iOS Keychain. Persists across app updates.")
                }
            }

            // MARK: Help
            Section("Documentation") {
                Link(destination: URL(string: provider.documentationURL)!) {
                    Label("API Documentation", systemImage: "doc.text")
                }
            }
        }
        .navigationTitle(provider.rawValue)
        #if !os(tvOS)
        .toolbarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            isConfigured = KeychainService.hasKey(for: provider)
            // Pre-fill username if already stored
            if provider.credentialType == .usernamePassword,
               let keys = provider.credentialKeys.first,
               let stored = KeychainService.retrieve(key: keys) {
                username = stored
            }
        }
        .confirmationDialog("Delete Credentials?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                let _ = KeychainService.delete(for: provider)
                isConfigured = false
                username = ""
                password = ""
                keyText = ""
                onSave?()
            }
        } message: {
            Text("This will remove the stored \(provider.rawValue) credentials. Sources using them will become unavailable.")
        }
        .overlay {
            if showSavedToast {
                VStack {
                    Spacer()
                    Text("Saved to Keychain")
                        .font(.callout.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.green.opacity(0.9))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showSavedToast = false
                    }
                }
            }
        }
    }

    // MARK: - API Key entry

    @ViewBuilder
    private var apiKeyEntryView: some View {
        Text("After copying your key in Safari, switch back here and tap \"Paste from Clipboard\".")
            .font(.callout)
            .foregroundStyle(.secondary)

        #if !os(tvOS)
        if showKey {
            TextField("API key or token", text: $keyText, axis: .vertical)
                .lineLimit(1...6)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(.callout, design: .monospaced))
        } else {
            SecureField("API key or token", text: $keyText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        Toggle("Show key text", isOn: $showKey)
            .font(.callout)
        #else
        TextField("API key or token", text: $keyText, axis: .vertical)
            .lineLimit(1...6)
            .autocorrectionDisabled()
            .font(.system(.callout, design: .monospaced))
        #endif

        Button {
            if let pasted = UIPasteboard.general.string, !pasted.isEmpty {
                keyText = pasted
            }
        } label: {
            Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
        }
    }

    // MARK: - Username/Password entry

    @ViewBuilder
    private var usernamePasswordEntryView: some View {
        #if !os(tvOS)
        TextField("Username or email", text: $username)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .textContentType(.username)
        SecureField("Password", text: $password)
            .textContentType(.password)
        #else
        TextField("Username or email", text: $username)
            .autocorrectionDisabled()
        SecureField("Password", text: $password)
        #endif
    }

    // MARK: - Save logic

    private var canSave: Bool {
        switch provider.credentialType {
        case .apiKey: !keyText.isEmpty
        case .usernamePassword: !username.isEmpty && !password.isEmpty
        case .none: false
        }
    }

    private func saveCredentials() {
        switch provider.credentialType {
        case .apiKey:
            guard !keyText.isEmpty else { return }
            KeychainService.store(key: provider.credentialKeys[0], value: keyText)
            keyText = ""
            showKey = false
        case .usernamePassword:
            guard !username.isEmpty, !password.isEmpty else { return }
            let keys = provider.credentialKeys
            KeychainService.store(key: keys[0], value: username)
            KeychainService.store(key: keys[1], value: password)
            password = ""
        case .none:
            return
        }
        isConfigured = true
        showSavedToast = true
        onSave?()
    }
}

#Preview {
    SettingsView()
        .environment(AppSettings.shared)
}
