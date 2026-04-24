//
//  FileStorageManager.swift
//  letstalkAI
//
//  Manages file storage for documents
//

import Foundation
import PDFKit
import NaturalLanguage
import CoreGraphics
import Vision

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct PDFPageContent: Sendable {
    let pageIndex: Int
    let text: String
    let imageURLs: [URL]
    let imageOCRTexts: [String]
    let imageClassifications: [[String]]
}

struct PDFExtractionResult: Sendable {
    let text: String
    let pageContents: [PDFPageContent]
    let totalImages: Int
}

struct ImageOCRResult: Sendable {
    let imageURL: URL
    let ocrText: String
    let classificationLabels: [String]
    let pageIndex: Int
}

private class ImageExtractionContext {
    let manager: FileStorageManager
    let pageIndex: Int
    let outputDir: URL
    var extractedURLs: [URL] = []
    var imageIndex: Int = 0
    
    init(manager: FileStorageManager, pageIndex: Int, outputDir: URL) {
        self.manager = manager
        self.pageIndex = pageIndex
        self.outputDir = outputDir
    }
}

final class FileStorageManager: @unchecked Sendable {
    
    private let imagesDirectory: URL = {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("DocumentImages")
    }()
    
    init() {
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }
    
    func extractTextFromPDF(at url: URL) throws -> String {
        print("   📖 [PDF Extraction] Opening PDF: \(url.lastPathComponent)")
        
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        print("   📖 [PDF Extraction] Security scoped access: \(shouldStopAccessing ? "granted" : "not required")")
        
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("   ❌ [PDF Extraction] File not found")
            throw DocumentError.fileNotFound
        }
        
        guard let pdfDocument = PDFDocument(url: url) else {
            print("   ❌ [PDF Extraction] Failed to open PDF document")
            throw DocumentError.extractionFailed
        }
        
        let pageCount = pdfDocument.pageCount
        print("   📖 [PDF Extraction] PDF has \(pageCount) pages")
        
