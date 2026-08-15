import Security
import SwiftUI

struct TokenSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var serverURL = ""
    @State private var token = ""
    @State private var statusMessage: String?
    @State private var isSuccess = false
    @State private var isWorking = false

    private let service = "Timebase Activity API"
    private var account: String { URL(string: normalizedServerURL)?.host ?? normalizedServerURL }
    private var normalizedServerURL: String {
        serverURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Ajustes de Timebase").font(.title2.bold())
                Spacer()
                Button("Cerrar") { dismiss() }
            }

            Text("Configura el servidor y pega el token API. El token se guardará únicamente en el Llavero de este Mac.")
                .foregroundStyle(.secondary)

            TextField("URL de Timebase", text: $serverURL)
                .textFieldStyle(.roundedBorder)
            SecureField("Token API", text: $token)
                .textFieldStyle(.roundedBorder)

            if let statusMessage {
                Label(statusMessage, systemImage: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(isSuccess ? .green : .orange)
            }

            HStack {
                Spacer()
                Button(isWorking ? "Comprobando…" : "Guardar y comprobar") {
                    saveAndTest()
                }
                .buttonStyle(.borderedProminent)
                .disabled(normalizedServerURL.isEmpty || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func saveAndTest() {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              let url = URL(string: normalizedServerURL),
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              url.host != nil else {
            isSuccess = false
            statusMessage = "Introduce una URL válida, por ejemplo https://time.ejemplo.com."
            return
        }
        isWorking = true
        statusMessage = nil

        do {
            try saveToKeychain(value)
            TimebaseConfiguration.baseURL = normalizedServerURL
        } catch {
            isWorking = false
            isSuccess = false
            statusMessage = "No se pudo guardar el token: \(error.localizedDescription)"
            return
        }

        Task {
            do {
                _ = try await TimebaseAPIClient().projects()
                await MainActor.run {
                    token = ""
                    isWorking = false
                    isSuccess = true
                    statusMessage = "Conexión correcta. Token guardado."
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    isSuccess = false
                    statusMessage = "Token guardado, pero la conexión falló: \(error.localizedDescription)"
                }
            }
        }
    }

    private func saveToKeychain(_ value: String) throws {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attributes: [CFString: Any] = [kSecValueData: data]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData] = data
            item[kSecAttrLabel] = "Timebase Activity API Token"
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Error \(status)"
            throw NSError(domain: "TimebaseKeychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}
