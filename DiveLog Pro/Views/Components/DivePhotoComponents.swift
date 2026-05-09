import SwiftUI
import SwiftData
import PhotosUI

// ═══════════════════════════════════════
// MARK: - Thumbnail
// ═══════════════════════════════════════

/// Loads a dive photo from `PhotoStore` asynchronously so that scrolling
/// stays smooth. Falls back to a subtle placeholder while loading or if
/// the file is missing.
struct DivePhotoThumbnail: View {
    let filename: String
    var dive: Dive?
    var width: CGFloat = 80
    var height: CGFloat = 80
    var cornerRadius: CGFloat = 12

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.oceanBlue.opacity(0.1))
                    .overlay(
                        Image(systemName: "photo.fill")
                            .font(.system(size: min(width, height) * 0.3))
                            .foregroundColor(.white.opacity(0.18))
                    )
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .task(id: filename) {
            await loadImage()
        }
    }

    private func loadImage() async {
        if let dive {
            self.image = PhotoStore.load(filename: filename, from: dive)
        } else {
            self.image = PhotoStore.load(filename: filename)
        }
    }
}

// ═══════════════════════════════════════
// MARK: - Photo Picker Section
// ═══════════════════════════════════════

/// Horizontal photo selection UI for the dive form. Shows an "Add" button,
/// then thumbnails of currently attached photos with a delete control.
struct PhotoPickerSection: View {
    @Binding var filenames: [String]
    var dive: Dive?
    var maxPhotos: Int = 20

    @Environment(\.modelContext) private var modelContext
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var showingPicker = false

    private var remaining: Int { max(0, maxPhotos - filenames.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.photosLabel.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.labelDim)
                    .tracking(1.2)
                Spacer()
                Text("\(filenames.count) / \(maxPhotos)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Add button — uses the modifier form of PhotosPicker
                    // (.photosPicker(isPresented:)) because the inline init
                    // form can fail to present when nested inside ScrollViews
                    // inside a NavigationStack. Decoupling tap trigger from
                    // presentation is more reliable.
                    Button {
                        showingPicker = true
                    } label: {
                        addButton
                    }
                    .buttonStyle(.plain)
                    .disabled(remaining == 0 || isImporting)
                    .opacity(remaining == 0 ? 0.5 : 1)

                    // Existing thumbnails with delete
                    ForEach(filenames, id: \.self) { name in
                        ZStack(alignment: .topTrailing) {
                            DivePhotoThumbnail(filename: name, dive: dive, width: 96, height: 96, cornerRadius: 14)
                            Button {
                                remove(filename: name)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(Color.deepOcean.opacity(0.85)))
                                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .offset(x: 6, y: -6)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 108)

            if isImporting {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text(L10n.currentLanguage == "de" ? "Fotos werden importiert…" : "Importing photos…")
                        .font(.system(size: 11))
                        .foregroundColor(.textDim)
                }
            }
        }
        .photosPicker(
            isPresented: $showingPicker,
            selection: $pickerItems,
            maxSelectionCount: remaining,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            importPhotos(items)
        }
    }

    private var addButton: some View {
        VStack(spacing: 6) {
            Image(systemName: "camera.fill")
                .font(.system(size: 22))
                .foregroundColor(.oceanBlue)
            Text(L10n.currentLanguage == "de" ? "Hinzufügen" : "Add")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.oceanBlue)
        }
        .frame(width: 96, height: 96)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.oceanBlue.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .background(
                    RoundedRectangle(cornerRadius: 14).fill(Color.oceanBlue.opacity(0.08))
                )
        )
    }

    // MARK: - Import

    private func importPhotos(_ items: [PhotosPickerItem]) {
        isImporting = true
        Task {
            var saved: [String] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let filename: String?
                    if let dive {
                        filename = PhotoStore.save(image: image, toDive: dive, context: modelContext)
                    } else {
                        filename = PhotoStore.save(image: image)
                    }
                    if let filename { saved.append(filename) }
                }
            }
            await MainActor.run {
                filenames.append(contentsOf: saved)
                pickerItems = []
                isImporting = false
            }
        }
    }

    private func remove(filename: String) {
        if let dive {
            PhotoStore.delete(filename: filename, from: dive, context: modelContext)
        } else {
            PhotoStore.delete(filename: filename)
        }
        filenames.removeAll { $0 == filename }
    }
}

// ═══════════════════════════════════════
// MARK: - Full-Screen Viewer
// ═══════════════════════════════════════

/// Full-screen, swipeable viewer with pinch-to-zoom and a close button.
struct PhotoViewerView: View {
    let filenames: [String]
    var dive: Dive?
    @State var startIndex: Int = 0
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(filenames.indices, id: \.self) { i in
                    ZoomablePhoto(filename: filenames[i], dive: dive)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: filenames.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                Spacer()
                if filenames.count > 1 {
                    Text("\(currentIndex + 1) / \(filenames.count)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                        .padding(.bottom, 40)
                }
            }
        }
        .onAppear { currentIndex = startIndex }
    }
}

/// One photo in the viewer with pinch-to-zoom and double-tap-to-reset.
private struct ZoomablePhoto: View {
    let filename: String
    var dive: Dive?
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1, min(4, lastScale * value))
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale == 1 {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            offset = .zero; lastOffset = .zero
                                        }
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    guard scale > 1 else { return }
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in lastOffset = offset }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if scale > 1 {
                                    scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
                                } else {
                                    scale = 2; lastScale = 2
                                }
                            }
                        }
                } else {
                    ProgressView().tint(.white.opacity(0.6))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task(id: filename) {
            if let dive {
                self.image = PhotoStore.load(filename: filename, from: dive)
            } else {
                self.image = PhotoStore.load(filename: filename)
            }
        }
    }
}
