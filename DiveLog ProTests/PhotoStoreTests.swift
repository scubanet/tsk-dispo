import Testing
import Foundation
import SwiftData
import UIKit
@testable import DiveLog_Pro

@Suite("PhotoStore")
struct PhotoStoreTests {

    @MainActor
    private func makeContext() throws -> (ModelContext, Dive) {
        let schema = Schema([
            Dive.self, DivePhoto.self, DiverProfile.self, DiveSite.self,
            Buddy.self, DiveSignature.self,
            Student.self, PoolSession.self, SkillCompletion.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let dive = Dive(date: .now)
        context.insert(dive)
        try context.save()
        return (context, dive)
    }

    /// 64x64 solid-colored UIImage for tests — small enough to keep tests fast,
    /// large enough that JPEG encoding produces non-empty data.
    private func dummyImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        return renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
    }

    // MARK: - Save (record + cache)

    @Test("save(image:toDive:context:) creates a DivePhoto record with imageData")
    @MainActor
    func saveCreatesRecord() throws {
        let (ctx, dive) = try makeContext()

        let filename = PhotoStore.save(image: dummyImage(), toDive: dive, context: ctx)
        try ctx.save()

        #expect(filename != nil)
        #expect(dive.photos?.count == 1)
        #expect(dive.photos?.first?.filename == filename)
        #expect(dive.photos?.first?.imageData.isEmpty == false)
    }

    // MARK: - Load — disk path

    @Test("load(filename:from:) returns the image when disk cache is present")
    @MainActor
    func loadFromDiskCache() throws {
        let (ctx, dive) = try makeContext()
        guard let filename = PhotoStore.save(image: dummyImage(), toDive: dive, context: ctx) else {
            Issue.record("Save failed")
            return
        }
        try ctx.save()

        let loaded = PhotoStore.load(filename: filename, from: dive)
        #expect(loaded != nil)
    }

    // MARK: - Load — fallback to record imageData

    @Test("load falls back to record imageData when disk file is missing")
    @MainActor
    func loadFallsBackToRecord() throws {
        let (ctx, dive) = try makeContext()
        guard let filename = PhotoStore.save(image: dummyImage(), toDive: dive, context: ctx) else {
            Issue.record("Save failed")
            return
        }
        try ctx.save()

        // Simulate a fresh device after CloudKit sync — disk file is gone,
        // but the DivePhoto record carries the bytes.
        PhotoStore.delete(filename: filename)

        let loaded = PhotoStore.load(filename: filename, from: dive)
        #expect(loaded != nil, "Image should still load from DivePhoto.imageData")
    }

    // MARK: - Migration — legacy filenames-only dives

    @Test("migrateLocalPhotosToCloudKit creates DivePhoto records for legacy filenames")
    @MainActor
    func migrationCreatesRecords() throws {
        let (ctx, dive) = try makeContext()

        // Simulate a legacy dive: filename in the array, no DivePhoto record yet.
        let img = dummyImage()
        guard let data = img.jpegData(compressionQuality: 0.82),
              let legacyFilename = PhotoStore.save(jpegData: data) else {
            Issue.record("Legacy save failed")
            return
        }
        dive.photoFilenames.append(legacyFilename)
        try ctx.save()

        #expect(dive.photos?.isEmpty == true)

        PhotoStore.migrateLocalPhotosToCloudKit(dive: dive, context: ctx)
        try ctx.save()

        #expect(dive.photos?.count == 1)
        #expect(dive.photos?.first?.filename == legacyFilename)
    }

    // MARK: - Migration is idempotent

    @Test("migration is idempotent — running twice does not duplicate records")
    @MainActor
    func migrationIdempotent() throws {
        let (ctx, dive) = try makeContext()

        let img = dummyImage()
        guard let data = img.jpegData(compressionQuality: 0.82),
              let filename = PhotoStore.save(jpegData: data) else {
            Issue.record("Save failed")
            return
        }
        dive.photoFilenames.append(filename)
        try ctx.save()

        PhotoStore.migrateLocalPhotosToCloudKit(dive: dive, context: ctx)
        try ctx.save()
        let firstCount = dive.photos?.count ?? 0

        PhotoStore.migrateLocalPhotosToCloudKit(dive: dive, context: ctx)
        try ctx.save()
        let secondCount = dive.photos?.count ?? 0

        #expect(firstCount == 1)
        #expect(secondCount == 1)
    }
}