        var extractedText = ""
        var pagesWithText = 0
        
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            if let pageText = page.string, !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                extractedText += pageText + "\n"
                pagesWithText += 1
            }
        }
        
        print("   📖 [PDF Extraction] Extracted text from \(pagesWithText)/\(pageCount) pages")
        
        guard !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("   ❌ [PDF Extraction] No text content found in PDF")
            throw DocumentError.extractionFailed
        }
        
        print("   ✅ [PDF Extraction] Successfully extracted \(extractedText.count) characters")
        return extractedText
    }
    
    func extractContentFromPDF(at url: URL, documentId: String) throws -> PDFExtractionResult {
        print("   📖 [PDF Extraction] Opening PDF with embedded image extraction: \(url.lastPathComponent)")
        
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DocumentError.fileNotFound
        }
        
        guard let pdfDocument = PDFDocument(url: url),
              let cgPDF = CGPDFDocument(url as CFURL) else {
            throw DocumentError.extractionFailed
        }
        
        let pageCount = pdfDocument.pageCount
        print("   📖 [PDF Extraction] PDF has \(pageCount) pages")
        
        var allText = ""
        var pageContents: [PDFPageContent] = []
        var totalImages = 0
        
        let documentImagesDir = imagesDirectory.appendingPathComponent(documentId)
        try? FileManager.default.createDirectory(at: documentImagesDir, withIntermediateDirectories: true)
        
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex),
                  let cgPage = cgPDF.page(at: pageIndex + 1) else { continue }
            
            let pageText = page.string ?? ""
            var imageURLs: [URL] = []
            var imageOCRTexts: [String] = []
            
            let extractedImages = extractEmbeddedImages(from: cgPage, pageIndex: pageIndex, documentId: documentId, documentImagesDir: documentImagesDir)
            var imageClassifications: [[String]] = []
            
            if !extractedImages.isEmpty {
                print("   🖼️ [PDF Extraction] Page \(pageIndex + 1): Found \(extractedImages.count) embedded image(s)")
                
                for imageURL in extractedImages {
                    imageURLs.append(imageURL)
                    totalImages += 1
                    
                    let ocrText = performOCR(on: imageURL)
                    imageOCRTexts.append(ocrText)
                    
                    let labels = classifyImage(at: imageURL)
                    imageClassifications.append(labels)
                    
                    if !ocrText.isEmpty {
                        print("   🔍 [OCR] Image: \(ocrText.prefix(50))...")
                    }
                }
            }
            
            var combinedPageText = pageText
            
            for (index, ocrText) in imageOCRTexts.enumerated() {
                if !ocrText.isEmpty {
                    combinedPageText += "\n[Image \(index + 1) on Page \(pageIndex + 1): \(ocrText)]"
                }
            }
            
            if !combinedPageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                allText += "[Page \(pageIndex + 1)]\n\(combinedPageText)\n\n"
                print("   📖 [PDF Extraction] Page \(pageIndex + 1): \(pageText.count) text chars, \(imageURLs.count) images")
            }
            
            pageContents.append(PDFPageContent(
                pageIndex: pageIndex,
                text: combinedPageText,
                imageURLs: imageURLs,
                imageOCRTexts: imageOCRTexts,
                imageClassifications: imageClassifications
            ))
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 [PDF Extraction Summary]")
        print("   📄 Total pages: \(pageCount)")
        print("   🖼️ Total images extracted: \(totalImages)")
        print("   📝 Total text chars: \(allText.count)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        return PDFExtractionResult(
            text: allText,
            pageContents: pageContents,
            totalImages: totalImages
        )
    }
    
    private func extractEmbeddedImages(from page: CGPDFPage, pageIndex: Int, documentId: String, documentImagesDir: URL) -> [URL] {
        let context = ImageExtractionContext(manager: self, pageIndex: pageIndex, outputDir: documentImagesDir)
        
        guard let pageDictionary = page.dictionary else { return [] }
        
        var resourcesDict: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(pageDictionary, "Resources", &resourcesDict),
              let resources = resourcesDict else { return [] }
        
        var xObjectDict: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(resources, "XObject", &xObjectDict),
              let xObjects = xObjectDict else { return [] }
        
        let contextPtr = Unmanaged.passUnretained(context).toOpaque()
        
        CGPDFDictionaryApplyBlock(xObjects, { (key, object, info) -> Bool in
            guard let info = info else { return true }
            let context = Unmanaged<ImageExtractionContext>.fromOpaque(info).takeUnretainedValue()
            
            var stream: CGPDFStreamRef?
            guard CGPDFObjectGetValue(object, .stream, &stream), let pdfStream = stream else {
                return true
            }
            
            guard let streamDict = CGPDFStreamGetDictionary(pdfStream) else {
                return true
            }
            
            var subtypeName: UnsafePointer<CChar>?
            guard CGPDFDictionaryGetName(streamDict, "Subtype", &subtypeName),
                  let subtype = subtypeName,
                  String(cString: subtype) == "Image" else {
                return true
            }
            
            var width: CGPDFInteger = 0
            var height: CGPDFInteger = 0
            CGPDFDictionaryGetInteger(streamDict, "Width", &width)
            CGPDFDictionaryGetInteger(streamDict, "Height", &height)
            
            let minSize: CGPDFInteger = 100
            guard width >= minSize && height >= minSize else {
                return true
            }
            
            let aspectRatio = Double(width) / Double(height)
            guard aspectRatio >= 0.2 && aspectRatio <= 5.0 else {
                return true
            }
            
            var format: CGPDFDataFormat = .raw
            guard let data = CGPDFStreamCopyData(pdfStream, &format) else {
                return true
            }
            
            let imageData = data as Data
            
            if let image = context.manager.createImage(from: imageData, width: Int(width), height: Int(height), format: format, streamDict: streamDict) {
                
                if context.manager.isLikelyBackgroundImage(image) {
                    return true
                }
                
                let fileName = "img_p\(context.pageIndex + 1)_\(context.imageIndex).jpg"
                let imageURL = context.outputDir.appendingPathComponent(fileName)
                
                if context.manager.saveImage(image, to: imageURL) {
                    context.extractedURLs.append(imageURL)
                    context.imageIndex += 1
                }
            }
            
            return true
        }, contextPtr)
        
        return context.extractedURLs
    }
    
    private func createImage(from data: Data, width: Int, height: Int, format: CGPDFDataFormat, streamDict: CGPDFDictionaryRef) -> CGImage? {
        var colorSpaceName: UnsafePointer<CChar>?
        var bitsPerComponent: CGPDFInteger = 8
        CGPDFDictionaryGetInteger(streamDict, "BitsPerComponent", &bitsPerComponent)
        
        var colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        
        if CGPDFDictionaryGetName(streamDict, "ColorSpace", &colorSpaceName), let csName = colorSpaceName {
            let csString = String(cString: csName)
            if csString == "DeviceGray" {
                colorSpace = CGColorSpaceCreateDeviceGray()
            } else if csString == "DeviceCMYK" {
                colorSpace = CGColorSpaceCreateDeviceCMYK()
            }
        }
        
        if format == .JPEG2000 || format == .jpegEncoded {
            #if os(iOS)
            if let uiImage = UIImage(data: data) {
                return uiImage.cgImage
            }
            #elseif os(macOS)
            if let nsImage = NSImage(data: data) {
                var rect = NSRect(x: 0, y: 0, width: nsImage.size.width, height: nsImage.size.height)
                return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
            }
            #endif
        }
        
        let componentsPerPixel = colorSpace.numberOfComponents
        let bytesPerRow = width * componentsPerPixel * Int(bitsPerComponent) / 8
        
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        
        let bitmapInfo: CGBitmapInfo = componentsPerPixel == 1 ? [] : CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: Int(bitsPerComponent),
            bitsPerPixel: Int(bitsPerComponent) * componentsPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
    
    private func saveImage(_ cgImage: CGImage, to url: URL) -> Bool {
        #if os(iOS)
        let uiImage = UIImage(cgImage: cgImage)
        guard let data = uiImage.jpegData(compressionQuality: 0.85) else { return false }
        #elseif os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            return false
        }
        #endif
        
        do {
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }
    
    func isLikelyBackgroundImage(_ cgImage: CGImage) -> Bool {
        let width = cgImage.width
        let height = cgImage.height
        
        let sampleSize = 10
        guard width > sampleSize * 2 && height > sampleSize * 2 else { return false }
        
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return false
        }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        guard bytesPerPixel >= 3 else { return false }
        
        var colors: [(r: Int, g: Int, b: Int)] = []
        
        let stepX = width / sampleSize
        let stepY = height / sampleSize
        
        for y in stride(from: stepY, to: height - stepY, by: stepY) {
            for x in stride(from: stepX, to: width - stepX, by: stepX) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = Int(bytes[offset])
                let g = Int(bytes[offset + 1])
                let b = Int(bytes[offset + 2])
                colors.append((r, g, b))
            }
        }
        
        guard colors.count >= 9 else { return false }
        
        let avgR = colors.map { $0.r }.reduce(0, +) / colors.count
        let avgG = colors.map { $0.g }.reduce(0, +) / colors.count
        let avgB = colors.map { $0.b }.reduce(0, +) / colors.count
        
        var variance = 0
        for color in colors {
            variance += abs(color.r - avgR) + abs(color.g - avgG) + abs(color.b - avgB)
        }
        variance /= colors.count
        
        let isUniform = variance < 30
        
        let isSkyLike = avgB > avgR && avgB > avgG && avgB > 150 && variance < 50
        
        let isGrayGradient = abs(avgR - avgG) < 20 && abs(avgG - avgB) < 20 && variance < 40
        
        if isUniform || isSkyLike || isGrayGradient {
            print("   🚫 [Filter] Skipping background/uniform image (variance: \(variance), RGB: \(avgR),\(avgG),\(avgB))")
            return true
        }
        
        return false
    }
    
    private func performOCR(on imageURL: URL) -> String {
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            return ""
        }
        
        #if os(iOS)
        guard let uiImage = UIImage(contentsOfFile: imageURL.path),
              let cgImage = uiImage.cgImage else {
            return ""
        }
        #elseif os(macOS)
        guard let nsImage = NSImage(contentsOf: imageURL),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ""
        }
        #endif
        
        var ocrText = ""
        let semaphore = DispatchSemaphore(value: 0)
        
        let request = VNRecognizeTextRequest { request, error in
            defer { semaphore.signal() }
            
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            ocrText = recognizedStrings.joined(separator: " ")
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("   ⚠️ [OCR] Failed: \(error.localizedDescription)")
                semaphore.signal()
            }
        }
        
        _ = semaphore.wait(timeout: .now() + 10.0)
        
        return ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func classifyImage(at imageURL: URL) -> [String] {
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            return []
        }
        
        #if os(iOS)
        guard let uiImage = UIImage(contentsOfFile: imageURL.path),
              let cgImage = uiImage.cgImage else {
            return []
        }
        #elseif os(macOS)
        guard let nsImage = NSImage(contentsOf: imageURL),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }
        #endif
        
        var labels: [String] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        let request = VNClassifyImageRequest { request, error in
            defer { semaphore.signal() }
            
            guard error == nil,
                  let observations = request.results as? [VNClassificationObservation] else {
                return
            }
            
            let topLabels = observations
                .filter { $0.confidence > 0.3 }
                .prefix(10)
                .map { $0.identifier.lowercased().replacingOccurrences(of: "_", with: " ") }
            
            labels = Array(topLabels)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("   ⚠️ [Classification] Failed: \(error.localizedDescription)")
                semaphore.signal()
            }
        }
        
        _ = semaphore.wait(timeout: .now() + 10.0)
        
        if !labels.isEmpty {
            print("   🏷️ [Classification] Labels: \(labels.prefix(5).joined(separator: ", "))")
        }
        
        return labels
    }
    
    private func renderPageAsImage(page: PDFPage, pageIndex: Int, documentId: String, documentImagesDir: URL) -> URL? {
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        
        #if os(iOS)
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            
            context.cgContext.translateBy(x: 0, y: scaledSize.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { return nil }
        #elseif os(macOS)
        let image = NSImage(size: scaledSize)
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }
        
        NSColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: scaledSize))
        
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        
        image.unlockFocus()
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return nil
        }
        #endif
        
        let imageFileName = "page_\(pageIndex + 1).jpg"
        let imageURL = documentImagesDir.appendingPathComponent(imageFileName)
        
        do {
            try imageData.write(to: imageURL)
            return imageURL
        } catch {
            print("   ⚠️ [PDF Extraction] Failed to save page image: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getImagesForDocument(_ documentId: String) -> [URL] {
        let documentImagesDir = imagesDirectory.appendingPathComponent(documentId)
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: documentImagesDir, includingPropertiesForKeys: nil) else {
            return []
        }
        
        return files.filter { $0.pathExtension.lowercased() == "jpg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
    
    func deleteImagesForDocument(_ documentId: String) {
        let documentImagesDir = imagesDirectory.appendingPathComponent(documentId)
        try? FileManager.default.removeItem(at: documentImagesDir)
    }
    
    func chunkText(_ text: String, maxChunkSize: Int = 3500, overlapTokens: Int = 125) -> [String] {
        let maxTokens = maxChunkSize / 4
        
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { sentence in
                sentence.hasSuffix(".") || sentence.hasSuffix("!") || sentence.hasSuffix("?") ?
                sentence : sentence + "."
            }
        
        var chunks: [String] = []
        var currentChunk = ""
        var currentTokenCount = 0
        var previousChunkSentences: [String] = []
        
        for sentence in sentences {
            let sentenceTokenCount = countTokens(in: sentence)
            let potentialChunk = currentChunk.isEmpty ? sentence : currentChunk + " " + sentence
            let potentialTokenCount = currentTokenCount + sentenceTokenCount + (currentChunk.isEmpty ? 0 : 1)
            
            if potentialTokenCount <= maxTokens {
                currentChunk = potentialChunk
                currentTokenCount = potentialTokenCount
            } else {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                    
                    let chunkSentences = currentChunk.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    previousChunkSentences = chunkSentences
                }
                
                var overlapText = ""
                var overlapTokenCount = 0
                
                if !previousChunkSentences.isEmpty && chunks.count > 0 {
                    for sentenceIndex in stride(from: previousChunkSentences.count - 1, through: 0, by: -1) {
                        let overlapSentence = previousChunkSentences[sentenceIndex]
                        let overlapSentenceTokens = countTokens(in: overlapSentence)
                        
                        if overlapTokenCount + overlapSentenceTokens <= overlapTokens {
                            overlapText = overlapSentence + (overlapText.isEmpty ? "" : " " + overlapText)
                            overlapTokenCount += overlapSentenceTokens
                        } else {
                            break
                        }
                    }
                }
                
                if sentenceTokenCount <= maxTokens {
                    if !overlapText.isEmpty {
                        currentChunk = overlapText + " " + sentence
                        currentTokenCount = overlapTokenCount + sentenceTokenCount + 1
                    } else {
                        currentChunk = sentence
                        currentTokenCount = sentenceTokenCount
                    }
                } else {
                    let words = sentence.components(separatedBy: .whitespaces)
                    var truncatedSentence = ""
                    var truncatedTokenCount = 0
                    
                    for word in words {
                        let wordTokenCount = countTokens(in: word)
                        if truncatedTokenCount + wordTokenCount <= maxTokens {
                            truncatedSentence += (truncatedSentence.isEmpty ? "" : " ") + word
                            truncatedTokenCount += wordTokenCount
                        } else {
                            break
                        }
                    }
                    
                    if !truncatedSentence.isEmpty {
                        if !truncatedSentence.hasSuffix(".") && !truncatedSentence.hasSuffix("!") && !truncatedSentence.hasSuffix("?") {
                            truncatedSentence += "."
                        }
                        chunks.append(truncatedSentence)
                    }
                    currentChunk = ""
                    currentTokenCount = 0
                }
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks.filter { !$0.isEmpty }
    }
    
    private func countTokens(in text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        let tokens = tokenizer.tokens(for: text.startIndex..<text.endIndex)
        return tokens.count
    }
    
    func saveDocument(_ data: Data, fileName: String) throws -> URL {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw DocumentError.saveFailed
        }
        
        let fileURL = documentsDirectory.appendingPathComponent("Documents").appendingPathComponent(fileName)
        
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL)
        
        return fileURL
    }
}
