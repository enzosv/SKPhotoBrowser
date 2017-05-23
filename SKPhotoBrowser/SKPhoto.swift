//
//  SKPhoto.swift
//  SKViewExample
//
//  Created by suzuki_keishi on 2015/10/01.
//  Copyright © 2015 suzuki_keishi. All rights reserved.
//

import UIKit

@objc public protocol SKPhotoProtocol: NSObjectProtocol {
	var underlyingImage: UIImage! { get }
	var caption: String! { get }
	var index: Int { get set}
	var contentMode: UIViewContentMode { get set }
	func loadUnderlyingImageAndNotify()
	func checkCache()
}

// MARK: - SKPhoto
open class SKPhoto: NSObject, SKPhotoProtocol {
	
	open var underlyingImage: UIImage!
	open var photoURL: String!
	open var contentMode: UIViewContentMode = .scaleAspectFill
	open var shouldCachePhotoURLImage: Bool = false
	open var caption: String!
	open var index: Int = 0
	open var padding:CGFloat?
	
	open var headers:[String:Any]?
	
	override init() {
		super.init()
	}
	
	convenience init(image: UIImage) {
		self.init()
		underlyingImage = image
	}
	
	convenience init(url: String) {
		self.init()
		photoURL = url
	}
	
	convenience init(url: String, holder: UIImage?) {
		self.init()
		photoURL = url
		underlyingImage = holder
	}
	
	convenience init(url:String, headers:[String:Any]) {
		self.init()
		photoURL = url
		self.headers = headers
	}
	
	open func checkCache() {
		guard let photoURL = photoURL else {
			return
		}
		guard shouldCachePhotoURLImage else {
			return
		}
		
		if SKCache.sharedCache.imageCache is SKRequestResponseCacheable {
			let request = URLRequest(url: URL(string: photoURL)!)
			if let img = SKCache.sharedCache.imageForRequest(request) {
				underlyingImage = img
			}
		} else {
			if let img = SKCache.sharedCache.imageForKey(photoURL) {
				underlyingImage = img
			}
		}
	}
	
	open func loadUnderlyingImageAndNotify() {
		guard photoURL != nil, let URL = URL(string: photoURL) else { return }
		
		// Fetch Image
		let session = URLSession(configuration: URLSessionConfiguration.default)
		
		var task: URLSessionTask?
		var mutableRequest = NSMutableURLRequest(url: URL)
		if let h = headers{
			for (key, value) in h{
				mutableRequest.setValue(value as? String ?? "", forHTTPHeaderField: key)
			}
		}
		
		task = session.dataTask(with: mutableRequest as URLRequest, completionHandler: { [weak self] (data, response, error) in
			guard let `self` = self else { return }
			
			defer { session.finishTasksAndInvalidate() }
			
			guard error == nil else {
				DispatchQueue.main.async {
					self.loadUnderlyingImageComplete()
				}
				return
			}
			
			if let data = data, let response = response, let image = UIImage(data: data) {
				var paddedImage:UIImage?
				if let padding = self.padding{
					let width: CGFloat = image.size.width + padding
					let height: CGFloat = image.size.height + padding
					UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0.0)
					let context: CGContext = UIGraphicsGetCurrentContext()!
					UIGraphicsPushContext(context)
					let origin: CGPoint = CGPoint(x: (width - image.size.width) * 0.5, y: (height - image.size.height) * 0.5)
					image.draw(at: origin)
					UIGraphicsPopContext()
					paddedImage = UIGraphicsGetImageFromCurrentImageContext()
					UIGraphicsEndImageContext()
				}
				
				
				if self.shouldCachePhotoURLImage {
					if SKCache.sharedCache.imageCache is SKRequestResponseCacheable {
						SKCache.sharedCache.setImageData(data, response: response, request: task?.originalRequest)
					} else {
						SKCache.sharedCache.setImage(image, forKey: self.photoURL)
					}
				}
				DispatchQueue.main.async {
					self.underlyingImage = paddedImage ?? image
					self.loadUnderlyingImageComplete()
				}
			}
			
		})
		task?.resume()
	}
	
	open func loadUnderlyingImageComplete() {
		NotificationCenter.default.post(name: Notification.Name(rawValue: SKPHOTO_LOADING_DID_END_NOTIFICATION), object: self)
	}
	
}

// MARK: - Static Function

extension SKPhoto {
	public static func photoWithImage(_ image: UIImage) -> SKPhoto {
		return SKPhoto(image: image)
	}
	
	public static func photoWithImageURL(_ url: String) -> SKPhoto {
		return SKPhoto(url: url)
	}
	
	public static func photoWithImageURL(_ url: String, holder: UIImage?) -> SKPhoto {
		return SKPhoto(url: url, holder: holder)
	}
	
	public static func photoWithImageURL(_ url: String, headers: [String:Any]) -> SKPhoto{
		return SKPhoto(url: url, headers: headers)
	}
}
