//
//  ViewController.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/11/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController {
    
    //MARK: -------- TYPES --------
    //this type is used to distinguish between two different states of the toolbar and toolbar button that appears when the "edit" button is tapped
    enum ButtonType {
        case Message
        case DeletePin
    }
    
    //MARK: -------- PROPERTIES --------
    var temporaryAnnotation: MKPointAnnotation!
    var activeAnnotation: PinAnnotation!  //used to track the currently (or last) selected annotation
    var lastPinTapped: MKPinAnnotationView?  //used to track the last annotation view that was tapped (used when toggling the color of the pin between red and purple when in edit mode)
    var pointPressed = CGPoint()
    var coordinate = CLLocationCoordinate2D()
    var initiallyLoaded = false //variable which is set to true on initial loading of the user's saved map region, thus preventing unnecessary loading of a user's saved map region each time the user returns from the photo album controller
    var imageFetchExecuting = false
    var userTappedMapNotPin = true
    
    //Set up the longpress gesture recognizer when the map view outlet gets set
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(MapViewController.dropPin(_:)))
            longPress.minimumPressDuration = Constants.MapViewConstants.LongPressDuration
            mapView.addGestureRecognizer(longPress)
        }
    }
    
    let flickrClient = FlickrClient.sharedInstance

    var sharedContext: NSManagedObjectContext {
        return CoreDataStack.sharedInstance.managedObjectContect
    }
    
    //button properties for the toolbar
    var removePinButton: UIBarButtonItem!
    var displayMessage: UIBarButtonItem!
    var spacerButton = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
    
    //MARK: -------- CUSTOM METHODS --------
    
    ///method that gets called when the long press gesture recognizer registers a long press; this function places an annotation view as soon as the long press begins, but immediately moves to the .changed state in which the location gets updated with the finger scroll (allowing the pin to move with the finger).
    func dropPin(gesture: UIGestureRecognizer) {
        
        switch gesture.state {
        case .Began:
            coordinate = mapView.convertPoint(gesture.locationInView(mapView), toCoordinateFromView: mapView)
            temporaryAnnotation = MKPointAnnotation()
            mapView.addAnnotation(temporaryAnnotation)
            temporaryAnnotation.coordinate = coordinate
            
        case .Changed: //need to include .Changed so that the pin will move along with the finger drag
            updatePinLocatin(gesture)
            temporaryAnnotation.coordinate = coordinate

        case .Ended:
            updatePinLocatin(gesture)
            
            let newAnnotation = PinAnnotation(latitude: coordinate.latitude, longitude: coordinate.longitude, title: nil, subtitle: nil, context: sharedContext)
            activeAnnotation = newAnnotation
            activeAnnotation.latitude = coordinate.latitude
            activeAnnotation.longitude = coordinate.longitude
            
            mapView.addAnnotation(activeAnnotation)
            mapView.removeAnnotation(temporaryAnnotation)

            lookUpLocation(activeAnnotation)
            
            do {
                try sharedContext.save()
            } catch { }
            getPhotosAtLocation(activeAnnotation.coordinate)
            
        default:
            break
        }
    }
    
    ///method that was created to reduce redundant code; the convertPoint doesn't actally convert a location (since the convertPoint is occurring on the same view that it is converting to! however, it is still needed because it performs the role of converting the pointPressed, which is a CGpoint, to a CLLocationCoordinate2D, which is the type required in order to add it to the map view.
    func updatePinLocatin(gesture: UIGestureRecognizer) {
        coordinate = mapView.convertPoint(gesture.locationInView(mapView), toCoordinateFromView: mapView)
    }
    
    func getPhotosAtLocation(coordinate: CLLocationCoordinate2D) {
        
        imageFetchExecuting = true
        
        flickrClient.executeGeoBasedFlickrSearch(coordinate.latitude, longitude: coordinate.longitude) {[unowned self] (success, photoArray, error) in
            guard error == nil else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.callAlert("Error", message: error!, alertHandler: nil, presentationCompletionHandler: nil)
                }
                return
            }
            
            guard let photoArray = photoArray else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.callAlert("Error", message: "No photos in the photo array", alertHandler: nil, presentationCompletionHandler: nil)
                }
                return
            }
        
            CoreDataStack.sharedInstance.savePhotosToPin(photoArray, pinToSaveTo: self.activeAnnotation, maxNumberToSave: Constants.MapViewConstants.MaxNumberOfPhotosToSavePerPin)
            self.imageFetchExecuting = false
        }
    }
    
    func callAlert(title: String, message: String, alertHandler: ((UIAlertAction) -> Void)?, presentationCompletionHandler: (() -> Void)?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: alertHandler))
        presentViewController(alertController, animated: true, completion: presentationCompletionHandler)
    }
    
    //this method has been taken from http://stackoverflow.com/questions/33131213/regiondidchange-called-several-times-on-app-load-swift and is used to detect whether the map region was updated as a result of a user interacting with the map (i.e. through the user scrolling zooming); this method is needed for proper loading of the most recent zoom/pan of the map, which gets saved when a user updates it and saved/loaded each time the app is run; this method is used within the "regionDidChangeAnimated" map delegate method, and is only needed for the initial loading of the map, because when the app loads, the map gets initially set and regionDidChangeAnimated method gets called in between viewWillAppear and viewDidAppear (and this initial location is shifted off center from the loaded/saved location), but this initial setting is NOT a result of the user interacting with the map and so we do NOT want to save it as though it was a user-selected location for a save (and potentially immediately overwrite a user's saved location that has yet to even be loaded!); hence, in the regionDidChangeAnimated method, this method is invoked to check to see if the region was changed as a result of the USER moving it, which allows for the distinction between when the app "pre-sets" the map upon loading (which is NOT saved) and a user-generated region update which IS saved to NSUserDefaults
    func mapViewRegionDidChangeFromUserInteraction() -> Bool {
        let view = self.mapView.subviews[0]
        //  Look through gesture recognizers to determine whether this region change is from user interaction
        if let gestureRecognizers = view.gestureRecognizers {
            for recognizer in gestureRecognizers {
                if (recognizer.state == UIGestureRecognizerState.Began || recognizer.state == UIGestureRecognizerState.Ended) {
                    return true
                }
            }
        }
        return false
    }
    
    func loadAllPins() -> [PinAnnotation] {
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        
        do {
            return try sharedContext.executeFetchRequest(fetchRequest) as! [PinAnnotation]
        } catch {
            return [PinAnnotation]()
        }
    }
    
    func removePinFromMap() {
        if let annotationToDelete = activeAnnotation {
            sharedContext.deleteObject(annotationToDelete)
            do {
                try sharedContext.save()
                mapView.removeAnnotation(annotationToDelete)
            } catch {
                callAlert("Error", message: "There was an error removing the pin.", alertHandler: nil, presentationCompletionHandler: nil)
            }
        }
        setupToolbar(.Message)
    }
    
    func setupToolbar(buttonToShow: ButtonType) {
        switch buttonToShow {
        case .Message:
            setToolbarItems([spacerButton, displayMessage, spacerButton], animated: false)
            navigationController?.toolbar.barTintColor = nil
        case .DeletePin:
            setToolbarItems([spacerButton, removePinButton, spacerButton], animated: false)
            navigationController?.toolbar.barTintColor = UIColor(red: 255/255, green: 168/255, blue: 168/255, alpha: 1)
        }
    }
    
    ///method that determines a string-based location for the user's pin using reverse geocoding
    func lookUpLocation(annotation: MKAnnotation) {  //i put the argument here as MKAnnotation rather than MKPointAnnotation just to keep the function more resusable! it just as easily have been MKPointAnnoation, in which case the downcast that happens in the completion closure below would not have been necessary
        let geocoder = CLGeocoder()
        
        let location = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { [unowned self] (placemarksArray, error) in
            if let placemarks = placemarksArray {
                dispatch_async(dispatch_get_main_queue(), {
                    self.activeAnnotation.title = placemarks[0].locality
                    do {
                        try self.sharedContext.save()
                    } catch { }
                })
            }
        }
    }
    
    //MARK: -------- VIEW CONTROLLER METHODS --------
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == Constants.MapViewConstants.ShowPhotoAlbumSegue {
            if let destinationViewController = segue.destinationViewController as? PhotoAlbumViewController {
                
                destinationViewController.annotationToShow = activeAnnotation

                if imageFetchExecuting {
                    destinationViewController.isStillLoadingText = "Retrieving Images..."
                }
            }
        }
    }
    
    override func setEditing(editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: true)
        
        setupToolbar(.Message)

        if editing {
            navigationController?.setToolbarHidden(false, animated: true)
        } else {
            navigationController?.setToolbarHidden(true, animated: true)
            lastPinTapped?.pinTintColor = MKPinAnnotationView.redPinColor()
            mapView.deselectAnnotation(activeAnnotation, animated: false)  //in case a user turned off edit mode while a pin was still in "ready for delete" (i.e. purple) status, this allows the user to them immediately tap the same pin again and enable the segue (otherwise, that pin is still "selected" and so the didSelectAnnotationView won't re-fire, having fired the first time when editing = true)
        }
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if touches.first?.view as? MKPinAnnotationView == nil {
            userTappedMapNotPin = true
        } else {
            userTappedMapNotPin = false
        }
    }
    
    //MARK: -------- VIEW CONTROLLER LIFECYCLE --------
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Virtual Tourist"
        navigationItem.rightBarButtonItem = editButtonItem()
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .Plain, target: nil, action: nil)  //enables a custom back button so that "Back" is shown instead of "Virtual Tourist" (could have done this in the storyboard also by adjusting the navigation item's back button value)
        
        displayMessage = UIBarButtonItem(title: "Select a pin to delete", style: .Plain, target: self, action: nil)
        removePinButton = UIBarButtonItem(barButtonSystemItem: .Trash, target: self, action: #selector(MapViewController.removePinFromMap))
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        lastPinTapped = nil
    }
    
    //the loading of a user's saved map zoom/pan/location setting is performed in viewDIDappear rather than viewWILLappear because the map gets initially set to an app-determined location and regionDidChangeAnimated method gets called in BETWEEN viewWillAppear and viewDidAppear (and this initial location is NOT related to the loaded/saved location), so the code to load a user's saved preferences is delayed until now so that the saved location is loaded AFTER the app pre-sets the map, rather then before (and thus being overwritten, or "shifted" to a different location); it is ensured that the initial auotmatica "pre-set" region of the map is not saved as a user-based save (thus overwriting a user's save) via the mapViewRegionDidChangeFromUserInteraction method, which checks to make sure that when regionDidChangeAnimated is invoked, it is in response to user-generated input
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if !initiallyLoaded {
            if let savedRegion = NSUserDefaults.standardUserDefaults().objectForKey("savedMapRegion") as? [String: Double] {
                let center = CLLocationCoordinate2D(latitude: savedRegion["mapRegionCenterLat"]!, longitude: savedRegion["mapRegionCenterLon"]!)
                let span = MKCoordinateSpan(latitudeDelta: savedRegion["mapRegionSpanLatDelta"]!, longitudeDelta: savedRegion["mapRegionSpanLonDelta"]!)
                mapView.region = MKCoordinateRegion(center: center, span: span)
            }
            
            let annotationsToLoad = loadAllPins()
            mapView.addAnnotations(annotationsToLoad)
            
            initiallyLoaded = true
        }
    }
}

