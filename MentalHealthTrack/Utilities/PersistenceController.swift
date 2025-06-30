import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()
    
    // プレビュー用（SwiftUIプレビューで使用）
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // プレビュー用のサンプルデータを作成
        let sampleEntry = MindfulnessData(context: viewContext)
        sampleEntry.id = UUID()
        sampleEntry.timestamp = Date()
        sampleEntry.activity = "読書をしていました"
        sampleEntry.mood = "😊"
        sampleEntry.feelings = "とてもリラックスできて良い時間でした"
        
        let sampleEntry2 = MindfulnessData(context: viewContext)
        sampleEntry2.id = UUID()
        sampleEntry2.timestamp = Calendar.current.date(byAdding: .hour, value: -1, to: Date())
        sampleEntry2.activity = "散歩をしていました"
        sampleEntry2.mood = "🙂"
        sampleEntry2.feelings = "新鮮な空気を吸って気分転換になりました"
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        // ⚠️ 重要：ここの名前は MindfulnessDataModel.xcdatamodeld のファイル名と一致させる
        container = NSPersistentContainer(name: "MindfulnessDataModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Core Dataストアを読み込み
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // 本番環境では適切なエラーハンドリングを実装
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        // 自動マージを有効にする（バックグラウンドでの変更を自動的に反映）
        container.viewContext.automaticallyMergesChangesFromParent = true

        // リアルタイム更新のための設定
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // 変更通知を有効にする
        container.viewContext.stalenessInterval = 0
    }
}
