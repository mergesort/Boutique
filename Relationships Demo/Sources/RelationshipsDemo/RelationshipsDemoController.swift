import Boutique
import SwiftUI
import UIKit

@Observable
final class RelationshipsDemoController {
    @MainActor
    static let shared = RelationshipsDemoController()

    @ObservationIgnored
    @Stored(in: .notesStore) var notes: [Note]

    @ObservationIgnored
    @Stored(in: .tagsStore) var tags: [Tag]

    @ObservationIgnored
    @Stored(in: .actionLogStore) var actions: [ActionLog]

    var selectedTagID: String?
    private var noteIndex = 0
    private var tagIndex = 0
    private var updateIndex = 0
    private var logTail: Task<Void, Never>?
    #if DEBUG
    private var hasRunSelfTest = false
    #endif

    init(notesStore: Store<Note> = .notesStore, tagsStore: Store<Tag> = .tagsStore, actionLogStore: Store<ActionLog> = .actionLogStore) {
        self._notes = Stored(in: notesStore)
        self._tags = Stored(in: tagsStore)
        self._actions = Stored(in: actionLogStore)

        self.$tags.addRelationship(updating: \.tags, in: self.$notes)
        self.$tags.addRelationship(updating: \.primaryTag, in: self.$notes)
        self.$tags.addRelationship(clearing: \.tags, in: self.$notes)
        self.$tags.addRelationship(nullifying: \.primaryTag, in: self.$notes)
        self.$tags.addRelationship(to: self.$notes, on: .update) { [weak self] changes, notesStore in
            await self?.logAndWait("Custom update relationship observed \(changes.count) tag change(s) across \(notesStore.items.count) note(s)")
        }
        self.$tags.addRelationship(to: self.$notes, on: .remove) { [weak self] changes, notesStore in
            await self?.logAndWait("Custom remove relationship observed \(changes.count) removed tag(s) across \(notesStore.items.count) note(s)")
        }

        self.log("Initialized relationship stores and registered update, clear, and nullify relationships")
    }

    func addNote() async throws {
        let text = DemoContent.noteTexts[self.noteIndex % DemoContent.noteTexts.count]
        self.noteIndex += 1

        let note = Note.make(text: text)
        try await self.$notes.insert(note)
        await self.logAndWait("Added note \(note.id) text=\"\(note.text)\"")
    }

    func addTag() async throws {
        guard let nextTag = self.nextAvailableTagSeed() else {
            await self.logAndWait("Skipped adding tag because all predefined tag names are already in use")
            return
        }

        self.tagIndex = nextTag.nextIndex

        let tag = Tag.make(title: nextTag.title, colorHex: nextTag.colorHex)
        try await self.$tags.insert(tag)
        self.selectedTagID = tag.id
        await self.logAndWait("Added tag \(tag.id) title=\"\(tag.title)\" and selected it")
    }

    func select(_ tag: Tag) async {
        self.selectedTagID = self.selectedTagID == tag.id ? nil : tag.id
        await self.logAndWait("Selected tag changed to \(self.selectedTagID ?? "none")")
    }

    func linkSelectedTag(to note: Note) async throws {
        guard let selectedTag = self.selectedTag else {
            await self.logAndWait("Skipped tap-link for note \(note.id) because no tag is selected")
            return
        }

        try await self.link(selectedTag, to: note)
    }

    func update(_ tag: Tag) async throws {
        let replacementTitle = DemoContent.tagTitles[(self.updateIndex + self.tagIndex) % DemoContent.tagTitles.count]
        let replacementColor = DemoContent.tagColors[(self.updateIndex + 3) % DemoContent.tagColors.count]
        self.updateIndex += 1

        let updatedTag = tag.updated(title: "\(replacementTitle)+", colorHex: replacementColor)
        try await self.$tags.insert(updatedTag)

        if self.selectedTagID == tag.id {
            self.selectedTagID = updatedTag.id
        }

        await self.logAndWait("Updated tag \(tag.id) from \"\(tag.title)\" to \"\(updatedTag.title)\"")
    }

    func remove(_ tag: Tag) async throws {
        try await self.$tags.remove(tag)

        if self.selectedTagID == tag.id {
            self.selectedTagID = nil
        }

        await self.logAndWait("Removed tag \(tag.id) title=\"\(tag.title)\"; related note arrays clear and primary tags nullify")
    }

    func remove(_ note: Note) async throws {
        try await self.$notes.remove(note)
        await self.logAndWait("Removed note \(note.id)")
    }

