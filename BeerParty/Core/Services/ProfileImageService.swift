import Foundation
import UIKit
import Supabase

enum ProfileImageError: LocalizedError {
  case invalidImageData
  case unableToCompress
  case imageTooLarge

  var errorDescription: String? {
    switch self {
    case .invalidImageData:
      return "Selected file is not a valid image."
    case .unableToCompress:
      return "Could not compress image. Please choose a different photo."
    case .imageTooLarge:
      return "Image is too large. Please pick a smaller photo."
    }
  }
}

struct ProfileImageService {
  static let maxProfileImageBytes = 300 * 1024
  private let bucketName = "profile_pics"

  func normalizeForUpload(_ rawData: Data) throws -> Data {
    guard let image = UIImage(data: rawData) else {
      throw ProfileImageError.invalidImageData
    }

    let maxDimension: CGFloat = 720
    let resized = resize(image: image, maxDimension: maxDimension)

    var quality: CGFloat = 0.82
    while quality >= 0.35 {
      if let jpeg = resized.jpegData(compressionQuality: quality), jpeg.count <= Self.maxProfileImageBytes {
        return jpeg
      }
      quality -= 0.12
    }

    throw ProfileImageError.imageTooLarge
  }

  // Uploads under a new file name, so the photo's link changes and no phone or
  // cache keeps showing the old picture. Returns the path to save in the profile.
  func uploadProfileImage(_ imageData: Data, userId: UUID, at date: Date = Date()) async throws -> String {
    let newPath = ProfilePhotoPath.newPath(userID: userId, at: date)

    do {
      _ = try await supabase.storage
        .from(bucketName)
        .upload(
          newPath,
          data: imageData,
          options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
      return newPath
    } catch {
      // The bucket's rules are not in the repo. If they only allow the old file
      // name, save there as before rather than fail the whole profile save.
      let legacyPath = ProfilePhotoPath.legacyPath(userID: userId)
      _ = try await supabase.storage
        .from(bucketName)
        .upload(
          legacyPath,
          data: imageData,
          options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
      return legacyPath
    }
  }

  // Deletes a photo that the profile no longer points at. Best effort: a file
  // that could not be deleted is left behind and nothing is shown to the user.
  func removeProfileImage(path: String) async {
    _ = try? await supabase.storage.from(bucketName).remove(paths: [path])
  }

  func publicImageURL(for path: String?) -> URL? {
    guard let path, !path.isEmpty else { return nil }
    return try? supabase.storage.from(bucketName).getPublicURL(path: path)
  }

  private func resize(image: UIImage, maxDimension: CGFloat) -> UIImage {
    let originalSize = image.size
    let longestSide = max(originalSize.width, originalSize.height)
    guard longestSide > maxDimension else { return image }

    let scale = maxDimension / longestSide
    let targetSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)

    let renderer = UIGraphicsImageRenderer(size: targetSize)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
  }
}
