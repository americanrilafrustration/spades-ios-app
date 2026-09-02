#!/usr/bin/env swift
import AppKit
import Foundation

let size: CGFloat = 1024
let output = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon-1024.png"

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let green = NSColor(red: 0.09, green: 0.36, blue: 0.22, alpha: 1)
let gold = NSColor(red: 0.91, green: 0.82, blue: 0.56, alpha: 1)

green.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()

let symbolSize = size * 0.62
let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)
guard let symbol = NSImage(systemSymbolName: "suit.spade.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) else {
    fputs("Failed to load spade symbol\n", stderr)
    exit(1)
}

let tinted = symbol.copy() as! NSImage
tinted.isTemplate = true
let drawSize = tinted.size
let scale = min(symbolSize / drawSize.width, symbolSize / drawSize.height)
let width = drawSize.width * scale
let height = drawSize.height * scale
let rect = NSRect(
    x: (size - width) / 2,
    y: (size - height) / 2,
    width: width,
    height: height
)
gold.set()
tinted.draw(in: rect)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
