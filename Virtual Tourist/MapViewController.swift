//
//  ViewController.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/11/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: UIViewController {

    //MARK: Constants
    struct Constants {
        static let LongPressDuration = 0.5
        static let ShowPhotoAlbumSegue = "ShowPhotoAlbum"
    }
    
    //MARK: Properties
    var activeAnnotion = MKPointAnnotation()
    var pointPressed = CGPoint()
    var coordinate = CLLocationCoordinate2D()
    var savedRegionLoaded = false //variable which is set to true on initial loading of the user's saved map region, thus preventing unnecessary loading of a user's saved map region each time the user returns from the photo album controller
    
    //Set up the longpress gesture recognizer when the map view outlet gets set
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(MapViewController.dropPin(_:)))
            longPress.minimumPressDuration = Constants.LongPressDuration
            mapView.addGestureRecognizer(longPress)
        }
    }
    
    //MARK: Custom Methods
    
    ///method that gets called when the long press gesture recognizer registers a long press; this function places an annotation view as soon as the long press begins, but immediately moves to the .changed state in which the location gets updated with the finger scroll (allowing the pin to move with the finger).
    func dropPin(gesture: UIGestureRecognizer) {
        
        switch gesture.state {
        case .Began:
            let newAnnotation = MKPointAnnotation()
            activeAnnotion = newAnnotation
            updatePinLocatin(gesture)
            newAnnotation.coordinate = coordinate
            newAnnotation.title = nil
            mapView.addAnnotation(newAnnotation)
        case .Changed: //need to include .Changed so that the pin will move along with the finger drag
            updatePinLocatin(gesture)
            activeAnnotion.coordinate = coordinate
            print("moved to \(activeAnnotion.coordinate)")
        case .Ended:
            updatePinLocatin(gesture)
            activeAnnotion.coordinate = coordinate
            lookUpLocation(activeAnnotion)
        default:
            break
        }
    }
    
    ///method that was created to reduce redundant code; the convertPoint doesn't actally convert a location (since the convertPoint is occurring on the same view that it is converting to! however, it is still needed because it performs the role of converting the pointPressed, which is a CGpoint, to a CLLocationCoordinate2D, which is the type required in order to add it to the map view.
    func updatePinLocatin(gesture: UIGestureRecognizer) {
        pointPressed = gesture.locationInView(mapView)
        coordinate = mapView.convertPoint(pointPressed, toCoordinateFromView: mapView)
    }
    
    ///method that determines a string-based location for the user's pin using reverse geocoding
    func lookUpLocation(annotation: MKAnnotation) {  //i put the argument here as MKAnnotation rather than MKPointAnnotation just to keep the function more resusable! it just as easily have been MKPointAnnoation, in which case the downcast that happens in the completion closure below would not have been necessary
        let geocoder = CLGeocoder()
        
        let location = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { (placemarksArray, error) in
            if let error = error {
            //TODO: Add a display alert method and print error to display alert
                print(error.localizedDescription)
            } else if let placemarks = placemarksArray {
                let place = placemarks[0].locality
                if let pointAnnotation = annotation as? MKPointAnnotation {  //note that is necessary to first downcast the annotation as an MKPointAnnotation since the title property would otherwise not be settable
                    dispatch_async(dispatch_get_main_queue()) {
                        pointAnnotation.title = place
                    }
                }
            }
        }
    }
    
    //this method has been taken from http://stackoverflow.com/questions/33131213/regiondidchange-called-several-times-on-app-load-swift and is used to detect whether the map region was updated as a result of a user interacting with the map (i.e. through the user scrolling zooming); this method is needed for proper loading of the most recent zoom/pan of the map, which gets saved when a user updates it and saved/loaded each time the app is run; this method is used within the "regionDidChangeAnimated" map delegate method, and is only needed for the initial loading of the map, because when the app loads, the map gets initially set and regionDidChangeAnimated method gets called in between viewWillAppear and viewDidAppear (and this initial location is shifted off center from the loaded/saved location), but this initial setting is NOT a result of the user interacting with the map and so we do NOT want to save it as though it was a user-selected location for a save (and potentially immediately overwrite a user's saved location that has yet to even be loaded!); hence, in the regionDidChangeAnimated method, this method is invoked to check to see if the region was changed as a result of the USER moving it, which allows for the distinction between when the app "pre-sets" the map upon loading (which is NOT saved) and a user-generated region update which IS saved to NSUserDefaults
    func mapViewRegionDidChangeFromUserInteraction() -> Bool {
        let view = self.mapView.subviews[0]
        //  Look through gesture recognizers to determine whether this region change is from user interaction
        if let gestureRecognizers = view.gestureRecognizers {
            for recognizer in gestureRecognizers {
                if (recognizer.state == UIGestureRecognizerState.Began || recognizer.state == UIGestureRecognizerState.Ended) {
                    print("user interaction")
                    return true
                }
            }
        }
        return false
    }
    
    func removePinFromMap() {
        print("EDIT MODE")
    }
    
    //MARK: View Controller Methods
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == Constants.ShowPhotoAlbumSegue {
            if let destinationViewController = segue.destinationViewController as? PhotoAlbumViewController {
                if let senderTitle = (sender as? MKAnnotationView)?.annotation?.title {
                    destinationViewController.localityName = senderTitle
                }
            }
        }
    }
    
    //MARK: View Controller Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        print("viewDidLoad")
        
        title = "Virtual Tourist"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Edit, target: self, action: #selector(MapViewController.removePinFromMap))
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .Plain, target: nil, action: nil)  //enables a custom back button so that "Back" is shown instead of "Virtual Tourist" (could have done this in the storyboard also by adjusting the navigation item's back button value)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        print("viewWillAppear")
    }
    
    //the loading of a user's saved map zoom/pan/location setting is performed in viewDIDappear rather than viewWILLappear because the map gets initially set to an app-determined location and regionDidChangeAnimated method gets called in BETWEEN viewWillAppear and viewDidAppear (and this initial location is NOT related to the loaded/saved location), so the code to load a user's saved preferences is delayed until now so that the saved location is loaded AFTER the app pre-sets the map, rather then before (and thus being overwritten, or "shifted" to a different location); it is ensured that the initial auotmatica "pre-set" region of the map is not saved as a user-based save (thus overwriting a user's save) via the mapViewRegionDidChangeFromUserInteraction method, which checks to make sure that when regionDidChangeAnimated is invoked, it is in response to user-generated input
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        print("viewDidAppear")
        
        if !savedRegionLoaded {
            if let savedRegion = NSUserDefaults.standardUserDefaults().objectForKey("savedMapRegion") as? [String: Double] {
                let center = CLLocationCoordinate2D(latitude: savedRegion["mapRegionCenterLat"]!, longitude: savedRegion["mapRegionCenterLon"]!)
                let span = MKCoordinateSpan(latitudeDelta: savedRegion["mapRegionSpanLatDelta"]!, longitudeDelta: savedRegion["mapRegionSpanLonDelta"]!)
                print("loaded: \(center)")
                mapView.region = MKCoordinateRegion(center: center, span: span)
            }
            savedRegionLoaded = true
        }
    }
}

//MAPVIEW DELEGATE METHODS

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

    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        performSegueWithIdentifier(Constants.ShowPhotoAlbumSegue, sender: view)
        
        //the following sets the annotation back to "not selected" so it is possible to re-tap on it again after returning from the photo album view; this is necessary because when an annotation is first tapped, it's registered as "selected" and stays that way, so when trying to tap on it again after returning from the photo album view, it doesn't call the "didSelectAnnotationView" delegate method because technically it is already selected!  thank you stackoverflow for this insight and resolution: http://stackoverflow.com/questions/26620672/mapview-didselectannotationview-not-functioning-properly
        mapView.deselectAnnotation(view.annotation, animated: true)
    }
    
    //TODO:  enable dragging; CODE BELOW NEVER RUNS BECAUSE A "GRAB" on the pin registers the didSelectAnnotationView rather than as a grab
//    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
//        print("did change state")
//        if newState == .Ending {
//            print("grabbed and moved to \(view.annotation?.coordinate)")
//        }
//    }
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        print("region did change to \(mapView.region.center)")
        
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
