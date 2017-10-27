//
//  ZomPhotoStreamViewController.swift
//  Zom
//
//  Created by N-Pex on 2017-06-14.
//
//

import UIKit
import ChatSecureCore
import INSPhotoGallery

open class ZomPhotoStreamViewController: UICollectionViewController {
    
    public var photos:[ZomPhotoStreamImage] = []
    
    fileprivate var assetGridThumbnailSize:CGSize = CGSize()
    private var loadingIndicator:UIActivityIndicatorView?
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        loadingIndicator = UIActivityIndicatorView(frame: self.view.frame)
        if let loadingIndicator = loadingIndicator {
            loadingIndicator.hidesWhenStopped = true
            loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
            loadingIndicator.startAnimating();
            view.addSubview(loadingIndicator)
        }
        
        OTRDatabaseManager.shared.readOnlyDatabaseConnection?.asyncRead({ (transaction) in
            var array:[OTRMediaItem] = [OTRMediaItem]()
            let collection = OTRMediaItem.collection
            let allMediaItemKeys = transaction.allKeys(inCollection: collection)
            allMediaItemKeys.forEach({ (key) in
                if let object = transaction.object(forKey: key, inCollection: collection) as? OTRImageItem {
                    array.append(object)
                }
            })
            if array.count > 0 {
                var photos:[ZomPhotoStreamImage] = [ZomPhotoStreamImage]()
                array.forEach({ (mediaItem) in
                    if mediaItem is OTRImageItem, let message = mediaItem.parentMessage(with: transaction), mediaItem.transferProgress == 1 {
                        
                        if let threadOwner = message.threadOwner(with: transaction) {
                            // Check that we have a data length, can be 0 for some reason
                            let threadIdentifier = threadOwner.threadIdentifier
                            do {
                                let dataLength = try OTRMediaFileManager.shared.dataLength(for: mediaItem, buddyUniqueId: threadIdentifier)
                                if dataLength.intValue > 0 {
                                    let p = ZomPhotoStreamImage(mediaItem: mediaItem, message: message, threadOwner:threadOwner)
                                    photos.append(p)
                                }
                            } catch {
                            }
                        }
                    }
                })
                photos.sort(by: { (item1, item2) -> Bool in
                    return item1.date().compare(item2.date()) == .orderedAscending
                })
                self.photos = photos
                DispatchQueue.main.async {
                    self.collectionView?.reloadData()
                    self.loadingIndicator?.stopAnimating()
                }
            }
        });
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Determine the size of the thumbnails to request from the PHCachingImageManager
        let scale:CGFloat = UIScreen.main.scale
        let cellSize:CGSize = (self.collectionViewLayout as! UICollectionViewFlowLayout).itemSize;
        assetGridThumbnailSize = CGSize(width: cellSize.width * scale, height: cellSize.height * scale);
    }
    
    // Mark - UICollectionViewDataSource
    
    open override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    open override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let photo = photos[indexPath.item]
        let cell:ZomPhotoStreamCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! ZomPhotoStreamCell
        cell.populateWithPhoto(photo)
        return cell
    }
    
    open override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = self.collectionView?.cellForItem(at: indexPath)  as! ZomPhotoStreamCell
        let initialPhoto = photos[indexPath.row]
        let browser = ZomPhotosViewController(photos: photos, initialPhoto:initialPhoto, referenceView:cell.imageView)
        browser.referenceViewForPhotoWhenDismissingHandler = { [weak self] photo in
            if let index = self?.photos.index(where: {$0 === photo}) {
                let indexPath = IndexPath(item: index, section: 0)
                return (collectionView.cellForItem(at: indexPath) as? ZomPhotoStreamCell)?.imageView
            }
            return nil
        }
        self.present(browser, animated: true, completion: nil)
    }
}
