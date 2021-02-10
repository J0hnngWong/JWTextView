//
//  JWTextView.swift
//  CoreTextDemo
//
//  Created by J0hnnyWong on 2020/12/28.
//  Copyright © 2020 Johnny. All rights reserved.
//

import UIKit

public class JWTextView: UIView {
    
    private var clickHandler: ((JWDataProtocol) -> ())?
    
    public var config = JWTextViewConfig() {
        didSet {
            // 重绘
            // need redraw
            setNeedsDisplay()
        }
    }
    
    public var textConfigs: [JWConfigProtocol] = [] {
        didSet {
            needRedrawText()
            setNeedsDisplay()
        }
    }
    
    var attributedString: NSAttributedString = NSAttributedString(string: "") {
        didSet {
            needRedrawAttributedText()
        }
    }
    
    private var data: JWTextViewData?
    
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        contentMode = .redraw
        performDraw()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupTapGesture()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTapGesture()
    }
    
    /// 文字更改重绘文字内容
    /// redraw the text
    func needRedrawText() {
        let resolveData = JWTextViewResolver.resolveText(from: textConfigs, width: config.width)
        config.width = jw_width
        data = resolveData
        jw_setHeight(height: resolveData.height)
    }
    
    func needRedrawAttributedText() {
        let resolveData = JWTextViewConfigResolver.resolveConfig(with: attributedString, width: config.width)
        config.width = jw_width
        data = resolveData
        jw_setHeight(height: resolveData.height)
    }
}

extension JWTextView {
    
    func performDraw() {
        drawText()
        drawImage()
    }
    
    func drawText() {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        // 因为坐标系是相反的，所以要翻转坐标系，元坐标系原点为左下角，现翻转至左上角
        // because the coordinate system is different from UIKit, so we need to revert it to coord system of UIKit, move the origin point from left bottom corner to left top corner.
        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)
        if let ctFrame = data?.ctFrame {
            CTFrameDraw(ctFrame, context)
        }
    }
    
    func drawImage() {
        for view in subviews {
            view.removeFromSuperview()
        }
        for imageInfo in data?.imageDataList ?? [] {
            guard let imageData = imageInfo.imageData else { continue }
            let image = UIImage(data: imageData)
            let imageView = UIImageView(frame: imageInfo.imagePosition)
            imageView.image = image
            addSubview(imageView)
        }
    }

}

extension JWTextView: UIGestureRecognizerDelegate {
    
    func setupTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(JWTextView.tapEventHandler(sender:)))
        tap.delegate = self
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }
    
    @objc
    func tapEventHandler(sender: UIGestureRecognizer?) {
        guard
            let point = sender?.location(in: self),
            let dataTmp = data
        else { return }
        
        if let clickData = JWTextViewGestureResolver.tapGestuer(in: self, point: point, data: dataTmp) {
            if let linkData = clickData as? JWLinkTextData {
                debugPrint("click on : \(linkData.uri)")
                clickHandler?(linkData)
            } else if let textData = clickData as? JWCharacterTextData {
                debugPrint("click on text: \(textData.content)")
                clickHandler?(textData)
            } else {
                debugPrint("click on position: \(point)")
            }
        }
    }
    
}

// MARK: resolver class

class JWTextViewResolver {
    
