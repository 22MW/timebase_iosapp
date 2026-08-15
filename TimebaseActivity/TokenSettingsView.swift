import Security
import SwiftUI

struct TokenSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var statusMessage: String?
    @State private var isSuccess = false
    @State private var isWorking = false

    private let service = "Timebase Activity API"
    private let account = "time.22mw.online"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Ajustes de Timebase").font(.title2.bold())
                Spacer()
                Button("Cerrar") { dismiss() }
            }

            Text("Pega el token API de Timebase. Se guardará únicamente en el Llavero de este Mac.")
                .foregroundStyle(.secondary)

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
                .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func saveAndTest() {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        isWorking = true
        statusMessage = nil

        do {
            try saveToKeychain(value)
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
