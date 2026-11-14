import Foundation
import SwiftSignalKit

public struct StoryAudience: Codable, Equatable {
    public var id: Int64
    public var name: String
    public var icon: String
    public var colorIndex: Int
    public var members: [Int64]
}

/// Local audience definitions. Server-facing clients can use the same definitions with
/// their privacy adapter; the offline demo stores them in its isolated account folder.
public final class StoryAudienceStore {
    private static var stores: [String: StoryAudienceStore] = [:]
    public static func forAccount(_ account: Account) -> StoryAudienceStore {
        if let store = stores[account.basePath] { return store }
        let store = StoryAudienceStore(path: account.basePath + "/story-audiences.json")
        stores[account.basePath] = store
        return store
    }
    public struct PublishedStory: Codable, Equatable {
        public var id: Int32
        public var audienceId: Int64?
        public var base: String
        public var members: [Int64]
    }
    public struct State: Codable, Equatable {
        public var audiences: [StoryAudience] = []
        public var selectedId: Int64?
        public var nextColorIndex: Int = 0
        public var stories: [PublishedStory] = []
    }
    public private(set) var value: State
    private let promise: ValuePromise<State>
    private let path: String
    public var updated: Signal<State, NoError> { self.promise.get() }
    public init(path: String) {
        self.path = path
        self.value = (try? Data(contentsOf: URL(fileURLWithPath: path))).flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
        var migrated = false
        for index in self.value.audiences.indices {
            let old = self.value.audiences[index].icon
            if old == "Travel" { self.value.audiences[index].icon = "Car"; migrated = true }
            if old == "Game" { self.value.audiences[index].icon = "Verified"; migrated = true }
        }
        self.promise = ValuePromise(self.value, ignoreRepeated: true)
        if migrated { commit() }
    }
    public func audience(_ id: Int64?) -> StoryAudience? { self.value.audiences.first { $0.id == id } }
    @discardableResult public func save(id: Int64?, name: String, icon: String, members: [Int64]) -> StoryAudience? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let old = audience(id)
        let item = StoryAudience(id: old?.id ?? Int64.random(in: 1 ... Int64.max), name: name, icon: icon, colorIndex: old?.colorIndex ?? value.nextColorIndex, members: Array(Set(members)).sorted())
        if let index = value.audiences.firstIndex(where: { $0.id == item.id }) { value.audiences[index] = item }
        else { value.audiences.append(item); value.nextColorIndex += 1 }
        if old == nil { value.selectedId = item.id }
        for i in value.stories.indices where value.stories[i].audienceId == item.id { value.stories[i].members = item.members }
        commit()
        return item
    }
    public func select(_ id: Int64?) { value.selectedId = audience(id)?.id; commit() }
    public func delete(_ id: Int64) {
        value.audiences.removeAll { $0.id == id }
        if value.selectedId == id { value.selectedId = nil }
        for i in value.stories.indices where value.stories[i].audienceId == id {
            value.stories[i].audienceId = nil; value.stories[i].base = "everyone"; value.stories[i].members = []
        }
        commit()
    }
    public func publish(id: Int32, base: String, members: [Int64]) {
        value.stories.removeAll { $0.id == id }
        value.stories.append(PublishedStory(id: id, audienceId: value.selectedId, base: base, members: members))
        commit()
    }
    public func changeStory(id: Int32, audienceId: Int64?, base: String, members: [Int64]) {
        guard let i = value.stories.firstIndex(where: { $0.id == id }) else { return }
        value.stories[i].audienceId = audienceId; value.stories[i].base = base; value.stories[i].members = members
        commit()
    }
    private func commit() {
        // Write atomically before notifying UI observers.
        if let data = try? JSONEncoder().encode(value) { try? data.write(to: URL(fileURLWithPath: path), options: .atomic) }
        promise.set(value)
    }
}
