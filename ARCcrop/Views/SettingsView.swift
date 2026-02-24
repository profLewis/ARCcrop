import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        NavigationStack {
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
                    NavigationLink {
                        APIKeysListView()
                    } label: {
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

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Build", value: "1")
                }
            }
            .navigationTitle("Settings")
            #if !os(tvOS)
            .toolbarTitleDisplayMode(.inline)
            #endif
        }
    }
}

// MARK: - API Keys List

struct APIKeysListView: View {
    @State private var refreshToken = UUID()

    var body: some View {
        Form {
            ForEach(APIKeyProvider.allCases, id: \.rawValue) { provider in
                NavigationLink {
                    APIKeySetupView(provider: provider, onSave: { refreshToken = UUID() })
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.rawValue)
                            Text(provider.usedBy)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
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
    @State private var isConfigured: Bool = false
    @State private var showDeleteConfirm = false
    @State private var showSavedToast = false

    var body: some View {
        Form {
            Section {
                if isConfigured {
                    Label("Configured", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Not Configured", systemImage: "xmark.circle")
                        .foregroundStyle(.secondary)
                }
            }

            Section("API Key") {
                SecureField("Enter API key or token", text: $keyText)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    #if !os(tvOS)
                    .textInputAutocapitalization(.never)
                    #endif

                Button("Save Key") {
                    if !keyText.isEmpty {
                        let _ = KeychainService.save(key: keyText, for: provider)
                        isConfigured = true
                        keyText = ""
                        showSavedToast = true
                        onSave?()
                    }
                }
                .disabled(keyText.isEmpty)

                if isConfigured {
                    Button("Delete Key", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }

            Section("Setup Instructions") {
                Text(provider.instructions)
                    .font(.callout)
            }

            Section("Sign Up") {
                Link(destination: URL(string: provider.signupURL)!) {
                    Label(provider.signupURL, systemImage: "safari")
                        .font(.callout)
                }
            }

            Section("Used By") {
                Text(provider.usedBy)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(provider.rawValue)
        #if !os(tvOS)
        .toolbarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            isConfigured = KeychainService.hasKey(for: provider)
        }
        .confirmationDialog("Delete API Key?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                let _ = KeychainService.delete(for: provider)
                isConfigured = false
                onSave?()
            }
        } message: {
            Text("This will remove the stored \(provider.rawValue) key. Sources using this key will become unavailable.")
        }
        .overlay {
            if showSavedToast {
                VStack {
                    Spacer()
                    Text("Key saved to Keychain")
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
}

#Preview {
    SettingsView()
        .environment(AppSettings.shared)
}