//MARK: -------- MAPVIEW DELEGATE METHODS --------

extension MapViewController: MKMapViewDelegate {
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        var annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier("location") as? MKPinAnnotationView
        if annotationView == nil {
            annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "location")
         //   annotationView?.canShowCallout = true
            annotationView?.pinTintColor = MKPinAnnotationView.redPinColor()
        } else {
            annotationView?.annotation = annotation
        }
        
        annotationView?.draggable = true
        return annotationView
    }

    func mapView(mapView: MKMapView, didDeselectAnnotationView view: MKAnnotationView) {
        (view as! MKPinAnnotationView).pinTintColor = MKPinAnnotationView.redPinColor()
        
        if userTappedMapNotPin {
            setupToolbar(.Message)
        }
    }
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        
        guard view.annotation as? PinAnnotation != nil else {
            return
        }
        
        lastPinTapped = view as? MKPinAnnotationView
        activeAnnotation = view.annotation as? PinAnnotation
        
        if editing {
            setupToolbar(.DeletePin)
            (view as! MKPinAnnotationView).pinTintColor = MKPinAnnotationView.purplePinColor()
        } else {
        
            performSegueWithIdentifier(Constants.MapViewConstants.ShowPhotoAlbumSegue, sender: view)
            
            //the following sets the annotation back to "not selected" so it is possible to re-tap on it again after returning from the photo album view; this is necessary because when an annotation is first tapped, it's registered as "selected" and stays that way, so when trying to tap on it again after returning from the photo album view, it doesn't call the "didSelectAnnotationView" delegate method because technically it is already selected!  thank you stackoverflow for this insight and resolution: http://stackoverflow.com/questions/26620672/mapview-didselectannotationview-not-functioning-properly
            mapView.deselectAnnotation(view.annotation, animated: true)
        }
        
        
    }
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
        if mapViewRegionDidChangeFromUserInteraction() {
            let regionToSave = [
                "mapRegionCenterLat": mapView.region.center.latitude,
                "mapRegionCenterLon": mapView.region.center.longitude,
                "mapRegionSpanLatDelta": mapView.region.span.latitudeDelta,
                "mapRegionSpanLonDelta": mapView.region.span.longitudeDelta
            ]
            NSUserDefaults.standardUserDefaults().setObject(regionToSave, forKey: "savedMapRegion")
        }
    }
}
