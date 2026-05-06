import Foundation
import SwiftUI

struct Note: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var createdAt: Date
    var updatedAt: Date
    var text: String
    var tags: [Tag]
    var primaryTag: Tag?
}

struct Tag: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var createdAt: Date
    var updatedAt: Date
    var title: String
    var colorHex: String
}

struct ActionLog: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let createdAt: Date
    let action: String
    let selectedTagID: String?
    let notes: [Note]
    let tags: [Tag]
}

struct RelationshipDemoSnapshot: Codable {
    let createdAt: Date
    let notes: [Note]
    let tags: [Tag]
    let actions: [ActionLog]
}

extension Note {
    static func make(text: String) -> Note {
        Note(
            id: UUID().uuidString,
            createdAt: .now,
            updatedAt: .now,
            text: text,
            tags: [],
            primaryTag: nil
        )
    }

    static func scenario(id: String, text: String, tags: [Tag], primaryTag: Tag?) -> Note {
        Note(
            id: id,
            createdAt: .now,
            updatedAt: .now,
            text: text,
            tags: tags,
            primaryTag: primaryTag
        )
    }
}

extension Tag {
    static func make(title: String, colorHex: String) -> Tag {
        Tag(
            id: UUID().uuidString,
            createdAt: .now,
            updatedAt: .now,
            title: title,
            colorHex: colorHex
        )
    }

    static func scenario(id: String, title: String, colorHex: String) -> Tag {
        Tag(
            id: id,
            createdAt: .now,
            updatedAt: .now,
            title: title,
            colorHex: colorHex
        )
    }

    func updated(title: String, colorHex: String) -> Tag {
        Tag(
            id: self.id,
            createdAt: self.createdAt,
            updatedAt: .now,
            title: title,
            colorHex: colorHex
        )
    }
}

