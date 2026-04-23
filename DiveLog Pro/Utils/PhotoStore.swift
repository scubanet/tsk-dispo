import Foundation
import UIKit

/// Stores dive photos as JPEG files in the app's documents directory.
/// Dive objects reference photos by filename; actual bytes live on disk so the
/// SwiftData store stays small and iCloud-syncable.
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

    // MARK: - Save

    /// Compress an image to JPEG and persist it. Returns the generated filename
    /// on success. Down-samples to max 2000 px on the long edge to keep storage
    /// reasonable — dive photos rarely need full-resolution.
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

    // MARK: - Load

    static func load(filename: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: filename).path)
    }

    // MARK: - Delete

    static func delete(filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    static func deleteAll(filenames: [String]) {
        filenames.forEach { delete(filename: $0) }
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