    static func resolveText(from configArray: [JWConfigProtocol], width: CGFloat) -> JWTextViewData {
        
        let result = NSMutableAttributedString()
        var commonTxtConfig = JWTextViewTextConfig()
        
        var linkDataList: [JWLinkTextData] = []
        var textDataList: [JWTextTextData] = []
        var imageDataList: [JWImageViewData] = []
        
        for item in configArray {
            
            let startPos = result.length
            
            if let textConfig = item as? JWTextViewTextConfig {
                
                let textAtt = JWTextViewConfigResolver.resolveText(with: textConfig)
                result.append(textAtt)
                commonTxtConfig = textConfig
                
                let length = result.length - startPos
                let textData = JWTextTextData(content: textConfig.content, range: NSRange(location: startPos, length: length))
                textDataList.append(textData)
                
            } else if let linkConfig = item as? JWLinkTextConfig {
                
                let linkAtt = JWTextViewLinkResolver.resolveLinkData(from: linkConfig)
                result.append(linkAtt)
                
                let length = result.length - startPos
                let linkData = JWLinkTextData(content: linkConfig.content, uri: linkConfig.link, range: NSRange(location: startPos, length: length))
                linkDataList.append(linkData)
                
            } else if let imageConfig = item as? JWImageViewConfig {
                
                let imageAtt = JWTextViewImageResolver.resolveImageData(from: imageConfig, textConfig: commonTxtConfig)
                result.append(imageAtt)
                
                let length = result.length - startPos
                var imageData = JWImageViewData(imagePosition: .zero, uri: imageConfig.resouceAddress, range: NSRange(location: startPos, length: length))
                imageData.imageSize = CGSize(width: imageConfig.width, height: imageConfig.height)
                imageDataList.append(imageData)
            }
        }
        var data = JWTextViewConfigResolver.resolveConfig(with: result, width: width)
        if let ctFrameTmp = data.ctFrame {
            JWTextViewImageResolver.fillImageData(from: ctFrameTmp, imageArray: &imageDataList)
        }
        data.rawAttributedString = result
        data.linkDataList = linkDataList
        data.textDataList = textDataList
        data.imageDataList = imageDataList
        return data
    }
}

class JWTextViewConfigResolver {
    
    static func resolveConfig(with text: String, config: JWTextViewTextConfig) -> JWTextViewData {
        let attributedStr = NSAttributedString(string: text, attributes: JWTextViewConfigResolver.resolveAttributed(from: config))
        let data = JWTextViewConfigResolver.resolveConfig(with: attributedStr, width: config.width)
        return data
    }
    
    static func resolveText(with config: JWTextViewTextConfig) -> NSAttributedString {
        let attributedStr = NSAttributedString(string: config.content, attributes: JWTextViewConfigResolver.resolveAttributed(from: config))
        return attributedStr
    }
    
    static func resolveConfig(with attributedText: NSAttributedString, width: CGFloat) -> JWTextViewData {
        let cfAttrubutedString = attributedText as CFAttributedString
        let frameSetter = CTFramesetterCreateWithAttributedString(cfAttrubutedString)
        
        // 获得绘制区域的高度
        // TODO: 如果需要固定高度，变动的宽度就改这边的内容，让其适应变宽
        let constraintSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let ctFrameSuggestFrame = CTFramesetterSuggestFrameSizeWithConstraints(frameSetter, CFRangeMake(0, 0), nil, constraintSize, nil)
        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: width, height: ctFrameSuggestFrame.height))
        
        let ctFrame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, 0), path, nil)
        
        let data = JWTextViewData(height: ctFrameSuggestFrame.height, ctFrame: ctFrame)
        
        return data
    }
    
    static func resolveAttributed(from config: JWTextViewTextConfig) -> [NSAttributedString.Key: Any]? {
        
        let fontRef = CTFontCreateWithName(config.fontName as CFString, config.fontSize, nil)
        let lineSpace = config.lineSpace
        let cGFloatByteCount = MemoryLayout<CGFloat>.stride(ofValue: config.lineSpace)
        let cGFloatAlignment = MemoryLayout<CGFloat>.alignment(ofValue: config.lineSpace)
        let lineSpacePointer = UnsafeMutableRawPointer.allocate(byteCount: cGFloatByteCount, alignment: cGFloatAlignment)
        lineSpacePointer.storeBytes(of: lineSpace, as: CGFloat.self)
        defer {
            lineSpacePointer.deallocate()
        }
        
        let kNumberOfSettings = 3
        var paragraphSetting: [CTParagraphStyleSetting] = [
            CTParagraphStyleSetting(spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.size, value: lineSpacePointer),
            CTParagraphStyleSetting(spec: .maximumLineSpacing, valueSize: MemoryLayout<CGFloat>.size, value: lineSpacePointer),
            CTParagraphStyleSetting(spec: .minimumLineSpacing, valueSize: MemoryLayout<CGFloat>.size, value: lineSpacePointer)
        ]
        
        let paragraphStyleRef = CTParagraphStyleCreate(&paragraphSetting, kNumberOfSettings)
        
        let dict: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTForegroundColorAttributeName as String) : config.textColor.cgColor,
            NSAttributedString.Key(kCTFontFamilyNameAttribute as String): fontRef,