    func runStaleRemoveScenario() async throws {
        await self.logAndWait("Started stale remove scenario")
        try await self.removeScenarioData()

        let originalTag = Tag.scenario(id: "scenario-stale-remove", title: "Stale", colorHex: "#CC5533")
        let updatedTag = originalTag.updated(title: "Stale+", colorHex: "#2F7D68")
        let note = Note.scenario(id: "scenario-stale-note", text: "Scenario: update a tag, then remove it with the stale pre-update value.", tags: [originalTag], primaryTag: originalTag)

        try await self.$tags.insert(originalTag)
        try await self.$notes.insert(note)
        try await self.$tags.insert(updatedTag)
        try await self.$tags.remove(originalTag)

        await self.logAndWait("Finished stale remove scenario; note should be untagged and primary should be nil")
    }

    func runChainReplaceScenario() async throws {
        await self.logAndWait("Started remove-and-insert chain scenario")
        try await self.removeScenarioData()

        let replacedTag = Tag.scenario(id: "scenario-chain-replaced", title: "Chain", colorHex: "#CC5533")
        let updatedTag = replacedTag.updated(title: "Chain+", colorHex: "#2F7D68")
        let removedTag = Tag.scenario(id: "scenario-chain-removed", title: "Removed", colorHex: "#D18B00")
        let keptTag = Tag.scenario(id: "scenario-chain-kept", title: "Kept", colorHex: "#5B6CFF")
        let firstNote = Note.scenario(id: "scenario-chain-note-a", text: "Scenario: this note should keep Chain+ and lose Removed.", tags: [replacedTag, removedTag, keptTag], primaryTag: replacedTag)
        let secondNote = Note.scenario(id: "scenario-chain-note-b", text: "Scenario: this note should keep Kept and nullify Removed as primary.", tags: [removedTag, keptTag], primaryTag: removedTag)

        try await self.$tags.insert([replacedTag, removedTag, keptTag])
        try await self.$notes.insert([firstNote, secondNote])
        try await self.$tags.remove([replacedTag, removedTag]).insert([updatedTag]).run()

        await self.logAndWait("Finished remove-and-insert chain scenario; replacement should update and missing tag should clear")
    }

    func runFullRefreshScenario() async throws {
        await self.logAndWait("Started remove-all-and-insert refresh scenario")

        let replacedTag = Tag.scenario(id: "scenario-refresh-replaced", title: "Refresh", colorHex: "#CC5533")
        let updatedTag = replacedTag.updated(title: "Refresh+", colorHex: "#2F7D68")
        let removedTag = Tag.scenario(id: "scenario-refresh-removed", title: "Expired", colorHex: "#D18B00")
        let keptTag = Tag.scenario(id: "scenario-refresh-kept", title: "Current", colorHex: "#5B6CFF")
        let firstNote = Note.scenario(id: "scenario-refresh-note-a", text: "Scenario: full refresh should update Refresh and clear Expired.", tags: [replacedTag, removedTag], primaryTag: replacedTag)
        let secondNote = Note.scenario(id: "scenario-refresh-note-b", text: "Scenario: full refresh should keep Current and nullify Expired.", tags: [removedTag, keptTag], primaryTag: removedTag)

        try await self.$notes.insert([firstNote, secondNote])
        try await self.$tags.insert([replacedTag, removedTag, keptTag])
        try await self.$tags.removeAll().insert([updatedTag, keptTag]).run()

        if self.selectedTagID != nil, self.selectedTag == nil {
            self.selectedTagID = nil
        }

        await self.logAndWait("Finished remove-all-and-insert refresh scenario; replacement should update and missing tags should clear")
    }

    func reset() async throws {
        try await self.$notes.removeAll()
        try await self.$tags.removeAll()
        try await self.$actions.removeAll()
        self.selectedTagID = nil
        self.noteIndex = 0
        self.tagIndex = 0
        self.updateIndex = 0
        await self.logAndWait("Confirmed reset notes, tags, and action history")
    }

