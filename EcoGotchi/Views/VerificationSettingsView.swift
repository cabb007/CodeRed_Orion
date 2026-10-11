import SwiftUI

struct VerificationSettingsView: View {
    @EnvironmentObject private var store: HabitatStore
    @Environment(\.dismiss) private var dismiss
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
                         ? "Demo automatically accepts all three photos, adds 20 leaves, and clears one piece of habitat trash. No server or AI connection needed."
                         : "AI review sends the three photos to Gemini and awards leaves only after an approved review.")
                        .font(.subheadline)
                    Toggle("Scan sounds", isOn: $store.scanSounds)
                } header: { Text("Scan experience") } footer: {
                    Text("Success sounds respect your iPhone’s Silent Mode. Demo progress is saved; developer preview progress remains temporary.")
                }
                if !store.isDemoRecycling {
                    Section {
                        TextField("https://your-server.example", text: $address)
                            .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .accessibilityLabel("Review server address")
                            .disabled(testing)
                        if let directAddress = VerificationConnection.configuredDirectURL {
                            Button("Use this Mac’s direct address") { address = directAddress }
                                .disabled(testing)
                        }
                        SecureField("Server access token", text: $token)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .disabled(testing)
                    } header: { Text("Connect recycling review") } footer: {
                        Text("Use the address and access token from your EcoGotchi server. The direct address bypasses .local name lookup and is specific to the Mac’s current network. Your Gemini API key stays on the server.")
                    }
                    Section {
                        Button {
                            testing = true
                            error = nil
                            connectionMessage = nil
                            connectionTask = Task { @MainActor in
                                defer { testing = false }
                                do {
                                    let connection = try VerificationConnection(address: address, token: token)
                                    let result = try await connection.testConnection()
                                    try Task.checkCancellation()
                                    try connection.save()
                                    connectionMessage = result.reviewsRemaining > 0
                                        ? "Connected and saved. Your server has \(result.reviewsRemaining) AI reviews left in its daily budget. Tap Done to continue."
                                        : "Connected and saved, but the server’s daily AI review budget is used up. Try again later."
                                } catch is CancellationError { }
                                catch { self.error = error.localizedDescription }
                            }
                        } label: {
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
                        Text("Checks your server address and access token. No photos are sent and no Gemini tokens are used. This does not test Gemini’s photo review.")
                    }
                    Section {
                        Text("When you tap Send for review, your three photos go to this server and Google Gemini. Avoid faces and personal information. Photos aren’t added to your photo library or saved by EcoGotchi’s server; the server keeps review results and photo fingerprints to prevent repeat rewards. Google’s own data terms apply.")
                            .font(.subheadline)
                        Link("Google Gemini data terms", destination: URL(string: "https://ai.google.dev/gemini-api/terms")!)
                        Text("For a local demo, run the server on your Mac and connect it to your iPhone’s hotspot or the same trusted Wi-Fi. Use the .local address or the direct-address button. Allow EcoGotchi’s Local Network access. Local HTTP is unencrypted; use HTTPS for a hosted server.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Scan settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.tint(Palette.forest)
            .onChange(of: address) { _, _ in connectionMessage = nil; error = nil }
            .onChange(of: token) { _, _ in connectionMessage = nil; error = nil }
            .onDisappear { connectionTask?.cancel() }
    }
}