//            NSAttributedString.Key(kCTFontSizeAttribute as String): config.fontSize,
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraphStyleRef,
        ]
        
        return dict
    }
}

class JWTextViewImageResolver {
    
    static var ascentCallback: CTRunDelegateGetAscentCallback = { (data) in
        let dict = data.load(as: [String: Any].self)
        return dict["height"] as? CGFloat ?? 0
    }
    
    static var descentCallback: CTRunDelegateGetDescentCallback = { (data) in
        return 0
    }
    
    static var widthCallback: CTRunDelegateGetWidthCallback = { (data) in
        let dict = data.load(as: [String: Any].self)
        return dict["width"] as? CGFloat ?? 0
    }
    
    static var deallocateCallback: CTRunDelegateDeallocateCallback = { (data) in
        data.deallocate()
    }
    
    static func resolveImageData(from imageConfig: JWImageViewConfig, textConfig: JWTextViewTextConfig) -> NSAttributedString {
        
        var callbacks = CTRunDelegateCallbacks(version: kCTRunDelegateVersion1, dealloc: { (pointer) in
            pointer.deallocate()
        }, getAscent: { (pointer) -> CGFloat in
            let imageCfg = pointer.load(as: JWImageViewConfig.self)
            return imageCfg.height
        }, getDescent: { (pointer) -> CGFloat in
            return 0
        }, getWidth: { (pointer) -> CGFloat in
            let imageCfg = pointer.load(as: JWImageViewConfig.self)
            return imageCfg.width
        })
        
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<JWImageViewConfig>.stride, alignment: MemoryLayout<JWImageViewConfig>.alignment)
        pointer.storeBytes(of: imageConfig, as: JWImageViewConfig.self)
        let delegate = CTRunDelegateCreate(&callbacks, pointer)
        
        // 图片在文字中的占位符
        var objectReplacementChar = unichar(0xFFFC)
        let content = NSString(characters: &objectReplacementChar, length: 1)
        let attributes = JWTextViewConfigResolver.resolveAttributed(from: textConfig)
        
        let space = NSMutableAttributedString(string: content as String, attributes: attributes)
        CFAttributedStringSetAttribute(space as CFMutableAttributedString, CFRangeMake(0, 1), kCTRunDelegateAttributeName, delegate)
        return space
    }
    
    static func fillImageData(from ctFrame: CTFrame, imageArray: inout [JWImageViewData]) {
        if imageArray.count <= 0 {
            return
        }
        let lines = CTFrameGetLines(ctFrame)
        let linesCount = CFArrayGetCount(lines)
        var lineOrigins = [CGPoint](repeating: .zero, count: linesCount)
        CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), &lineOrigins)
        
        var imgIndex = 0
        
        var imageData: JWImageViewData?
        imageData = imageArray.first
        
        for index in 0...linesCount-1 {
            guard let _ = imageData else { return }
            
            guard let linePointer = CFArrayGetValueAtIndex(lines, index) else { continue }
            let linePointerPointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<UnsafeRawPointer>.stride, alignment: MemoryLayout<UnsafeRawPointer>.alignment)
            linePointerPointer.storeBytes(of: linePointer, as: UnsafeRawPointer.self)
            let line = linePointerPointer.load(as: CTLine.self)
            let runObjArray = CTLineGetGlyphRuns(line)
            
            for runIndex in 0...CFArrayGetCount(runObjArray)-1 {
//                let run = CFArrayGetValueAtIndex(runObjArray, runIndex).load(as: CTRun.self)
                guard let runPointer = CFArrayGetValueAtIndex(runObjArray, runIndex) else { continue }
                let runPointerPointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<UnsafeRawPointer>.stride, alignment: MemoryLayout<UnsafeRawPointer>.alignment)
                runPointerPointer.storeBytes(of: runPointer, as: UnsafeRawPointer.self)
                let run = runPointerPointer.load(as: CTRun.self)
                let runAttributes = CTRunGetAttributes(run)
                let key = kCTRunDelegateAttributeName
                
