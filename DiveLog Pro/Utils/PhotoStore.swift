import Foundation
import UIKit
import SwiftData

/// Stores dive photos as JPEG files on disk (local cache) **and** in DivePhoto
/// records (CloudKit sync). On save both locations are written. On load the
/// disk cache is checked first; if missing the DivePhoto record is used and
/// the file is re-cached locally.
enum PhotoStore {

    // MARK: - Paths

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var photosDirectory: URL {
        let url = documentsURL.appendingPathComponent("dive_photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private static func url(for filename: String) -> URL {
        photosDirectory.appendingPathComponent(filename)
    }

    // MARK: - Save (local only — legacy callers)

    @discardableResult
    static func save(image: UIImage, quality: CGFloat = 0.82) -> String? {
        let resized = downsample(image: image, maxDimension: 2000)
        guard let data = resized.jpegData(compressionQuality: quality) else { return nil }
        return save(jpegData: data)
    }

    @discardableResult
    static func save(jpegData: Data) -> String? {
        let filename = UUID().uuidString + ".jpg"
        do {
            try jpegData.write(to: url(for: filename), options: .atomic)
            return filename
        } catch {
            print("PhotoStore save error: \(error)")
            return nil
        }
    }

    // MARK: - Save (local + CloudKit)

    @discardableResult
    static func save(image: UIImage, toDive dive: Dive, context: ModelContext, quality: CGFloat = 0.82) -> String? {
        let resized = downsample(image: image, maxDimension: 2000)
        guard let data = resized.jpegData(compressionQuality: quality) else { return nil }
        guard let filename = save(jpegData: data) else { return nil }

        let photo = DivePhoto()
        photo.filename = filename
        photo.imageData = data
        photo.dive = dive
        context.insert(photo)

        return filename
    }

    // MARK: - Load

    static func load(filename: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: filename).path)
    }

    static func load(filename: String, from dive: Dive) -> UIImage? {
        if let local = load(filename: filename) {
            return local
        }
        guard let photos = dive.photos,
              let record = photos.first(where: { $0.filename == filename }),
              !record.imageData.isEmpty,
              let image = UIImage(data: record.imageData) else {
            return nil
        }
        try? record.imageData.write(to: url(for: filename), options: .atomic)
        return image
    }

    // MARK: - Delete

    static func delete(filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    static func deleteAll(filenames: [String]) {
        filenames.forEach { delete(filename: $0) }
    }

    static func delete(filename: String, from dive: Dive, context: ModelContext) {
        delete(filename: filename)
        if let photos = dive.photos,
           let record = photos.first(where: { $0.filename == filename }) {
            context.delete(record)
        }
    }

    // MARK: - Migration

    static func migrateLocalPhotosToCloudKit(dive: Dive, context: ModelContext) {
        let existingRecordNames = Set((dive.photos ?? []).map(\.filename))
        for filename in dive.photoFilenames {
            guard !existingRecordNames.contains(filename) else { continue }
            guard let data = try? Data(contentsOf: url(for: filename)) else { continue }
            let photo = DivePhoto()
            photo.filename = filename
            photo.imageData = data
            photo.dive = dive
            context.insert(photo)
        }
    }

    // MARK: - Helpers

    private static func downsample(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longEdge = max(size.width, size.height)
        guard longEdge > maxDimension else { return image }
        let scale = maxDimension / longEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