extension Tag {
    var color: Color {
        Color(hex: self.colorHex)
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: sanitized)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

enum DemoContent {
    static let noteTexts: [String] = [
        "Draft a short plan for the relationship demo before lunch.",
        "Review the tag cleanup behavior after deleting a tag.",
        "Collect screenshots for the next Boutique documentation pass.",
        "Write down the edge case where a note has no tags.",
        "Compare update propagation against the expected JSON snapshot.",
        "Prepare a quick demo script for tapping tags onto notes.",
        "Check whether the primary tag nullifies after deletion.",
        "Record a sequence that adds three tags to two notes.",
        "Trim the UI until the relationship behavior is obvious.",
        "Inspect logs after every mutation to verify ordering.",
        "Create a note about optimistic UI updates and failures.",
        "Save a sample state before testing tag updates.",
        "Try linking one tag to every visible note.",
        "Remove a heavily used tag and watch the grid rebalance.",
        "Update a tag title and confirm every note reflects it.",
        "Add notes until the scroll view has enough density.",
        "Use the JSON dump to compare before and after states.",
        "Write a note that intentionally stays untagged.",
        "Test a note with a primary tag and two secondary tags.",
        "Confirm duplicate tag titles still have unique identities.",
        "Add a note for the release checklist.",
        "Mark a tag as primary by assigning it first.",
        "Add a second tag onto a note without replacing primary.",
        "Confirm removing a note leaves the tag store untouched.",
        "Create a sample note about offline-first caches.",
        "Watch for unexpected reorder after updating a tag.",
        "Check that the toolbar dump includes every note.",
        "Add several short notes to exercise compact card layout.",
        "Document how array clearing differs from optional nullify.",
        "Make a note about relationship propagation errors.",
        "Verify tags remain sorted alphabetically in the sidebar.",
        "Create a test note for batch deletion later.",
        "Trace a tag from creation through update and removal.",
        "Add an implementation note about denormalized data.",
        "Check that logs include precise timestamps.",
        "Create a note for tag selection accessibility follow-up.",
        "Run a state dump after updating the selected tag.",
        "Add a reminder to test on a narrow phone simulator.",
        "Confirm the untagged section shrinks after linking tags.",
        "Create a note that uses the same tag as many others.",
        "Check the grid when all tags are removed.",
        "Add a note about StoreEvent ordering.",
        "Capture the state after clearing the last tag.",
        "Test whether tag colors propagate with updates.",
        "Create a note about feature documentation examples.",
        "Link a tag using the tap flow.",
        "Confirm the selected tag clears after it is deleted.",
        "Add a note to verify the reset path empties both stores.",
        "Write down a regression test idea for nullify.",
        "Create a note about parent and child store naming.",
        "Add a note about keeping models annotation-free.",
        "Record a scenario with one tag across five notes.",
        "Check how the grid handles long note text.",
        "Create a note for future bidirectional relationship tests.",
        "Verify that deleting tags never deletes notes.",
        "Add a short note for visual spacing checks.",
        "Capture console output while linking two tags.",
        "Create a note about relationship action naming.",
        "Confirm update actions use the same cache identifier.",
        "Add a note about deterministic sample content.",
        "Test a note with primary tag only.",
        "Test a note with three regular tags.",
        "Create a note for manual QA steps.",
        "Inspect state after adding ten tags quickly.",
        "Add a note that should move between tag sections.",
        "Check JSON formatting after many operations.",
        "Create a note for comparing clear and nullify behavior.",
        "Verify tag removal logs before and after state counts.",
        "Add a note about Store relationship performance.",
        "Test repeated updates to the same tag.",
        "Create a note for checking color contrast.",
        "Confirm tag chips stay current after update.",
        "Add a note about keeping the API small.",
        "Test removing the primary tag from a busy note.",
        "Create a note for later screenshot polish.",
        "Watch untagged notes appear after their tags are removed.",
        "Add a note about relationship setup in controllers.",
        "Check the behavior when no selected tag exists.",
        "Create a note for long-running manual testing.",
        "Link a tag, update it, then delete it.",
        "Add a note about relationship test fixtures.",
        "Confirm notes can be removed independently.",
        "Create a note that receives tags only through selection.",
        "Check that state dump copies to the pasteboard.",
        "Add a note about child store batch inserts.",
        "Verify that updated tag colors appear in note chips.",
        "Create a note about tag deletion safety.",
        "Test the UI after resetting from a dense state.",
        "Add a note about future conflict handling.",
        "Confirm every action emits a console log.",
        "Create a note for relationship demo onboarding.",
        "Check if the toolbar stays reachable while scrolling.",
        "Add a note about local persistence between launches.",
        "Verify tags survive note removal.",
        "Create a note with no primary tag.",
        "Add a note about Store relationship documentation.",
        "Check that generated note text cycles predictably.",
        "Create a note about debugging with JSON snapshots.",
        "Verify the final state after a full reset.",
        "Add a note for the next manual pass."
    ]

    static let tagTitles: [String] = [
        "Swift",
        "Design",
        "Offline",
        "Sync",
        "Debug",
        "State",
        "JSON",
        "Cache",
        "Notes",
        "Tags",
        "Update",
        "Delete",
        "Grid",
        "Primary",
        "Menu",
        "Toolbar",
        "Child",
        "Parent",
        "Nullify",
        "Clear",
        "Batch",
        "Store",
        "Event",
        "Log",
        "QA",
        "Docs",
        "Demo",
        "Color",
        "Feature",
        "Test",
        "Bug",
        "Fix",
        "Local",
        "Model",
        "Link",
        "Trace",
        "Review",
        "Sample",
        "Manual",
        "Check",
        "Plan",
        "UI",
        "Data",
        "Sort",
        "Filter",
        "Focus",
        "Action",
        "Dump",
        "Reset",
        "Flow"
    ]

    static let tagColors: [String] = [
        "#CC5533",
        "#2F7D68",
        "#5B6CFF",
        "#D18B00",
        "#7A4EAB",
        "#1677A3",
        "#B43F5F",
        "#4F7F2A",
        "#8F5A2A",
        "#4B6B7D"
    ]
}
