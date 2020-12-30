//
//  JWTextView.swift
//  CoreTextDemo
//
//  Created by 王嘉宁 on 2020/12/28.
//  Copyright © 2020 Johnny. All rights reserved.
//

import UIKit

class JWTextView: UIView {
    
    public var clickHandler: ((JWDataProtocol) -> ())?
    
    var config = JWTextViewConfig() {
        didSet {
            // 重绘
            // need redraw
            setNeedsDisplay()
        }
    }
    
    var textConfigs: [JWConfigProtocol] = [] {
        didSet {
            needRedrawText()
        }
    }
    
    var attributedString: NSAttributedString = NSAttributedString(string: "") {
        didSet {
            needRedrawAttributedText()
        }
    }
    
    private var data: JWTextViewData?
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        contentMode = .redraw
        drawText()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTapGesture()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTapGesture()
    }
    
    /// 文字更改重绘文字内容
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
                print("click on : \(linkData.uri)")
                clickHandler?(linkData)
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
        
        for item in configArray {
            
            let startPos = result.length
            
            if let textConfig = item as? JWTextViewTextConfig {
                
                let textAtt = JWTextViewConfigResolver.resolveText(with: textConfig)
                result.append(textAtt)
                commonTxtConfig = textConfig
                
            } else if let linkConfig = item as? JWLinkTextConfig {
                
                let linkAtt = JWTextViewLinkResolver.resolveLinkData(from: linkConfig)
                result.append(linkAtt)
                
                let length = result.length - startPos
                let linkData = JWLinkTextData(content: linkConfig.content, uri: linkConfig.link, range: NSRange(location: startPos, length: length))
                linkDataList.append(linkData)
                
            } else if let imageConfig = item as? JWImageViewConfig {
                
                let imageAtt = JWTextViewImageResolver.resolveImageData(from: imageConfig, textConfig: commonTxtConfig)
                result.append(imageAtt)
                
            }
        }
        var data = JWTextViewConfigResolver.resolveConfig(with: result, width: width)
        data.linkDataList = linkDataList
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
    
    static func fillImageData(from ctFrame: CTFrame, imageArray: inout [JWImageViewConfig]) {
        if imageArray.count <= 0 {
            return
        }
        let lines = CTFrameGetLines(ctFrame)
        let linesCount = CFArrayGetCount(lines)
        var lineOrigins = [CGPoint](repeating: .zero, count: linesCount)
        CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), &lineOrigins)
        
        var imgIndex = 0
        
        var imageData: JWImageViewConfig?
        imageData = imageArray.first
        
        for index in 0...linesCount-1 {
            guard let _ = imageData else { return }
            let line = CFArrayGetValueAtIndex(lines, index).load(as: CTLine.self)
            let runObjArray = CTLineGetGlyphRuns(line)
            
            for runIndex in 0...CFArrayGetCount(runObjArray)-1 {
                let run = CFArrayGetValueAtIndex(runObjArray, runIndex).load(as: CTRun.self)
//                let runAttributes = CTRunGetAttributes(run)
//                var key = kCTRunDelegateAttributeName
//                guard let delegatePointer = CFDictionaryGetValue(runAttributes, &key) else { continue }
//                let delegate = delegatePointer.load(as: CTRunDelegate.self)
//                let metaConfig = CTRunDelegateGetRefCon(delegate)
//                if !(metaConfig is JWImageViewConfig) {
//                    continue
//                }
                
                var runBounds = CGRect.zero
                var ascent = CGFloat(0)
                var descent = CGFloat(0)
                CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, nil)
                runBounds.size.height = ascent + descent
                
                let xOffset = CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, nil)
                runBounds.origin.x = lineOrigins[runIndex].x + xOffset
                runBounds.origin.y = lineOrigins[runIndex].y
                runBounds.origin.y -= descent
                
                let pathRef = CTFrameGetPath(ctFrame)
                let colRect = pathRef.boundingBox
                
                let delegateBounds = runBounds.offsetBy(dx: colRect.origin.x, dy: colRect.origin.y)
                
                imageData?.imagePosition = delegateBounds
                imgIndex += 1
                if imgIndex == imageArray.count {
                    imageData = nil
                    break
                } else {
                    imageData = imageArray[imgIndex]
                }
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
        let foundLink: JWLinkTextData?
        
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
                foundLink = JWTextViewGestureResolver.textLink(at: idx, linkArray: data.linkDataList)
                return foundLink
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
}

// MARK: struct

struct JWTextViewConfig {
    var width: CGFloat = 0
}

struct JWTextViewTextConfig: JWConfigProtocol {
    
    var content: String = ""
    var width: CGFloat = 0
    var fontSize: CGFloat = 0
    var fontName: String = "System"
    var lineSpace: CGFloat = 0
    var textColor: UIColor = .black
}

struct JWImageViewConfig: JWConfigProtocol {
    
    var imagePosition: CGRect = .zero
    var width: CGFloat = 0
    var height: CGFloat = 0
    var resouceAddress: String = ""
}

struct JWLinkTextConfig: JWConfigProtocol {
    
    var content: String = ""
    var link: String = ""
    var range: NSRange = NSRange(location: 0, length: 0)
    var fontSize: CGFloat = 0
    var fontName: String = "System"
    var lineSpace: CGFloat = 0
    var textColor: UIColor = .black
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
    var uri: String = ""
    var range: NSRange = NSRange(location: 0, length: 0)
}

struct JWTextViewData {
    
    var height: CGFloat = 0
    var ctFrame: CTFrame?
    
    var linkDataList: [JWLinkTextData] = []
}

// MARK: protocol

protocol JWDataProtocol {
    
    var type: JWTextViewDataType { get }
}

protocol JWConfigProtocol {
}

// MARK: enum

enum JWTextViewDataType {
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