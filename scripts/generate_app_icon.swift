#!/usr/bin/env swift
import AppKit
import Foundation

func spadePath(in rect: NSRect) -> NSBezierPath {
    let w = rect.width
    let h = rect.height
    let x = rect.minX
    let y = rect.minY

    let body = NSBezierPath()
    body.move(to: NSPoint(x: x + w * 0.5, y: y + h * 0.93))
    body.line(to: NSPoint(x: x + w * 0.5, y: y + h * 0.56))
    body.curve(
        to: NSPoint(x: x + w * 0.1, y: y + h * 0.36),
        controlPoint1: NSPoint(x: x + w * 0.5, y: y + h * 0.56),
        controlPoint2: NSPoint(x: x + w * 0.1, y: y + h * 0.52)
    )
    body.curve(
        to: NSPoint(x: x + w * 0.5, y: y + h * 0.06),
        controlPoint1: NSPoint(x: x + w * 0.1, y: y + h * 0.12),
        controlPoint2: NSPoint(x: x + w * 0.26, y: y + h * 0.06)
    )
    body.curve(
        to: NSPoint(x: x + w * 0.9, y: y + h * 0.36),
        controlPoint1: NSPoint(x: x + w * 0.74, y: y + h * 0.06),
        controlPoint2: NSPoint(x: x + w * 0.9, y: y + h * 0.12)
    )
    body.curve(
        to: NSPoint(x: x + w * 0.5, y: y + h * 0.56),
        controlPoint1: NSPoint(x: x + w * 0.9, y: y + h * 0.52),
        controlPoint2: NSPoint(x: x + w * 0.5, y: y + h * 0.56)
    )
    body.close()

    let base = NSBezierPath()
    base.move(to: NSPoint(x: x + w * 0.26, y: y + h * 0.76))
    base.line(to: NSPoint(x: x + w * 0.74, y: y + h * 0.76))
    base.line(to: NSPoint(x: x + w * 0.64, y: y + h * 0.93))
    base.line(to: NSPoint(x: x + w * 0.36, y: y + h * 0.93))
    base.close()

    body.append(base)
    return body
}

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

let inset = size * 0.18
let spadeRect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
gold.setFill()
spadePath(in: spadeRect).fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
