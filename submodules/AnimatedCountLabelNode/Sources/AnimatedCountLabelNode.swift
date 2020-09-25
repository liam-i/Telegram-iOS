import Foundation
import UIKit
import Display
import AsyncDisplayKit

public class AnimatedCountLabelNode: ASDisplayNode {
    public struct Layout {
        public var size: CGSize
        public var isTruncated: Bool
    }
    
    public enum Segment: Equatable {
        public enum Key: Hashable {
            case number
            case text(Int)
        }
        
        case number(Int, NSAttributedString)
        case text(Int, NSAttributedString)
        
        public static func ==(lhs: Segment, rhs: Segment) -> Bool {
            switch lhs {
            case let .number(number, text):
                if case let .number(rhsNumber, rhsText) = rhs, number == rhsNumber, text.isEqual(to: rhsText) {
                    return true
                } else {
                    return false
                }
            case let .text(index, text):
                if case let .text(rhsIndex, rhsText) = rhs, index == rhsIndex, text.isEqual(to: rhsText) {
                    return true
                } else {
                    return false
                }
            }
        }
        
        public var attributedText: NSAttributedString {
            switch self {
            case let .number(_, text):
                return text
            case let .text(_, text):
                return text
            }
        }
        
        var key: Key {
            switch self {
            case .number:
                return .number
            case let .text(index, _):
                return .text(index)
            }
        }
    }
    
    private var segments: [Segment.Key: (Segment, TextNode)] = [:]
    
    override public init() {
        super.init()
    }
    
    public func asyncLayout() -> (CGSize, [Segment]) -> (Layout, (Bool) -> Void) {
        var segmentLayouts: [Segment.Key: (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode)] = [:]
        for (segmentKey, segmentAndTextNode) in self.segments {
            segmentLayouts[segmentKey] = TextNode.asyncLayout(segmentAndTextNode.1)
        }
        
        return { [weak self] size, segments in
            for segment in segments {
                if segmentLayouts[segment.key] == nil {
                    segmentLayouts[segment.key] = TextNode.asyncLayout(nil)
                }
            }
            
            var contentSize = CGSize()
            var remainingSize = size
            
            var calculatedSegments: [Segment.Key: (TextNodeLayout, () -> TextNode)] = [:]
            var isTruncated = false
            
            var validKeys: [Segment.Key] = []
            
            for segment in segments {
                validKeys.append(segment.key)
                let (layout, apply) = segmentLayouts[segment.key]!(TextNodeLayoutArguments(attributedString: segment.attributedText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: remainingSize, alignment: .left, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets(), lineColor: nil, textShadowColor: nil, textStroke: nil))
                calculatedSegments[segment.key] = (layout, apply)
                contentSize.width += layout.size.width
                contentSize.height = max(contentSize.height, layout.size.height)
                remainingSize.width = max(0.0, remainingSize.width - layout.size.width)
                if layout.truncated {
                    isTruncated = true
                }
            }
            
            return (Layout(size: contentSize, isTruncated: isTruncated), { animated in
                guard let strongSelf = self else {
                    return
                }
                let transition: ContainedViewLayoutTransition
                if animated {
                    transition = .animated(duration: 0.2, curve: .easeInOut)
                } else {
                    transition = .immediate
                }
                
                var currentOffset = CGPoint()
                for segment in segments {
                    var animation: (CGFloat, Double)?
                    if let (currentSegment, currentTextNode) = strongSelf.segments[segment.key] {
                        if case let .number(currentValue, _) = currentSegment, case let .number(updatedValue, _) = segment, animated, currentValue != updatedValue, let snapshot = currentTextNode.layer.snapshotContentTree() {
                            let offsetY: CGFloat
                            if currentValue > updatedValue {
                                offsetY = -floor(currentTextNode.bounds.height * 0.6)
                            } else {
                                offsetY = floor(currentTextNode.bounds.height * 0.6)
                            }
                            animation = (-offsetY, 0.2)
                            snapshot.frame = currentTextNode.frame
                            strongSelf.layer.addSublayer(snapshot)
                            snapshot.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: offsetY), duration: 0.2, removeOnCompletion: false, additive: true)
                            snapshot.animateScale(from: 1.0, to: 0.3, duration: 0.2, removeOnCompletion: false)
                            snapshot.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshot] _ in
                                snapshot?.removeFromSuperlayer()
                            })
                        }
                    }
                    
                    let (layout, apply) = calculatedSegments[segment.key]!
                    let textNode = apply()
                    let textFrame = CGRect(origin: currentOffset, size: layout.size)
                    if textNode.frame.isEmpty {
                        textNode.frame = textFrame
                        if animated, animation == nil {
                            textNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                            textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                    } else {
                        transition.updateFrameAdditive(node: textNode, frame: textFrame)
                    }
                    currentOffset.x += layout.size.width
                    if let (_, currentTextNode) = strongSelf.segments[segment.key] {
                        if currentTextNode !== textNode {
                            currentTextNode.removeFromSupernode()
                            strongSelf.addSubnode(textNode)
                        }
                    } else {
                        strongSelf.addSubnode(textNode)
                        textNode.displaysAsynchronously = false
                        textNode.isUserInteractionEnabled = false
                    }
                    if let (offset, duration) = animation {
                        textNode.layer.animatePosition(from: CGPoint(x: 0.0, y: offset), to: CGPoint(), duration: duration, additive: true)
                        textNode.layer.animateScale(from: 0.3, to: 1.0, duration: duration)
                        textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
                    }
                    strongSelf.segments[segment.key] = (segment, textNode)
                }
                
                var removeKeys: [Segment.Key] = []
                for key in strongSelf.segments.keys {
                    if !validKeys.contains(key) {
                        removeKeys.append(key)
                    }
                }
                
                for key in removeKeys {
                    guard let (_, textNode) = strongSelf.segments.removeValue(forKey: key) else {
                        continue
                    }
                    if animated {
                        textNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
                        textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak textNode] _ in
                            textNode?.removeFromSupernode()
                        })
                    } else {
                        textNode.removeFromSupernode()
                    }
                }
            })
        }
    }
}

public final class ImmediateAnimatedCountLabelNode: AnimatedCountLabelNode {
    public var segments: [AnimatedCountLabelNode.Segment] = []
    
    private var constrainedSize: CGSize?
    
    public func updateLayout(size: CGSize, animated: Bool) -> CGSize {
        self.constrainedSize = size
        
        let makeLayout = self.asyncLayout()
        let (layout, apply) = makeLayout(size, self.segments)
        let _ = apply(animated)
        return layout.size
    }
    
    public func makeCopy() -> ASDisplayNode {
        let node = ImmediateAnimatedCountLabelNode()
        node.segments = self.segments
        if let constrainedSize = self.constrainedSize {
            let _ = node.updateLayout(size: constrainedSize, animated: false)
        }
        return node
    }
}
