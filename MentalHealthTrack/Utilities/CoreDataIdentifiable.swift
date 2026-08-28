import CoreData

// ForEach(FetchedResults) がエンティティの id 属性を使えるようにする
extension PurchaseRecord: Identifiable {}
extension WatchEvent: Identifiable {}
extension SelfModel: Identifiable {}
extension MindfulnessData: Identifiable {}