    @discardableResult
    func dumpStateToConsoleAndPasteboard() async -> RelationshipDemoSnapshot? {
        await self.logAndWait("Dumped JSON state to console and pasteboard")

        let snapshot = RelationshipDemoSnapshot(createdAt: .now, notes: self.notes, tags: self.tags, actions: self.actions)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(snapshot)
            let json = String(decoding: data, as: UTF8.self)
            UIPasteboard.general.string = json
            print(json)
            return snapshot
        } catch {
            await self.logAndWait("Failed to dump JSON state: \(error)")
            return nil
        }
    }

    func notes(for tag: Tag) -> [Note] {
        self.notes
            .filter { $0.tags.contains(where: { $0.id == tag.id }) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var untaggedNotes: [Note] {
        self.notes
            .filter { $0.tags.isEmpty }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var selectedTag: Tag? {
        guard let selectedTagID else { return nil }
        return self.tags.first(where: { $0.id == selectedTagID })
    }

    @discardableResult
    func log(_ action: String) -> Task<Void, Never> {
        let entry = ActionLog(
            id: UUID().uuidString,
            createdAt: .now,
            action: action,
            selectedTagID: self.selectedTagID,
            notes: self.notes,
            tags: self.tags
        )
        print("[\(Self.timestampFormatter.string(from: entry.createdAt))] Action: \(action)")

        let previousLog = self.logTail
        let task = Task { @MainActor [weak self] in
            await previousLog?.value

            guard let self else { return }

            do {
                try await self.$actions.insert(entry)
            } catch {
                print("[\(Self.timestampFormatter.string(from: .now))] Action: Failed to persist action log \(entry.id): \(error)")
            }
        }

        self.logTail = task
        return task
    }
}

private extension RelationshipsDemoController {
    static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func link(_ tag: Tag, to note: Note) async throws {
        var updatedNote = note
        var didChange = false

        if !updatedNote.tags.contains(where: { $0.id == tag.id }) {
            updatedNote.tags.append(tag)
            didChange = true
        }

        if updatedNote.primaryTag == nil {
            updatedNote.primaryTag = tag
            didChange = true
        }

        guard didChange else {
            await self.logAndWait("Skipped linking tag \(tag.id) to note \(note.id) because it is already linked")
            return
        }

        updatedNote.updatedAt = .now
        try await self.$notes.insert(updatedNote)
        await self.logAndWait("Linked tag \(tag.id) title=\"\(tag.title)\" to note \(note.id)")
    }

    func logAndWait(_ action: String) async {
        await self.log(action).value
    }

    func removeScenarioData() async throws {
        let scenarioNotes = self.notes.filter({ $0.id.hasPrefix("scenario-") })
        let scenarioTags = self.tags.filter({ $0.id.hasPrefix("scenario-") })

        if !scenarioNotes.isEmpty {
            try await self.$notes.remove(scenarioNotes)
        }

        if !scenarioTags.isEmpty {
            try await self.$tags.remove(scenarioTags)
        }

        if self.selectedTagID?.hasPrefix("scenario-") == true {
            self.selectedTagID = nil
        }
    }

    func nextAvailableTagSeed() -> (title: String, colorHex: String, nextIndex: Int)? {
        let existingTitles = Set(self.tags.map({ Self.normalizedTagTitle($0.title) }))

        for offset in DemoContent.tagTitles.indices {
            let index = (self.tagIndex + offset) % DemoContent.tagTitles.count
            let title = DemoContent.tagTitles[index]

            guard !existingTitles.contains(Self.normalizedTagTitle(title)) else {
                continue
            }

            let colorHex = DemoContent.tagColors[index % DemoContent.tagColors.count]
            return (title, colorHex, index + 1)
        }

        return nil
    }

    static func normalizedTagTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }
}

#if DEBUG
extension RelationshipsDemoController {
    func runSelfTestIfRequested() async {
        guard ProcessInfo.processInfo.environment["RELATIONSHIPS_DEMO_SELF_TEST"] == "1", !self.hasRunSelfTest else { return }

        self.hasRunSelfTest = true

        do {
            try await self.reset()
            try await self.addNote()
            try await self.addTag()

            guard let note = self.notes.first, let tag = self.selectedTag else {
                await self.logAndWait("Self-test failed before linking because a note or selected tag was missing")
                return
            }

            try await self.link(tag, to: note)
            try await self.update(tag)

            guard let updatedTag = self.selectedTag else {
                await self.logAndWait("Self-test failed before removal because the updated selected tag was missing")
                return
            }

            try await self.remove(updatedTag)

            guard let snapshot = await self.dumpStateToConsoleAndPasteboard() else {
                await self.logAndWait("Self-test failed because the JSON dump could not be created")
                return
            }

            let actions = snapshot.actions.map(\.action)
            let requiredActionPrefixes = [
                "Confirmed reset notes, tags, and action history",
                "Added note ",
                "Added tag ",
                "Linked tag ",
                "Custom update relationship observed ",
                "Updated tag ",
                "Custom remove relationship observed ",
                "Removed tag ",
                "Dumped JSON state to console and pasteboard"
            ]
            let missingPrefixes = requiredActionPrefixes.filter { prefix in
                !actions.contains(where: { $0.hasPrefix(prefix) })
            }
            let clearedRelationships = snapshot.tags.isEmpty && snapshot.notes.allSatisfy { note in
                note.tags.isEmpty && note.primaryTag == nil
            }

            if missingPrefixes.isEmpty, clearedRelationships {
                await self.logAndWait("Self-test passed with \(snapshot.actions.count) persisted action(s)")
            } else {
                await self.logAndWait("Self-test failed missingActions=\(missingPrefixes) clearedRelationships=\(clearedRelationships)")
            }
        } catch {
            await self.logAndWait("Self-test failed with error: \(error)")
        }
    }
}
#endif