//                let keyPointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<CFString>.stride, alignment: MemoryLayout<CFString>.alignment)
//                keyPointer.storeBytes(of: key, as: CFString.self)
//                guard let delegatePointer = CFDictionaryGetValue(runAttributes, keyPointer) else { continue }
//                let delegate = delegatePointer.load(as: CTRunDelegate.self)
                
                guard let delegate = (runAttributes as Dictionary)[key] as! CTRunDelegate? else { continue }
                let metaConfigPointer = CTRunDelegateGetRefCon(delegate)
                let metaConfigPointerPointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<UnsafeRawPointer>.stride, alignment: MemoryLayout<UnsafeRawPointer>.alignment)
                metaConfigPointerPointer.storeBytes(of: metaConfigPointer, as: UnsafeRawPointer.self)
                var metaConfig = metaConfigPointer.load(as: JWImageViewConfig.self)
                
                var runBounds = CGRect.zero
                var ascent = CGFloat(0)
                var descent = CGFloat(0)
                runBounds.size.width = CGFloat(CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, nil))
                runBounds.size.height = ascent + descent
                
                let xOffset = CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, nil)
                runBounds.origin.x = lineOrigins[runIndex].x + xOffset
                runBounds.origin.y = lineOrigins[runIndex].y
                runBounds.origin.y -= descent
                
                let pathRef = CTFrameGetPath(ctFrame)
                let colRect = pathRef.boundingBox
                
                let delegateBounds = runBounds.offsetBy(dx: colRect.origin.x, dy: colRect.origin.y)
                
                if imgIndex >= imageArray.count {
                    break
                } else {
                    metaConfig.imagePosition = delegateBounds
                    imageArray[imgIndex].updateData(from: metaConfig)
                    imgIndex += 1
                }
                
//                imageData?.imagePosition = delegateBounds
//                metaConfig.imagePosition = delegateBounds
//                imageArray[imgIndex].imagePosition = delegateBounds
//                imgIndex += 1
//                if imgIndex == imageArray.count {
//                    imageData = nil
//                    break
//                } else {
//                    imageData = imageArray[imgIndex]
//                }
            }
        }
        
    }
}

class JWTextViewLinkResolver {
    
    static func resolveLinkData(from linkConfig: JWLinkTextConfig) -> NSAttributedString {
        let linkAttributeString = NSAttributedString(string: linkConfig.content, attributes: JWTextViewLinkResolver.resolveAttributed(from: linkConfig))
        return linkAttributeString
    }
    
    static func resolveAttributed(from config: JWLinkTextConfig) -> [NSAttributedString.Key: Any]? {
            
        let fontRef = CTFontCreateWithName(config.fontName as CFString, config.fontSize, nil)
        let lineSpace = config.lineSpace
        let cGFloatByteCount = MemoryLayout<CGFloat>.stride(ofValue: config.lineSpace)
        let cGFloatAlignment = MemoryLayout<CGFloat>.alignment(ofValue: config.lineSpace)
        let lineSpacePointer = UnsafeMutableRawPointer.allocate(byteCount: cGFloatByteCount, alignment: cGFloatAlignment)
        lineSpacePointer.storeBytes(of: lineSpace, as: CGFloat.self)
        defer {
            lineSpacePointer.deallocate()
        }
        
        let kNumberOfSettings = 3
        var paragraphSetting: [CTParagraphStyleSetting] = [
            CTParagraphStyleSetting(spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.size, value: lineSpacePointer),
            CTParagraphStyleSetting(spec: .maximumLineSpacing, valueSize: MemoryLayout<CGFloat>.size, value: lineSpacePointer),
            CTParagraphStyleSetting(spec: .minimumLineSpacing, valueSize: MemoryLayout<CGFloat>.size, value: lineSpacePointer)
        ]
        
        let paragraphStyleRef = CTParagraphStyleCreate(&paragraphSetting, kNumberOfSettings)
        
        let dict: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTForegroundColorAttributeName as String) : config.textColor.cgColor,
            NSAttributedString.Key(kCTFontFamilyNameAttribute as String): fontRef,
//            NSAttributedString.Key(kCTFontSizeAttribute as String): config.fontSize,
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraphStyleRef,
        ]
        
        return dict
    }
}

