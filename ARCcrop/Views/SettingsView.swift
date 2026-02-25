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
    @State private var showKey = false

    var body: some View {
        Form {
            // MARK: Status
            Section {
                if isConfigured {
                    Label("Key configured — ready to use", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("No key stored — follow the steps below", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Status")
            } footer: {
                Text("Used by: \(provider.usedBy)")
            }

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
                Text((try? AttributedString(markdown: provider.instructions)) ?? AttributedString(provider.instructions))
                    .font(.callout)
                    .tint(.blue)
                Link(destination: URL(string: provider.signupURL)!) {
                    Label("Open Credentials Page", systemImage: "safari")
                }
            } header: {
                Text("Step 2 — Generate API Key")
            } footer: {
                Text("Copy the key/token to your clipboard, then come back to this app.")
            }

            // MARK: Step 3
            Section {
                Text("After copying your key in Safari, switch back to this app and tap \"Paste from Clipboard\" below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                #if !os(tvOS)
                if showKey {
                    TextField("Paste your API key here", text: $keyText, axis: .vertical)
                        .lineLimit(1...6)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.system(.callout, design: .monospaced))
                } else {
                    SecureField("Paste your API key here", text: $keyText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Toggle("Show key text", isOn: $showKey)
                    .font(.callout)
                #else
                TextField("Paste your API key here", text: $keyText, axis: .vertical)
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

                Button {
                    guard !keyText.isEmpty else { return }
                    let _ = KeychainService.save(key: keyText, for: provider)
                    isConfigured = true
                    keyText = ""
                    showKey = false
                    showSavedToast = true
                    onSave?()
                } label: {
                    Label("Save Key to Keychain", systemImage: "square.and.arrow.down")
                        .bold()
                }
                .disabled(keyText.isEmpty)

                if isConfigured {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Stored Key", systemImage: "trash")
                    }
                }
            } header: {
                Text("Step 3 — Paste & Save")
            } footer: {
                Text("Your key is stored securely in the iOS Keychain and persists across app updates.")
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
