#!/usr/bin/env swift
// Programmatically draws an elegant slate-gray app icon and writes all macOS
// iconset sizes. No external image assets required.
// Usage: swift Scripts/MakeIcon.swift <output_iconset_dir>

import AppKit
import Foundation

func drawIcon(into bitmap: NSBitmapImageRep) {
    let size = CGFloat(bitmap.pixelsWide)
    let ctx = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.2237  // matches Big Sur+ app icon mask
    let mask = NSBezierPath(roundedRect: rect,
                            xRadius: cornerRadius,
                            yRadius: cornerRadius)

    // 1) Background: brushed silver / steel gradient — matches the macOS
    //    System Settings icon family. Neutral grays, slight cool undertones.
    let bg = NSGradient(colors: [
        NSColor(red: 0.815, green: 0.830, blue: 0.850, alpha: 1.0),  // light silver top
        NSColor(red: 0.495, green: 0.510, blue: 0.535, alpha: 1.0)   // medium steel bottom
    ])!
    bg.draw(in: mask, angle: -90)

    // 2) Top arc highlight (subtle "glass" gloss)
    NSGraphicsContext.saveGraphicsState()
    mask.addClip()
    let gloss = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.22),
        NSColor.white.withAlphaComponent(0.0)
    ])!
    gloss.draw(in: NSRect(x: 0, y: size * 0.50,
                          width: size, height: size * 0.50),
               angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // 3) Hairline inner border ring (light, since background is silver)
    let ring = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.006, dy: size * 0.006),
                            xRadius: cornerRadius * 0.985,
                            yRadius: cornerRadius * 0.985)
    NSColor.white.withAlphaComponent(0.30).setStroke()
    ring.lineWidth = max(1, size * 0.005)
    ring.stroke()

    // 4) 3×3 grid — 8 outlined cells + 1 champagne-gray filled center cell
    let cellCount = 3
    let cellSize = size * 0.165
    let gap = size * 0.062
    let totalWidth = cellSize * CGFloat(cellCount) + gap * CGFloat(cellCount - 1)
    let originOffset = (size - totalWidth) / 2
    let cellRadius = cellSize * 0.30
    let strokeW = max(1, size * 0.012)

    // Charcoal strokes for the 8 outlined cells. The center cell is a soft
    // off-white "light" — reads as a highlight on the silver field instead
    // of a heavy block, keeping the icon airy and in-family with the BG.
    let outlineColor = NSColor(white: 0.18, alpha: 0.42)
    let centerFill = NSColor(red: 0.965, green: 0.970, blue: 0.978, alpha: 0.96) // cool ice white
    let centerInnerShadow = NSColor.black.withAlphaComponent(0.12)

    for row in 0..<cellCount {
        for col in 0..<cellCount {
            let x = originOffset + CGFloat(col) * (cellSize + gap)
            let y = originOffset + CGFloat(row) * (cellSize + gap)
            let cellRect = NSRect(x: x, y: y, width: cellSize, height: cellSize)
            let path = NSBezierPath(roundedRect: cellRect,
                                    xRadius: cellRadius,
                                    yRadius: cellRadius)

            if row == 1 && col == 1 {
                centerFill.setFill()
                path.fill()
                // tiny inset shadow stroke for tactile depth
                let inset = NSBezierPath(roundedRect: cellRect.insetBy(dx: strokeW * 0.6,
                                                                       dy: strokeW * 0.6),
                                         xRadius: cellRadius * 0.93,
                                         yRadius: cellRadius * 0.93)
                centerInnerShadow.setStroke()
                inset.lineWidth = strokeW * 0.4
                inset.stroke()
            } else {
                outlineColor.setStroke()
                path.lineWidth = strokeW
                path.stroke()
            }
        }
    }

    // 5) Faint bottom vignette for grounding
    NSGraphicsContext.saveGraphicsState()
    mask.addClip()
    let vignette = NSGradient(colors: [
        NSColor.black.withAlphaComponent(0.0),
        NSColor.black.withAlphaComponent(0.10)
    ])!
    vignette.draw(in: NSRect(x: 0, y: 0, width: size, height: size * 0.32),
                  angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
}

func writePNG(at pixelSize: Int, to url: URL) throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                        pixelsWide: pixelSize,
                                        pixelsHigh: pixelSize,
                                        bitsPerSample: 8,
                                        samplesPerPixel: 4,
                                        hasAlpha: true,
                                        isPlanar: false,
                                        colorSpaceName: .deviceRGB,
                                        bytesPerRow: 0,
                                        bitsPerPixel: 0) else {
        throw NSError(domain: "MakeIcon", code: 1)
    }
    drawIcon(into: bitmap)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "MakeIcon", code: 2)
    }
    try data.write(to: url)
}

// MARK: - Main

let args = CommandLine.arguments
let outDir = URL(fileURLWithPath: args.count > 1 ? args[1] : "AppIcon.iconset")
try? FileManager.default.createDirectory(at: outDir,
                                         withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, px) in entries {
    try writePNG(at: px, to: outDir.appendingPathComponent(name))
}
print("Wrote \(entries.count) PNGs to \(outDir.path)")
