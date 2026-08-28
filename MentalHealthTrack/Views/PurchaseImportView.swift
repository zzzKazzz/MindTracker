import SwiftUI
import UniformTypeIdentifiers

// 注文確認メール（本文ペースト or .eml/.txt ファイル）から購入記録を取り込む。
// 解析はすべて端末内。メール本文を外部に送信しない。
struct PurchaseImportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var emailText = ""
    @State private var parsedPurchases: [ParsedPurchase] = []
    @State private var hasParsed = false
    @State private var showingFileImporter = false
    @State private var importError: String?

    private let categories = ["食品・飲料", "ファッション", "電子機器", "本・雑誌", "日用品", "趣味・娯楽", "その他"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    inputSection

                    if hasParsed {
                        resultSection
                    }
                }
                .padding()
            }
            .navigationTitle("メールから取り込み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { saveAll() }
                        .disabled(parsedPurchases.isEmpty)
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: allowedTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("読み込みエラー", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private var allowedTypes: [UTType] {
        var types: [UTType] = [.plainText, .text]
        if let eml = UTType(filenameExtension: "eml") {
            types.append(eml)
        }
        return types
    }

    // MARK: - Sections

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("注文確認メールの本文を貼り付けるか、ファイルを読み込んでください。解析は端末内だけで行われます。")
                .font(.caption)
                .foregroundColor(.secondary)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $emailText)
                    .frame(minHeight: 160)
                    .padding(8)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(UIColor.systemGray5), lineWidth: 1)
                    )

                if emailText.isEmpty {
                    Text("ここにメール本文を貼り付け")
                        .foregroundColor(Color(UIColor.placeholderText))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 12) {
                Button(action: { showingFileImporter = true }) {
                    Label("ファイルを読み込む", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }

                Button(action: parseText) {
                    Label("解析する", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(emailText.isEmpty ? Color.gray.opacity(0.2) : Color.blue)
                        .foregroundColor(emailText.isEmpty ? .secondary : .white)
                        .cornerRadius(10)
                }
                .disabled(emailText.isEmpty)
            }
        }
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("検出された購入")
                    .font(.headline)
                Spacer()
                Text("\(parsedPurchases.count)件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if parsedPurchases.isEmpty {
                Text("購入が見つかりませんでした。本文に商品名と金額（¥1,234 や 1,234円）が含まれているか確認してください。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }

            ForEach($parsedPurchases) { $purchase in
                VStack(spacing: 10) {
                    HStack {
                        TextField("商品名", text: $purchase.name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(action: { removePurchase(purchase.id) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }

                    HStack {
                        TextField("価格", value: $purchase.price, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .frame(width: 110)

                        Picker("カテゴリ", selection: $purchase.category) {
                            ForEach(categories, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(MenuPickerStyle())

                        Spacer()

                        Text(purchase.merchant)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    DatePicker("購入日", selection: $purchase.purchasedAt, displayedComponents: .date)
                        .font(.caption)
                }
                .padding(12)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Actions

    private func parseText() {
        parsedPurchases = PurchaseEmailParser.parse(emailText)
        hasParsed = true
    }

    private func removePurchase(_ id: UUID) {
        parsedPurchases.removeAll { $0.id == id }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url) else {
                importError = "ファイルを読み込めませんでした。"
                return
            }
            // UTF-8 → Shift_JIS → ISO-2022-JP の順で試す
            let encodings: [String.Encoding] = [.utf8, .shiftJIS, .iso2022JP]
            guard let text = encodings.lazy.compactMap({ String(data: data, encoding: $0) }).first else {
                importError = "テキストとして解釈できないファイルです。"
                return
            }
            emailText = text
            parseText()
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func saveAll() {
        for purchase in parsedPurchases {
            let record = PurchaseRecord(context: viewContext)
            record.id = UUID()
            record.name = purchase.name
            record.price = purchase.price
            record.category = purchase.category
            record.merchant = purchase.merchant
            record.purchasedAt = purchase.purchasedAt
            record.sourceRaw = nil // 本文は保存しない。抽出結果のみ残す
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            importError = "保存に失敗しました: \(error.localizedDescription)"
        }
    }
}

#Preview {
    PurchaseImportView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
