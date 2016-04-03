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
    //used to track the pin on the map when the user drags it
    var temporaryAnnotation: MKPointAnnotation!
    
    //used to track the currently (or last) selected annotation
    var activeAnnotation: PinAnnotation!
    
    //used to track the last annotation view that was tapped (used when toggling the color of the pin between red and purple when in edit mode)
    var lastPinTapped: MKPinAnnotationView?
    
    //used to track the current coordinate of the pin on the map, particularly useful for tracking a dragged pin (see the dropPin method)
    var coordinate = CLLocationCoordinate2D()
    
    //variable which is set to true on initial loading of the user's saved map region, thus preventing unnecessary loading of a user's saved map region each time the user returns from the photo album controller (see viewDidAppear)
    var initiallyLoaded = false
    
    //used for the purpose of tracking the completion of the flickr request; depending on if this is true or false when the pin is tapped determines what message the user iniitally sees in the photo album (if any)
    var imageFetchExecuting = false
    
    //used within touchesBegan to ensure that the "delete" button stays presented in edit mode when a user taps between pins before deleting any, and goes back to the "select a pin to delete" when the user taps off a pin in edit mode
    var userTappedMapNotPin = true
    
    //set the map view's delegate and add and set up a longpress gesture recognizer to the map view when the outlet gets set
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(MapViewController.dropPin(_:)))
            longPress.minimumPressDuration = Constants.MapViewConstants.LongPressDuration
            mapView.addGestureRecognizer(longPress)
        }
    }
    
    //getting a reference to the singleton client object
    let flickrClient = FlickrClient.sharedInstance

    //getting a reference to the singleton core data context
    var sharedContext: NSManagedObjectContext {
        return CoreDataStack.sharedInstance.managedObjectContect
    }
    
    //button properties for the toolbar; these are configured in viewDidLoad and arranged in the setupToolBar method
    var removePinButton: UIBarButtonItem!
    var displayMessage: UIBarButtonItem!
    var spacerButton = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
    
    //MARK: -------- CUSTOM METHODS --------
    ///this method gets called when the long press gesture recognizer registers a long press; this function places a temporary annotation view as soon as the long press begins, but immediately moves to the .changed state in which the location gets updated with the finger scroll and allows the pin to move with the finger; in .Ended, a new PinAnnotation is created using the final location of the temporary annoation, the temporary annotation is removed from the map and the new PinAnnoation is added to the map (this was necessary because tapping on a pin that was associated with an MKPointAnnoation and NOT a PinAnnotation creates problems because that pin's annoation property would not point to the desired PinAnnotation, as needed for the didSelectAnnotationView and prepareForSegue to be passed into the next view controller; i originally had this set up so that a PinAnnotation object was set up in the .Began and the latitutde/longitude of that object was updated throughout the drag (see earlier commits for what this looked like), which i thought would work because after all PinAnnotation was designed to be MKAnnotation-conforming (and i set the draggable property to true on viewForAnnoation); however, for some reason that i couldn't quite figure out, the pin would not move along with the drag when associated with a PinAnnotation, and i suspect it had something to with how the PinAnnotation made known its updated location to the mapView.  an MKPointAnnotation, on the other hand, DOES exhibit this able-to-be-dragged effect by default without any issue at all, and so that is why i used that class as the class for the temporary annotation.  this is something i still want to research because i believe there is a cleaner way to do this that enables a PinAnnotion to undergo the same dragging effect as an MKPointAnnotation (it think it may have something to do with getters, setters, the setCoordinate method on the MKAnnotation protocol, and/or the draggable property on the MKAnnotationView); but alas, i feel that the solution i came up with is good enough! (since there is no noticable difference)
    func dropPin(gesture: UIGestureRecognizer) {
        
        switch gesture.state {
        case .Began:
            updatePinLocation(gesture)
            temporaryAnnotation = MKPointAnnotation()
            mapView.addAnnotation(temporaryAnnotation)
            temporaryAnnotation.coordinate = coordinate
            
        //need to include .Changed so that the pin will move along with the finger drag
        case .Changed:
            updatePinLocation(gesture)
            temporaryAnnotation.coordinate = coordinate

        case .Ended:
            updatePinLocation(gesture)
            let newAnnotation = PinAnnotation(latitude: coordinate.latitude, longitude: coordinate.longitude, title: nil, subtitle: nil, context: sharedContext)
            
            //the globablly tracked activeAnnotation is set to the new PinAnnotation because activeAnnotation is used in other methods
            activeAnnotation = newAnnotation
            activeAnnotation.latitude = coordinate.latitude
            activeAnnotation.longitude = coordinate.longitude
            
            //the two lines below are where the temporary MKPointAnnotation (and associated pin) is being "swapped out" for the new PinAnnnotation (and its associated pin); this was necessary so that the pin the user ultimately taps to bring up the photo album has a .annotation property that references a PinAnnottion object (rather than an MKPointAnnotation object, which cannot be downcast to a PinAnnotation object); note that the temporary annotation is removed AFTER the active annotation because if it is done in the other order, there is a noticable "blip" between when one annoation get removed and the new one was placed; doing it in the order below prevents the blip and makes it a seamless swap (this may make it technically possible for the user to tap the temporary annotation pin BEFORE the system removes it, but i was unable to make this happen in testing; regardless, i wanted to be safe and ensure that even if a user tapped so quickly that the system didnt have time to process the removal, that there wouldn't be an issue down the road, so i added a guard statement to the didSelectAnnotationView method that checks to make sure that the incoming pin has an annotation attached to it that is a PinAnnotation and not an MKPointAnnotation
            mapView.addAnnotation(activeAnnotation)
            mapView.removeAnnotation(temporaryAnnotation)

            //get the geotagged location information for the activeAnnotation, which will update the pin's "title" property and be used as the segued-to photo album's navigation bar's title
            lookUpLocation(activeAnnotation)
            
            do {
                //save the new pin to the persistent store; note at this point that it is possible that the pin is being saved without the title on the pin having been set (since lookUpLocation occurs asycnhronously)
                try sharedContext.save()
            } catch { }
            
            //call to the method to begin the execution of a flickr request to search for images at a given coordinate
            getPhotosAtLocation(activeAnnotation.coordinate)
            
        default:
            break
        }
    }
    
    ///this method converts the location (CGPoint) of the gesture's location to a geographical coordinate that can be used and displayed on the map via the mapView's convertPoint method
    func updatePinLocation(gesture: UIGestureRecognizer) {
        
        //since the convertPoint is occurring on the same mapView as the destination mapView, the only conversion that is happening is a conversion of the point from a gesture-based CGPoint (where the user released the pin) to the geographical CLLocationCoordinate2D type that is required in order to add the location to a mapView
        coordinate = mapView.convertPoint(gesture.locationInView(mapView), toCoordinateFromView: mapView)
        
        //offsets the pin vertically by a small amount so the user can see with a finger placed on the screen where the tip of the pin is going to be located
        coordinate.latitude += Constants.MapViewConstants.PinDropLatitudeOffset
    }
    
    ///method that takes a coordinate and executes the flickr search for images and if no error is returned, passes the returned array of photo data (but not yet the image files themselves) to the core data stack for processing and creating new Photo objects (which are attached via the core data's inverse relationship to the specified "pinToSaveTo" PinAnnotation)
    func getPhotosAtLocation(coordinate: CLLocationCoordinate2D) {
        
        //used to track when the flickr request completes, utilized in prepareForSegue
        imageFetchExecuting = true
        
        flickrClient.executeGeoBasedFlickrSearch(coordinate.latitude, longitude: coordinate.longitude) {[unowned self] (success, photoArray, error) in
            
            //dispatch to main queue now since all possible avenues for what happens next involve either the UI or core data updates (which occur within the savePhotosToPin method)
            dispatch_async(dispatch_get_main_queue()) {
                guard error == nil else {
                    self.callAlert("Error", message: error!, alertHandler: nil, presentationCompletionHandler: nil)
                    return
                }
                
                guard let photoArray = photoArray else {
                    self.callAlert("Error", message: "No photos in the photo array", alertHandler: nil, presentationCompletionHandler: nil)
                    return
                }
                
                //sends the photo array to be processed and turned into Photo objects that are associated with the activeAnnotation; the max number to store is also sent here (currently 36)
                CoreDataStack.sharedInstance.savePhotosToPin(photoArray, pinToSaveTo: self.activeAnnotation, maxNumberToSave: Constants.MapViewConstants.MaxNumberOfPhotosToSavePerPin)
                
                //updates the tracking variable to indicate that the request has been completed
                self.imageFetchExecuting = false
            }
        }
    }
    
    ///this method has been taken from http://stackoverflow.com/questions/33131213/regiondidchange-called-several-times-on-app-load-swift and is used to detect whether the map region was updated as a result of a user interacting with the map (i.e. through the user scrolling zooming); this method is needed for proper loading of the most recent zoom/pan of the map, which gets saved when a user updates it and saved/loaded each time the app is run; this method is used within the "regionDidChangeAnimated" map delegate method, and is only needed for the initial loading of the map, because when the app loads, the map gets initially set and regionDidChangeAnimated method gets called in between viewWillAppear and viewDidAppear (and this initial location is shifted off center from the loaded/saved location), but this initial setting is NOT a result of the user interacting with the map and so we do NOT want to save it as though it was a user-selected location for a save (and potentially immediately overwrite a user's saved location that has yet to even be loaded!); hence, in the regionDidChangeAnimated method, this method is invoked to check to see if the region was changed as a result of the USER moving it, which allows for the distinction between when the app "pre-sets" the map upon loading (which is NOT saved) and a user-generated region update which IS saved to NSUserDefaults
    func mapViewRegionDidChangeFromUserInteraction() -> Bool {
        let view = self.mapView.subviews[0]
        
        //looks through gesture recognizers to determine whether this region change is from user interaction
        if let gestureRecognizers = view.gestureRecognizers {
            for recognizer in gestureRecognizers {
                if (recognizer.state == UIGestureRecognizerState.Began || recognizer.state == UIGestureRecognizerState.Ended) {
                    return true
                }
            }
        }
        return false
    }
    
    ///this method loads all the Pins from the persistent store and returns an array of all currently saved "Pin" objects; this method is called exclusively on the first invocation of viewDidAppear (see comment near viewDidAppear for why it doesn't occur in viewWillAppear instead)
    func loadAllPins() -> [PinAnnotation] {
        
        //create a database search request on the "Pin" column; since there are no sorts or predicates added to this fetch request, all Pins are returned (which is what we want)
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        
        do {
            //perform the fetch, which returns [AnyObject], then downcast it as [PinAnnotation] (since we know that is the NSManaged class associated with the Pin entity in the core data model)
            return try sharedContext.executeFetchRequest(fetchRequest) as! [PinAnnotation]
        } catch {
            //if there is a problem for some reason, return an empty array (i.e. no pins will appear on map)
            return [PinAnnotation]()
        }
    }
    
    ///method that deletes the PinAnnotion associated with the selected pin from the persistent store (which will also delete all Photo objects associated with that PinAnnotation via the one-to-many cascade delete rule in the core data model), and then deletes the annotation (and thus pin) from the map; this method is invoked when the user taps the Delete button after selecting a pin while in Edit mode
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
        //once a pin is removed, switch the toolbar from "DeletePin" mode to "Message" mode, inviting user to choose another pin to delete (since still in Edit mode)
        setupToolbar(.Message)
    }
    
    ///method that sets up the toolbar to show the appropriate button at the appropriate time; the color of the toolbar is also updated for a given state: light red for delete mode, and default gray color (i.e. barTintColor = nil) when in select-a-pin-to-delete mode; this method is called at various points throughout the Edit mode cycle, including when the "Edit" button is tapped, when a pin is selected/deselected, and when a pin is removed
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
    
    ///method that determines a string-based location for the user's pin using reverse geocoding; the location that gets returned is the "locality" of the placemark, which corresponds to the city (i chose the city since i felt that it made the most sense for this project); note that the argument to this method utilizes the MKAnnotation protocol as a type (as opposed to limiting the argument type to the specific PinAnnotion class) just to keep the method more generic and potentially resusable - even though i didn't end up using it for any other type, i think this is good practice in general; as such, i acknowledge that the argument could just as easily have been more specifically PinAnnotation (since that is the only class that ever gets passed in this project), in which case the downcast that happens in the completion closure below would not have been necessary
    func lookUpLocation(annotation: MKAnnotation) {
        let geocoder = CLGeocoder()
        
        let location = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { [unowned self] (placemarksArray, error) in
            if let placemarks = placemarksArray {
                
                //checks to see if the locality (city) of the placemark is not nil, and if so, sets the title of the activeAnnotation to that locality and updates the PinAnnotation object in the persistent store; note that this is done on the main queue, since updates to core data should be done on the main queue
                dispatch_async(dispatch_get_main_queue(), {
                    if let locality = placemarks[0].locality {
                        self.activeAnnotation.title = locality
                        do {
                            try self.sharedContext.save()
                        } catch { }
                    }
                })
            }
        }
    }
    
    ///method that displays an alert (i have reused this method across various projects!); it takes optional completion handlers for when the button is tapped and also when the display is presented (which in this project are both always nil; i have kept them in simply because it keeps this function generic and reusable, and copyable/pastable from project to project)
    func callAlert(title: String, message: String, alertHandler: ((UIAlertAction) -> Void)?, presentationCompletionHandler: (() -> Void)?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: alertHandler))
        presentViewController(alertController, animated: true, completion: presentationCompletionHandler)
    }
    
    //MARK: -------- VIEW CONTROLLER METHODS --------
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == Constants.MapViewConstants.ShowPhotoAlbumSegue {
            if let destinationViewController = segue.destinationViewController as? PhotoAlbumViewController {
                
                //sets the annotation property on the photo album view controller to the active annotation (i.e. the pin that was just tapped in didSelectAnnotationView)
                destinationViewController.annotationToShow = activeAnnotation

                //if the flickr request is still in the process of retrieving data, then update the text that the user first sees in the photo album view to reflect that
                if imageFetchExecuting {
                    destinationViewController.isStillLoadingText = "Retrieving Images..."
                }
            }
        }
    }
    
    //method that gets called when "Edit" button is tapped (note that the Edit button, created in viewDidLoad, is the result of editButtonItem(), which creates a button that is automatically linked to the editing property of the view; we override the setEditing property since we want to customize what happens when edit mode is entered (particularly since we don't have a table view or other view that typically lends itself naturally to editing)
    override func setEditing(editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: true)
        
        setupToolbar(.Message)
        
        //update the visibility of the toolbar depending on if user is in editing mode or not
        if editing {
            navigationController?.setToolbarHidden(false, animated: true)
        } else {
            navigationController?.setToolbarHidden(true, animated: true)
            
            //when leaving editing mode, if a pin is currently selected but user decides not to delete if (i.e. it is still purple when editing is turned off), this ensures that the pin is turned back to red rather than staying purple
            lastPinTapped?.pinTintColor = MKPinAnnotationView.redPinColor()
            
            //when leaving editing mode, if a pin was currently selected (i.e. purple), this allows the user to them immediately tap the same pin again and enable the segue (otherwise, that pin is still technically marked as "selected" and so the didSelectAnnotationView won't re-fire, having just fired the first time when the user tapped it to select it when in editing mode!); it definitely took me a while to figure this out, as i was initially stumped as to why the pin seemed to become "dead" to tapping when leaving edit mode
            mapView.deselectAnnotation(activeAnnotation, animated: false)
        }
    }
    
    //method that gets called when user taps the screen and checks to see if the UIView associated with the location of the tap is an MKPinAnnotationView or not (i.e. did the user tap a pin or the map?), then updates the "userTappedMapNotPin" tracking variable accordingly; the tracking variable comes into play exclusively when the user is in "Edit" mode, in which case, this tracking variable allows the user to tap successively from pin to pin (i.e. not deleting one before tapping the next) without the toolbar state flip flopping back and forth; this was necessary to implement (and tricky to figure out) because the mapView's didDeselectAnnotationView method is always called BEFORE the didSelectAnnotationView method when a user moves from pin to pin, and the sequential setupToolbar calls with different states results in a quick "blip" for the split second that exists between one pin registering as deselected and the next pin registering as selected; the tracking variable serves as a check specifically within the didDeselectAnnotationView to smooth this out, preventing the blip from occurring by ONLY switching back to the .Message toolbar state if a user taps the map (i.e. userTappedMapNotPin = true); if the user taps another pin, on the other hadn (userTappedMapNotPin = false), then the current .DeletePin toolbar state stays that way
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
        
        //create a Edit/Done toggling button using the view controller class function, editButtonItem(), which will enable the user to enter editing mode in order to delete pins from the map (and their associated images)
        navigationItem.rightBarButtonItem = editButtonItem()
        
        //enables a custom back button so that "Back" is shown instead of "Virtual Tourist" (could alternatively have done this in the storyboard also by adjusting the navigation item's back button value)
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .Plain, target: nil, action: nil)
        
        displayMessage = UIBarButtonItem(title: "Select a pin to delete", style: .Plain, target: self, action: nil)
        removePinButton = UIBarButtonItem(barButtonSystemItem: .Trash, target: self, action: #selector(MapViewController.removePinFromMap))
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        //reset this property so that when the user goes back to the map from the photo album, there isn't a pin saved
        lastPinTapped = nil
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        //the block of code below only runs once: when initially launching the app (because initiallyLoaded is set to true below, this won't run when a user returns back to this view controller from the photo album view
        if !initiallyLoaded {
            
            //loads a user's saved map zoom/pan/location setting from NSUserDefaults; this is performed in viewDIDappear rather than viewWILLappear because the map gets initially set to an app-determined location and regionDidChangeAnimated method gets called in BETWEEN viewWillAppear and viewDidAppear (and this initial location is NOT related to the loaded/saved location), so the code to load a user's saved preferences is delayed until now so that the saved location is loaded AFTER the app pre-sets the map, rather then before (and thus being overwritten, or "shifted" to a different location); it is ensured that the initial auotmatica "pre-set" region of the map is not saved as a user-based save (thus overwriting a user's save) via the mapViewRegionDidChangeFromUserInteraction method, which checks to make sure that when regionDidChangeAnimated is invoked, it is in response to user-generated input
            if let savedRegion = NSUserDefaults.standardUserDefaults().objectForKey("savedMapRegion") as? [String: Double] {
                let center = CLLocationCoordinate2D(latitude: savedRegion["mapRegionCenterLat"]!, longitude: savedRegion["mapRegionCenterLon"]!)
                let span = MKCoordinateSpan(latitudeDelta: savedRegion["mapRegionSpanLatDelta"]!, longitudeDelta: savedRegion["mapRegionSpanLonDelta"]!)
                mapView.region = MKCoordinateRegion(center: center, span: span)
            }
            
            //load all pins from the persistent store and add them to the map
            let annotationsToLoad = loadAllPins()
            mapView.addAnnotations(annotationsToLoad)
            
            //prevents this block of code from running again during the session
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
            
            //although it isn't necessary to explicitly set this property to false (it is false by default), this was kept here to emphasize that we do NOT want callouts enabled, even if the PinAnnotation does have a title string associated with it
            annotationView?.canShowCallout = false
            
            annotationView?.pinTintColor = MKPinAnnotationView.redPinColor()
        } else {
            annotationView?.annotation = annotation
        }
        /* --- line below UNUSED (i want to retain this line as a comment for personal future review)
        annotationView?.draggable = true
         --- */
        return annotationView
    }

    //this method gets called when a user taps off a pin (i.e. taps another pin, or taps somewhere else)
    func mapView(mapView: MKMapView, didDeselectAnnotationView view: MKAnnotationView) {
        (view as! MKPinAnnotationView).pinTintColor = MKPinAnnotationView.redPinColor()
        
        //checks the value of the userTappedMapNotPin tracking variable to see if the tap the user just made that caused the current pin to be deselected was either targeting another pin OR someplace else, e.g. the map (see the touchesBegan method for info on how this tracking variable gets set); if the user tapped some place other than another pin (userTappedMapNotPin = true), then the toolbar gets updated to reflect the "Select a pin to delete" state; otherwise, the user tapped another pin and the .DeletePin state shouldn't change (this eliminates the otherwise potential "blip" mentioned in the touchesBegan comment)
        if userTappedMapNotPin {
            setupToolbar(.Message)
        }
    }
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        
        //checks to ensure that the pin that was tapped is associated with a PinAnnotion (not an MKPointAnnotation); as described in the dropPin method comment, in the unlikely chance that a user is able to tap the pin associated with the temporary MKPointAnnotation before the system removes it from the map, we want to protect against a crash, which this guard statement does; as a note, instead of using isKindOfClass for this guard, it would have been possible to alternatively have tested for downcastability of the annotation, e.g. let _ = annotation as? PinAnnotation
        guard let annotation = view.annotation where annotation.isKindOfClass(PinAnnotation) else {
            return
        }
        
        //updates tracking variables with the current pin and PinAnnotation, to be used for ensuring the correct pin color and that the correct PinAnnotation gets sent to the photo album
        lastPinTapped = view as? MKPinAnnotationView
        activeAnnotation = annotation as? PinAnnotation
        
        //if the user is in editing mode when a pin it tapped, then update the toolbar (which has already been presented when the user enters edit mode) to show the DeletePin state (i.e. the Trash icon and red background), and also update the color of the tapped pin to purple, indicating "ready for delete"; if the user is NOT in edit mode, then when a pin is tapped, invoke the performSegue method to open up the photo album to display the saved photos associated with the PinAnnotation for that pin (or download them if being tapped for the first time)
        if editing {
            setupToolbar(.DeletePin)
            (view as! MKPinAnnotationView).pinTintColor = MKPinAnnotationView.purplePinColor()
        } else {
        
            performSegueWithIdentifier(Constants.MapViewConstants.ShowPhotoAlbumSegue, sender: view)
            
            //the following sets the annotation back to "not selected" so it is possible to re-tap on it again after returning from the photo album view; this is necessary because when an annotation is first tapped, it's registered as "selected" and stays that way, so when trying to tap on it again after returning from the photo album view, it doesn't call the "didSelectAnnotationView" delegate method because technically it is already selected!  thank you stackoverflow for this insight and resolution: http://stackoverflow.com/questions/26620672/mapview-didselectannotationview-not-functioning-properly
            mapView.deselectAnnotation(view.annotation, animated: true)
        }
    }
    
    //method that gets called when the user changes the zoom or scroll of the map
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
        //checks to ensure that the region update was a result of user interaction, and if so, save the current settings to NSUserDefaults for loading on the next time the app is started (see the comment for the mapViewRegionDidChangeFromUserInteraction method for more info on why it is necessary to check for user interaction)
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
