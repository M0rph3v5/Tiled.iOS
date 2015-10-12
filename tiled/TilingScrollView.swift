//
//  TilingScrollView.swift
//  tiledviewer
//
//  Created by Benjamin de Jager on 12/5/14.
//  Copyright (c) 2014 Q42. All rights reserved.
//

import UIKit

protocol TilingScrollViewDataSource {
  func tilingScrollView(tilingScrollView: TilingScrollView, imageForColumn column: Int, andRow row: Int, forScale scale: CGFloat) -> UIImage?
}

class TilingScrollView: UIScrollView, UIScrollViewDelegate, TilingViewDataSource {
  
  private var pointToCenterAfterResize: CGPoint!
  private var scaleToRestoreAfterResize: CGFloat!
  
  private var delegateProxy = DelegateProxy()
  private var tilingView: TilingView! // actual tiling view
  
//  override var delegate: UIScrollViewDelegate? {
//    get {
//      return delegateProxy.userDelegate
//    }
//    set {
//      delegateProxy.userDelegate = newValue;
//    }
//  }
  
  var dataSource: TilingScrollViewDataSource? {
    didSet {
      tilingView.dataSource = self
    }
  }
  
  var tileSize: CGSize = CGSizeZero {
    didSet {
      tilingView.tileSize = tileSize
    }
  }
  var levelsOfDetail: Int = 0 {
    didSet {
      tilingView.levelsOfDetail = levelsOfDetail
    }
  }
  var imageSize: CGSize! {
    didSet {
      zoomScale = 1
      
      imageView.frame.size = imageSize
      tilingView.frame = imageView.bounds
      contentSize = tilingView.frame.size
      setMaxMinZoomScalesForCurrentBounds()
      if fillMode {
        centerAnimated(true, horizontalOnly: false)
      }
    }
  }
  
  var imageView: TilingImageView! // hold thumbnail
  
  var fillMode: Bool = false
  var widthIsCropped: Bool = false
  
  var tilingEnabled: Bool = true {
    didSet {
      tilingView.hidden = !tilingEnabled
    }
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    initialize()
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    initialize()
  }
  
  func initialize() {
    delegate = self
    
    imageView = TilingImageView(frame: bounds);
    addSubview(imageView)
    
    tilingView = TilingView(frame: bounds);
    imageView.addSubview(tilingView)
  }
  
  // MARK: Actions

  func setMaxMinZoomScalesForCurrentBounds() {
    let tilingViewSize = tilingView.bounds.size
    let boundsSize = CGSize(
      width: CGRectGetWidth(bounds) - (contentInset.left + contentInset.right),
      height: CGRectGetHeight(bounds) - (contentInset.top + contentInset.bottom))
    
    let xScale = boundsSize.width / tilingViewSize.width
    let yScale = boundsSize.height / tilingViewSize.height
    
    let maxScale:CGFloat = 1.0 // / UIScreen.mainScreen().scale
    var minScale = min(xScale, yScale)
    if minScale > maxScale {
      minScale = maxScale
    }
    
    maximumZoomScale = maxScale
    minimumZoomScale = minScale
    
    if fillMode {
      zoomScale = max(xScale, yScale)
      widthIsCropped = zoomScale == yScale
    } else {
      zoomScale = minimumZoomScale
    }
  }
  
  func centerAnimated(animated: Bool, horizontalOnly: Bool) {
    setContentOffset(CGPoint(
      x: contentSize.width/2 - CGRectGetWidth(frame)/2,
      y: horizontalOnly ? contentOffset.y : contentSize.height/2 - CGRectGetHeight(frame)/2), animated: animated)
  }
  
  func zoomToRect(zoomRect: CGRect, zoomOutWhenZoomedIn:Bool, animated: Bool) {
    if CGRectIntersectsRect(tilingView.bounds, zoomRect) {
      
      let zoomScaleX = (bounds.size.width - contentInset.left - contentInset.right) / zoomRect.size.width
      let zoomScaleY = (bounds.size.height - contentInset.top - contentInset.bottom) / zoomRect.size.height
      let zoomScale = min(maximumZoomScale, min(zoomScaleX, zoomScaleY))
      
      if !zoomOutWhenZoomedIn || fabs(zoomScale - zoomScale) > fabs(zoomScale - minimumZoomScale) {
        zoomToRect(zoomRect, animated: true)
      } else {
        setZoomScale(minimumZoomScale, animated: true)
      }
    }
  }
  
  // MARK: rotation support methods
  
  func prepareToResize() {
    let boundsCenter = CGPoint(x: CGRectGetMidX(bounds), y: CGRectGetMidY(bounds))
    pointToCenterAfterResize = convertPoint(boundsCenter, toView: imageView)
    scaleToRestoreAfterResize = zoomScale
    
    if scaleToRestoreAfterResize <= (minimumZoomScale + CGFloat(FLT_EPSILON)) {
      scaleToRestoreAfterResize = 0
    }
  }
  
  func recoverFromResizing() {
    setMaxMinZoomScalesForCurrentBounds()
    
    let maxZoomScale = max(minimumZoomScale, scaleToRestoreAfterResize)
    let zoomScale = min(maximumZoomScale, maxZoomScale)
    self.zoomScale = zoomScale
    
    let boundsCenter = convertPoint(pointToCenterAfterResize, toView: imageView)
    var offset = CGPoint(
      x: boundsCenter.x - bounds.size.width / 2.0,
      y: boundsCenter.y - bounds.size.height / 2.0)
    
    let maxOffset = maximumContentOffset()
    let minOffset = minimumContentOffset()
    
    var realMaxOffset = min(maxOffset.x, offset.x)
    offset.x = max(minOffset.x, realMaxOffset)
    
    realMaxOffset = min(maxOffset.y, offset.y)
    offset.y = max(minOffset.y, realMaxOffset)
  }
  
  func maximumContentOffset() -> CGPoint {
    let contentSize = self.contentSize
    let boundsSize = bounds.size;
    return CGPoint(x: contentSize.width - boundsSize.width, y: contentSize.height - boundsSize.height);
  }
  
  func minimumContentOffset() -> CGPoint {
    return CGPoint.zero;
  }
  
  // MARK: scrollview delegate methods
  func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
    return imageView
  }
  
  func scrollViewDidZoom(scrollView: UIScrollView) {
    
    var top:CGFloat = 0, left:CGFloat = 0
    if (contentSize.width < bounds.size.width) {
      left = (bounds.size.width-contentSize.width) * 0.5
    }
    if (contentSize.height < bounds.size.height) {
      top = (bounds.size.height-contentSize.height) * 0.5
    }
    contentInset = UIEdgeInsetsMake(top, left, top, left)

  }

  override var frame: CGRect { // might need bounds override with same methods
    willSet {
      if !CGSizeEqualToSize(frame.size, frame.size) {
        prepareToResize()
      }
    }
    
    didSet {
      if !CGSizeEqualToSize(frame.size, frame.size) {
        recoverFromResizing()
      }
    }
  }

  // MARK: tilingview data source
  
  func tilingView(tilingView: TilingView, imageForColumn column: Int, andRow row: Int, forScale scale: CGFloat) -> UIImage? {
    return dataSource?.tilingScrollView(self, imageForColumn: column, andRow: row, forScale: scale)
  }
}