// MARK: tap geture resolver

class JWTextViewGestureResolver {
    
    static func tapGestuer(in view: UIView, point: CGPoint, data: JWTextViewData) -> JWDataProtocol? {
        guard let textFrame = data.ctFrame else { return nil }
        let lines = CTFrameGetLines(textFrame)
        let lineCount = CFArrayGetCount(lines)
        if lineCount <= 0 { return nil }
        
        // 获取每一行的origin
        var origins = [CGPoint](repeating: .zero, count: lineCount)
        // range 传0会从头复制到尾
        CTFrameGetLineOrigins(textFrame, CFRangeMake(0, 0), &origins)
        
        // 翻转坐标
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: 0, y: view.bounds.size.height)
        transform = transform.scaledBy(x: 1.0, y: -1.0)
        
        for index in 0...lineCount-1 {
            let linePoint = origins[index]
            guard let linePointer = CFArrayGetValueAtIndex(lines, index) else { continue }
            let linePointerPointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<UnsafeRawPointer>.stride, alignment: MemoryLayout<UnsafeRawPointer>.alignment)
            linePointerPointer.storeBytes(of: linePointer, as: UnsafeRawPointer.self)
            let line = linePointerPointer.load(as: CTLine.self)
            
//            let line = (lines as Array)[index] as! CTLine
            
            // 获得每一行的cgrect信息
            let flippedRect = JWTextViewGestureResolver.getLineBounds(with: line, point: linePoint)
            let rect = flippedRect.applying(transform)
            
            if rect.contains(point) {
                // 将点击的坐标转换成相对于当前行的坐标
                let relativePoint = CGPoint(x: point.x-rect.minX, y: point.y-rect.minY)
                // 获得当前点击坐标对应的字符串偏移
                let idx = CTLineGetStringIndexForPosition(line, relativePoint)
                // 判断这个偏移是否在我们的链接列表中
                if let foundLink = JWTextViewGestureResolver.textLink(at: idx, linkArray: data.linkDataList) {
                    return foundLink
                } else if let foundText = JWTextViewGestureResolver.text(at: idx, textArray: data.textDataList) {
                   return foundText
                } else if let foundCharacter = JWTextViewGestureResolver.character(at: idx, text: data.rawAttributedString ?? NSAttributedString()) {
                    return JWCharacterTextData(content: foundCharacter)
                }
            }
        }
        return nil
    }
    
    static func getLineBounds(with line: CTLine, point: CGPoint) -> CGRect {
        // 高度
        var ascent = CGFloat(0)
        // 下边距
        var descent = CGFloat(0)
        var leading = CGFloat(0)
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let height = ascent + descent
        return CGRect(x: point.x, y: point.y - descent, width: width, height: height)
    }
    
    static func textLink(at index: CFIndex, linkArray: [JWLinkTextData]) -> JWLinkTextData? {
        var link: JWLinkTextData?
        for data in linkArray {
            if NSLocationInRange(index, data.range) {
                link = data
                break
            }
        }
        return link
    }
    
    static func text(at index: CFIndex, textArray: [JWTextTextData]) -> JWTextTextData? {
        var text: JWTextTextData?
        for data in textArray {
            if NSLocationInRange(index, data.range) {
                text = data
                break
            }
        }
        return text
    }
    
    static func character(at index: CFIndex, text: NSAttributedString) -> String.Element? {
        return text.string[text.string.index(text.string.startIndex, offsetBy: index)]
    }
}

