import SwiftUI
import SwiftData
import PhotosUI

/// The Picture (collage) journal editor: add photos — imported or pasted — onto
/// the paper page, then drag and pinch each one to arrange a collage. The layout
/// is the entry's content, persisted as `entry.collageItems`.
///
/// v1 supports drag, pinch-to-scale, and delete; rotation and captions are left
/// for later. Photos are downscaled on the way in (`UIImage.journalEncoded`).
struct PictureJournalView: View {
    @Bindable var entry: JournalEntry
    var theme: JournalTheme = .diary

    @State private var items: [CollageItem] = []
    @State private var images: [UUID: UIImage] = [:]
    @State private var selection: UUID?
    @State private var pickerItems: [PhotosPickerItem] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                theme.paper

                ForEach(items) { item in
                    if let image = images[item.id] {
                        CollageImageView(
                            image: image,
                            item: binding(for: item),
                            pageSize: geo.size,
                            isSelected: selection == item.id,
                            onSelect: { selection = item.id },
                            onDelete: { delete(item) }
                        )
                    }
                }

                if items.isEmpty {
                    emptyHint
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .onTapGesture { selection = nil }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationTitle("Picture")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(theme.ink)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if UIPasteboard.general.hasImages {
                    Button(action: pasteImage) {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .accessibilityLabel("Paste photo")
                }
                PhotosPicker(selection: $pickerItems, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                }
                .accessibilityLabel("Add photos")
            }
        }
        .task { loadItems() }
        .onChange(of: items) { _, newValue in
            entry.collageItems = newValue
        }
        .onChange(of: pickerItems) { _, newValue in
            guard !newValue.isEmpty else { return }
            importPicked(newValue)
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44))
                .foregroundStyle(Color.lilac)
            Text("Add photos to start your collage")
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(theme.ink.opacity(0.6))
        }
        .allowsHitTesting(false)
    }

    // MARK: - Data

    private func binding(for item: CollageItem) -> Binding<CollageItem> {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return .constant(item)
        }
        return $items[index]
    }

    private func loadItems() {
        if items.isEmpty { items = entry.collageItems }
        for item in items where images[item.id] == nil {
            images[item.id] = UIImage(data: item.imageData)
        }
    }

    private func importPicked(_ picked: [PhotosPickerItem]) {
        Task { @MainActor in
            for pickerItem in picked {
                if let data = try? await pickerItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    add(image)
                }
            }
            pickerItems = []
        }
    }

    private func pasteImage() {
        if let image = UIPasteboard.general.image { add(image) }
    }

    /// Downscale, store, and place a new photo, cascading slightly so repeated
    /// adds don't land exactly on top of one another.
    private func add(_ image: UIImage) {
        guard let data = image.journalEncoded(), let stored = UIImage(data: data) else { return }
        let step = CGFloat(items.count % 6)
        var item = CollageItem(imageData: data)
        item.centerX = min(0.85, 0.4 + step * 0.04)
        item.centerY = min(0.8, 0.35 + step * 0.04)
        images[item.id] = stored
        items.append(item)
        selection = item.id
    }

    private func delete(_ item: CollageItem) {
        items.removeAll { $0.id == item.id }
        images[item.id] = nil
        if selection == item.id { selection = nil }
    }
}

/// A single placed photo: draggable, pinch-scalable, with a delete affordance
/// when selected. Live gesture state (`dragOffset`, `pinch`) drives the view
/// during a gesture and commits into the bound `CollageItem` on end.
private struct CollageImageView: View {
    let image: UIImage
    @Binding var item: CollageItem
    let pageSize: CGSize
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1

    private var baseWidth: CGFloat { item.widthFraction * pageSize.width }
    private var baseHeight: CGFloat { baseWidth * image.size.height / max(image.size.width, 1) }
    private var center: CGPoint {
        CGPoint(x: item.centerX * pageSize.width + dragOffset.width,
                y: item.centerY * pageSize.height + dragOffset.height)
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .frame(width: baseWidth * pinch, height: baseHeight * pinch)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.lilac, lineWidth: isSelected ? 2 : 0)
            )
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.lilac)
                    }
                    .offset(x: 10, y: -10)
                }
            }
            .position(center)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in state = value.translation }
                    .onChanged { _ in if !isSelected { onSelect() } }
                    .onEnded { value in
                        item.centerX += value.translation.width / pageSize.width
                        item.centerY += value.translation.height / pageSize.height
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onEnded { value in
                        item.widthFraction = min(1.5, max(0.15, item.widthFraction * value.magnification))
                    }
            )
            .onTapGesture { onSelect() }
    }
}
