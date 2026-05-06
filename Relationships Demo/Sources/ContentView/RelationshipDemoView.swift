import SwiftUI

struct RelationshipDemoView: View {
    @State private var controller = RelationshipsDemoController.shared

    private let columns = [
        GridItem(.adaptive(minimum: 240.0), spacing: 12.0)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18.0) {
                    tagPanel
                    noteSections
                }
                .padding(16.0)
                .padding(.bottom, 84.0)
            }
            .background(Color.palette.appBackground.ignoresSafeArea())
            .navigationTitle("Relationships")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: {
                        Task {
                            await controller.dumpStateToConsoleAndPasteboard()
                        }
                    }, label: {
                        Image(systemName: "terminal")
                    })
                    .accessibilityLabel("Dump JSON")

                    Menu(content: {
                        Button(action: {
                            Task {
                                try await controller.runStaleRemoveScenario()
                            }
                        }, label: {
                            Label("Stale Remove", systemImage: "clock.arrow.circlepath")
                        })

                        Button(action: {
                            Task {
                                try await controller.runChainReplaceScenario()
                            }
                        }, label: {
                            Label("Chain Replace", systemImage: "link")
                        })

                        Button(role: .destructive, action: {
                            Task {
                                try await controller.runFullRefreshScenario()
                            }
                        }, label: {
                            Label("Full Refresh", systemImage: "arrow.triangle.2.circlepath")
                        })
                    }, label: {
                        Image(systemName: "play.circle")
                    })
                    .accessibilityLabel("Run Scenario")

                    Menu(content: {
                        Button(role: .destructive, action: {
                            Task {
                                try await controller.reset()
                            }
                        }, label: {
                            Label("Confirm Reset", systemImage: "arrow.counterclockwise")
                        })
                    }, label: {
                        Image(systemName: "arrow.counterclockwise")
                    })
                    .accessibilityLabel("Reset")
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomActionToolbar
                    .padding(.horizontal, 18.0)
                    .padding(.bottom, 8.0)
            }
        }
    }

    @ViewBuilder
    private var bottomActionToolbar: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10.0) {
                HStack(spacing: 10.0) {
                    Button(action: {
                        Task {
                            try await controller.addNote()
                        }
                    }, label: {
                        Label("Add Note", systemImage: "note.text.badge.plus")
                    })
                    .buttonStyle(.glassProminent)

                    Button(action: {
                        Task {
                            try await controller.addTag()
                        }
                    }, label: {
                        Label("Tag", systemImage: "tag")
                    })
                    .buttonStyle(.glass(.regular.tint(.blue.opacity(0.18))))
                }
                .font(.headline)
                .padding(8.0)
                .glassEffect(.regular, in: Capsule())
            }
        } else {
            HStack(spacing: 10.0) {
                Button(action: {
                    Task {
                        try await controller.addNote()
                    }
                }, label: {
                    Label("Add Note", systemImage: "note.text.badge.plus")
                })
                .buttonStyle(.borderedProminent)

                Button(action: {
                    Task {
                        try await controller.addTag()
                    }
                }, label: {
                    Label("Tag", systemImage: "tag")
                })
                .buttonStyle(.bordered)
            }
            .font(.headline)
            .padding(10.0)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var tagPanel: some View {
        VStack(alignment: .leading, spacing: 10.0) {
            HStack {
                Text("Tags")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(controller.tags.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132.0), spacing: 8.0)], alignment: .leading, spacing: 8.0) {
                ForEach(controller.tags) { tag in
                    TagButton(
                        tag: tag,
                        isSelected: controller.selectedTagID == tag.id,
                        selectAction: {
                            Task {
                                await controller.select(tag)
                            }
                        },
                        updateAction: {
                            Task {
                                try await controller.update(tag)
                            }
                        },
                        removeAction: {
                            Task {
                                try await controller.remove(tag)
                            }
                        }
                    )
                }
            }
        }
    }

    private var noteSections: some View {
        VStack(alignment: .leading, spacing: 18.0) {
            if !controller.untaggedNotes.isEmpty {
                NoteGridSection(
                    title: "Untagged",
                    notes: controller.untaggedNotes,
                    controller: controller,
                    columns: columns
                )
            }

            ForEach(controller.tags.sorted(by: { $0.title < $1.title })) { tag in
                let notes = controller.notes(for: tag)

                if !notes.isEmpty {
                    NoteGridSection(
                        title: tag.title,
                        notes: notes,
                        controller: controller,
                        columns: columns
                    )
                }
            }
        }
    }
}

