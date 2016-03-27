//
//  PhotoAlbumViewController.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/13/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController {

    struct Constants {
        static let SpanDeltaLongitude: CLLocationDegrees = 2
        static let CellVerticalSpacing: CGFloat = 4
    }
    
    var SpanDeltaLatitude: CLLocationDegrees {
        let mapViewRatio = mapView.frame.height / mapView.frame.width
        return Constants.SpanDeltaLongitude * Double(mapViewRatio)
    }
    
    var localityName: String?
    var annotationToShow: PinAnnotation!

    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
        }
    }
    
    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            collectionView.delegate = self
            collectionView.dataSource = self
        }
    }
    
    //connecting to the collection view's flow layout object enables its customization
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStack.sharedInstance.managedObjectContect
    }

    lazy var fetchedResultsContoller: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.annotationToShow)
        fetchRequest.sortDescriptors = []  //without at least something in the sortDescriptors, a crash will result (per the documentation: a fetch request "must contain at least one sort descriptor to order the results."
        
        let contoller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        return contoller
    }()
    
    ///this method determines the cell layout (and does do differently depending on whether the device is in portrait or landscape mode) and is called when "viewDidLayoutSubviews" is called (which happens multiple times throughout the view controller's lifecycle, as well as when the device is phycially rotated)
    func layoutCells() {
        var cellWidth: CGFloat
        var numWide: CGFloat
        
        //sets the number of cells to display horizontally in each row based on the device's orientation
        switch UIDevice.currentDevice().orientation {
        case .Portrait:
            numWide = 3
        case .PortraitUpsideDown:
            numWide = 3
        case .LandscapeLeft:
            numWide = 4
        case .LandscapeRight:
            numWide = 4
        default:
            numWide = 4
        }
        
        //sets the cell width to be dependent upon the number of cells that will be displayed in each row, as determined directly above
        cellWidth = collectionView.frame.width / numWide
        
        //updates the cell width to account for the desired cell spacing (a predetermined constant, defined in the Constants struct), then updates the itemSize accordingly
        cellWidth -= Constants.CellVerticalSpacing
        flowLayout.itemSize.width = cellWidth
        flowLayout.itemSize.height = cellWidth
        flowLayout.minimumInteritemSpacing = Constants.CellVerticalSpacing
        
        //calculates the actual vertical spacing between cells, accounting for the additional vertical space that was subtracted from the cell width (e.g. if there are 3 cells, there are only 2 vertical spaces, not 3); then by setting the line spacing to be equal to this "actual" value, the vertical and horizontal distances between cells should be exact (or as close to exact as possible)
        let actualCellVerticalSpacing: CGFloat = (collectionView.frame.width - (numWide * cellWidth))/(numWide - 1)
        flowLayout.minimumLineSpacing = actualCellVerticalSpacing
        
        //causes the collection view to invalidate its current layout and relay out the collection view using the new settings in the flow layout (without this call, the cells don't properly resize upon rotation)
        flowLayout.invalidateLayout()
    }
    
    func callAlert(title: String, message: String, alertHandler: ((UIAlertAction) -> Void)?, presentationCompletionHandler: (() -> Void)?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: alertHandler))
        presentViewController(alertController, animated: true, completion: presentationCompletionHandler)
    }
    
    //MARK: VIEW CONTROLLER METHODS
    
    override func viewDidLayoutSubviews() {
        layoutCells()
    }
    
    //MARK: VIEW CONTROLLER LIFECYCLE
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
    
        print(annotationToShow.photos?.count)
        if let ann = annotationToShow.photos?.first {
            print(ann.photoID)
            print(ann.flickrURL)
            print(ann.photoURLonDisk)
        } else {
            print("empty")
        }
        
        fetchedResultsContoller.delegate = self
        
        do {
            try fetchedResultsContoller.performFetch()
        } catch {}
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        mapView.region = MKCoordinateRegion(center: annotationToShow.coordinate, span: MKCoordinateSpan(latitudeDelta: SpanDeltaLatitude, longitudeDelta: Constants.SpanDeltaLongitude))
        mapView.addAnnotation(annotationToShow)
        
        if localityName != nil {
            title = localityName
        } else {
            title = "Photos"
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
    }
}

//MARK: COLLECTION VIEW DELEGATE & DATASOURCE METHODS

extension PhotoAlbumViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    //Collection View DataSource Methods
    
    //required
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let section = fetchedResultsContoller.sections?[section] {
            print("objects: \(section.numberOfObjects)")
            return section.numberOfObjects
        } else {
            return 0
        }
    }
    
    //required
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
        cell.layer.borderWidth = 1
        cell.layer.borderColor = UIColor.blackColor().CGColor
        cell.layer.cornerRadius = 5
        cell.imageView.clipsToBounds = true
        cell.imageView.contentMode = .ScaleAspectFill
       
        
        let photoObjectToDisplay = fetchedResultsContoller.objectAtIndexPath(indexPath) as! Photo
       
        if let photoImage = photoObjectToDisplay.photoImage {
            cell.imageView.image = photoImage
            print("photo loaded")
        } else {
            FlickrClient.sharedInstance.getImageForUrl(photoObjectToDisplay.flickrURL, completionHandler: { (data, error) in
                guard error == nil else {
                    return
                }
                
                if let photoData = data {
                    let photo = UIImage(data: photoData)
                    dispatch_async(dispatch_get_main_queue()) {
                        print("photo DOWNLOADED")
                        cell.imageView.image = photo
                        photoObjectToDisplay.photoImage = photo
                    }
                }
            })
        }
        
        return cell
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return fetchedResultsContoller.sections?.count ?? 1
    }
    
    //Collection View Delegate Methods
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        print("MARK FOR DELETE!")
    }
}

//MARK: FETCHEDCONTROLLER DELEGATE METHODS

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        
    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
    }
    
}

//MARK: MAPVIEW DELEGATE METHODS

extension PhotoAlbumViewController: MKMapViewDelegate {
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let pin = MKPinAnnotationView()
        pin.pinTintColor = UIColor.redColor()
        return pin
    }
}