// MARK: struct

public struct JWTextViewConfig {
    public var width: CGFloat = 0
}

public struct JWTextViewTextConfig: JWConfigProtocol {
    
    public var content: String = ""
    public var width: CGFloat = 0
    public var fontSize: CGFloat = 0
    public var fontName: String = "System"
    public var lineSpace: CGFloat = 0
    public var textColor: UIColor = .black
    
    public init() {
    }
}

public struct JWImageViewConfig: JWConfigProtocol {
    
    public var imagePosition: CGRect = .zero
    public var width: CGFloat = 0
    public var height: CGFloat = 0
    public var resouceAddress: String = ""
    public var imageData: Data?
    
    public init() {
    }
}

public struct JWLinkTextConfig: JWConfigProtocol {
    
    public var content: String = ""
    public var link: String = ""
    public var range: NSRange = NSRange(location: 0, length: 0)
    public var fontSize: CGFloat = 0
    public var fontName: String = "System"
    public var lineSpace: CGFloat = 0
    public var textColor: UIColor = .black
    
    public init() {
    }
}

// character内部使用的data
struct JWCharacterTextData: JWDataProtocol {
    
    let type: JWTextViewDataType = .charater
    
    var content: String.Element = String.Element("")
}

// text内部使用的data
struct JWTextTextData: JWDataProtocol {
    
    let type: JWTextViewDataType = .text
    
    var content: String = ""
    var range: NSRange = NSRange(location: 0, length: 0)
}

// link内部使用的data
struct JWLinkTextData: JWDataProtocol {
    
    let type: JWTextViewDataType = .link
    
    var content: String = ""
    var uri: String = ""
    var range: NSRange = NSRange(location: 0, length: 0)
}

// image内部使用的data
struct JWImageViewData: JWDataProtocol {
    
    let type: JWTextViewDataType = .image
    
    var imagePosition: CGRect = .zero
    var imageSize: CGSize = .zero
    var uri: String = ""
    var imageData: Data?
    var range: NSRange = NSRange(location: 0, length: 0)
    
    mutating func updateData(from config: JWImageViewConfig) {
        imagePosition = config.imagePosition
        uri = config.resouceAddress
        imageData = config.imageData
    }
}

struct JWTextViewData {
    
    var height: CGFloat = 0
    var ctFrame: CTFrame?
    
    var rawAttributedString: NSMutableAttributedString?
    
    var textDataList: [JWTextTextData] = []
    var linkDataList: [JWLinkTextData] = []
    var imageDataList: [JWImageViewData] = []
}

// MARK: protocol

protocol JWDataProtocol {
    
    var type: JWTextViewDataType { get }
}


public protocol JWConfigProtocol {
}

// MARK: enum

enum JWTextViewDataType {
    case charater
    case text
    case link
    case image
}

// MARK: extension

extension UIView {
    var jw_x: CGFloat {
        frame.origin.x
    }
    
    var jw_y: CGFloat {
        frame.origin.y
    }
    
    var jw_width: CGFloat {
        frame.size.width
    }
    
    var jw_height: CGFloat {
        frame.size.height
    }
    
    func jw_setX(x: CGFloat) {
        frame = CGRect(x: x, y: jw_y, width: jw_width, height: jw_height)
    }
    
    func jw_setY(y: CGFloat) {
        frame = CGRect(x: jw_x, y: y, width: jw_width, height: jw_height)
    }
    
    func jw_setHeight(height: CGFloat) {
        frame = CGRect(x: jw_x, y: jw_y, width: jw_width, height: height)
    }
    
    func jw_setWidth(width: CGFloat) {
        frame = CGRect(x: jw_x, y: jw_y, width: width, height: jw_height)
    }
    
}