private struct TagButton: View {
    let tag: Tag
    let isSelected: Bool
    let selectAction: () -> Void
    let updateAction: () -> Void
    let removeAction: () -> Void

    var body: some View {
        HStack(spacing: 6.0) {
            Button(action: {
                var transaction = Transaction()
                transaction.animation = nil

                withTransaction(transaction) {
                    selectAction()
                }
            }, label: {
                HStack {
                    Text(tag.title)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)

                    Spacer(minLength: 0.0)
                }
                .frame(maxWidth: .infinity, minHeight: 34.0)
                .contentShape(Rectangle())
            })
            .buttonStyle(.plain)

            Button(action: updateAction, label: {
                Image(systemName: "arrow.triangle.2.circlepath")
            })

            Button(role: .destructive, action: removeAction, label: {
                Image(systemName: "xmark.circle.fill")
            })
        }
        .padding(.horizontal, 10.0)
        .frame(height: 34.0)
        .background(tag.color.opacity(isSelected ? 0.95 : 0.62))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        .overlay(
            RoundedRectangle(cornerRadius: 8.0)
                .stroke(Color.white.opacity(isSelected ? 0.95 : 0.0), lineWidth: 2.0)
        )
    }
}

private struct NoteGridSection: View {
    let title: String
    let notes: [Note]
    let controller: RelationshipsDemoController
    let columns: [GridItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10.0) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(notes.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            LazyVGrid(columns: columns, spacing: 12.0) {
                ForEach(notes) { note in
                    NoteCard(note: note, controller: controller)
                }
            }
        }
    }
}

private struct NoteCard: View {
    let note: Note
    let controller: RelationshipsDemoController

    var body: some View {
        VStack(alignment: .leading, spacing: 10.0) {
            HStack(alignment: .top) {
                Text(note.text)
                    .font(.body)
                    .foregroundStyle(.white)
                    .lineLimit(4)

                Spacer(minLength: 8.0)

                Button(role: .destructive, action: {
                    Task {
                        try await controller.remove(note)
                    }
                }, label: {
                    Image(systemName: "trash")
                })
            }

            if let primaryTag = note.primaryTag {
                TagChip(title: "Primary: \(primaryTag.title)", color: primaryTag.color)
            }

            FlowLayout(spacing: 6.0) {
                ForEach(note.tags) { tag in
                    TagChip(title: tag.title, color: tag.color)
                }
            }
        }
        .padding(12.0)
        .frame(maxWidth: .infinity, minHeight: 132.0, alignment: .topLeading)
        .background(Color.black.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
        .overlay(
            RoundedRectangle(cornerRadius: 8.0)
                .stroke(Color.white.opacity(0.12), lineWidth: 1.0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8.0))
        .onTapGesture {
            Task {
                try await controller.linkSelectedTag(to: note)
            }
        }
    }
}

private struct TagChip: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8.0)
            .frame(height: 24.0)
            .background(color.opacity(0.72))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = self.rows(proposal: proposal, subviews: subviews)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0.0,
            height: rows.map(\.height).reduce(0.0, +) + CGFloat(max(0, rows.count - 1)) * spacing
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = self.rows(proposal: ProposedViewSize(width: bounds.width, height: proposal.height), subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX

            for element in row.elements {
                element.subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(element.size)
                )
                x += element.size.width + spacing
            }

            y += row.height + spacing
        }
    }

    private func rows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let availableWidth = proposal.width ?? 320.0
        var rows = [Row]()
        var currentRow = Row()

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentRow.width + size.width > availableWidth, !currentRow.elements.isEmpty {
                rows.append(currentRow)
                currentRow = Row()
            }

            currentRow.elements.append(Row.Element(subview: subview, size: size))
            currentRow.width += size.width + (currentRow.elements.count == 1 ? 0.0 : spacing)
            currentRow.height = max(currentRow.height, size.height)
        }

        if !currentRow.elements.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    private struct Row {
        var elements = [Element]()
        var width: CGFloat = 0.0
        var height: CGFloat = 0.0

        struct Element {
            let subview: LayoutSubview
            let size: CGSize
        }
    }
}
