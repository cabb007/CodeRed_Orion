import SwiftUI

struct VerificationSettingsView: View {
    @EnvironmentObject private var store: HabitatStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("ecogotchi.scanSounds") private var scanSounds = true
    @AppStorage(RecyclingReviewProvider.preferenceKey) private var provider = RecyclingReviewProvider.direct
    @State private var apiKey = GeminiDirectConnection.savedKey
    @State private var model = GeminiDirectConnection.savedModel
    @State private var address = VerificationConnection.savedURL
    @State private var token = VerificationConnection.savedToken
    @State private var error: String?
    @State private var connectionMessage: String?
    @State private var testing = false
    @State private var connectionTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Recycling mode", selection: $store.recyclingMode) {
                        ForEach(RecyclingMode.allCases) { mode in Text(mode.title).tag(mode) }
                    }.pickerStyle(.segmented).disabled(testing)
                    Text(store.isDemoRecycling
                         ? "Demo accepts the two photos automatically and adds 20 leaves. No internet needed."
                         : "Actual reviews your two photos with Gemini. Only approved reviews earn leaves.")
                        .font(.subheadline)
                    Toggle("Scan sounds", isOn: $scanSounds)
                } header: { Text("Scan experience") } footer: {
                    Text("Sounds respect Silent Mode. Rewards in developer preview stay temporary, including Actual reviews.")
                }
                if !store.isDemoRecycling {
                    Section {
                        Picker("AI connection", selection: $provider) {
                            ForEach(RecyclingReviewProvider.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented).disabled(testing)
                        Text(provider == .direct
                             ? "Connect straight to Gemini over Wi-Fi or cellular. Your Mac can be off."
                             : "Connect through your existing Recycli review server. A hosted HTTPS server also works away from your Mac.")
                            .font(.subheadline)
                    } header: { Text("Actual scans") }
                    if provider == .direct { directSettings }
                    else { serverSettings }
                    Section {
                        Button(action: testAndSave) {
                            HStack {
                                if testing { ProgressView() }
                                Text(testing ? "Checking connection…" : "Save & test connection")
                            }
                        }.disabled(testing).frame(minHeight: 44)
                        if let error { Text(error).foregroundStyle(.red) }
                        if let connectionMessage {
                            Label(connectionMessage, systemImage: "checkmark.circle").foregroundStyle(Palette.forest)
                        }
                    } footer: {
                        Text(provider == .direct
                             ? "Checks the key and model without sending photos or generating an AI response. Photo review and available quota are checked when you submit a scan."
                             : "Checks the server address and access token without sending photos or calling Gemini.")
                    }
                    Section {
                        Text(provider.uploadNotice).font(.subheadline)
                        Text(provider == .direct
                             ? "Submitted photos stay in memory while you return to your habitat. They are removed after a result or when you discard a failed scan; closing the app discards unfinished scans. This phone saves review results and photo fingerprints to prevent repeated rewards. It allows 30 review attempts per rolling 24 hours, including failures."
                             : "Recycli’s server keeps review results and photo fingerprints, but doesn’t save the photos. Server review limits apply.")
                            .font(.caption).foregroundStyle(.secondary)
                        Link("Google Gemini data terms", destination: URL(string: "https://ai.google.dev/gemini-api/terms")!)
                    } header: { Text("Your photos") }
                }
            }
            .navigationTitle("Scan settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.tint(Palette.forest)
            .onChange(of: address) { _, _ in clearMessages() }
            .onChange(of: token) { _, _ in clearMessages() }
            .onChange(of: apiKey) { _, _ in clearMessages() }
            .onChange(of: model) { _, _ in clearMessages() }
            .onChange(of: provider) { _, _ in clearMessages() }
            .onChange(of: store.recyclingMode) { _, _ in clearMessages() }
            .onDisappear { connectionTask?.cancel() }
    }

    private var directSettings: some View {
        Section {
            SecureField("Gemini API key", text: $apiKey)
                .textInputAutocapitalization(.never).autocorrectionDisabled().disabled(testing)
            Link("Get a Gemini API key", destination: URL(string: "https://aistudio.google.com/api-keys")!)
            Picker("Review speed", selection: $model) {
                Text("Quick").tag(GeminiDirectConnection.defaultModel)
                Text("Detailed").tag(GeminiDirectConnection.detailedModel)
                if model != GeminiDirectConnection.defaultModel && model != GeminiDirectConnection.detailedModel {
                    Text("Custom").tag(model)
                }
            }.disabled(testing)
            Text("Quick uses a lighter model and smaller uploads. Detailed keeps more image detail for difficult items or small signs. Save below to apply.")
                .font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("Advanced model settings") {
                TextField(GeminiDirectConnection.defaultModel, text: $model)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().disabled(testing)
                    .accessibilityLabel("Gemini model")
            }
            if !GeminiDirectConnection.savedKey.isEmpty {
                Button("Remove saved key", role: .destructive) {
                    do { try GeminiDirectConnection.removeKey(); apiKey = ""; clearMessages() }
                    catch { self.error = error.localizedDescription }
                }.disabled(testing)
            }
        } header: { Text("Your Gemini connection") } footer: {
            Text("Enter the key once on this iPhone. It stays in Keychain and isn’t bundled with the app. This option is for your private hackathon build; use a hosted server before distributing the app with shared credentials.")
        }
    }

    private var serverSettings: some View {
        Section {
            TextField("https://your-server.example", text: $address)
                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityLabel("Review server address").disabled(testing)
            if let directAddress = VerificationConnection.configuredDirectURL {
                Button("Use this Mac’s direct address") { address = directAddress }.disabled(testing)
            }
            SecureField("Server access token", text: $token)
                .textInputAutocapitalization(.never).autocorrectionDisabled().disabled(testing)
        } header: { Text("Review server") } footer: {
            Text("No cable is required. A local server needs your Mac awake on the same Wi-Fi or hotspot, with Local Network access allowed. Use On iPhone above to remove the Mac dependency entirely. The Gemini key stays on the server in this mode.")
        }
    }

    private func clearMessages() { connectionMessage = nil; error = nil }

    private func testAndSave() {
        guard !testing else { return }
        testing = true
        clearMessages()
        connectionTask = Task { @MainActor in
            defer { testing = false }
            do {
                if provider == .direct {
                    let connection = try GeminiDirectConnection(apiKey: apiKey, model: model)
                    try await connection.testConnection()
                    try Task.checkCancellation()
                    try connection.save()
                    connectionMessage = "Connected and saved. Actual scans can use this iPhone’s Wi-Fi or cellular connection. No Mac needed."
                } else {
                    let connection = try VerificationConnection(address: address, token: token)
                    let result = try await connection.testConnection()
                    try Task.checkCancellation()
                    try connection.save()
                    connectionMessage = result.reviewsRemaining > 0
                        ? "Connected and saved. Your server has \(result.reviewsRemaining) AI reviews left today."
                        : "Connected and saved, but the server’s daily review budget is used up. Try later."
                }
            } catch is CancellationError { }
            catch { self.error = error.localizedDescription }
        }
    }
}
