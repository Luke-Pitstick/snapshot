import AppKit
import CoreGraphics

/// A finished screenshot ready to be handed to the `ResultRouter`.
struct CaptureResult {
    let cgImage: CGImage
    let createdAt: Date

    init(cgImage: CGImage, createdAt: Date = Date()) {
        self.cgImage = cgImage
        self.createdAt = createdAt
    }

    var nsImage: NSImage {
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
    }

    /// PNG bytes — used for clipboard + drag-out + save.
    var pngData: Data? {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    /// `Snapshot 2026-04-10 at 2.15.03 PM.png` — matches the native format.
    var defaultFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' h.mm.ss a"
        return "Snapshot \(formatter.string(from: createdAt)).png"
    }
}
