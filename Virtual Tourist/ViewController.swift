//
//  ViewController.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/11/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController, MKMapViewDelegate {

    struct Constants {
        static let longPressDuration = 0.5
    }
    
    var activeAnnotion = MKPointAnnotation()
    var pointPressed = CGPoint()
    var coordinate = CLLocationCoordinate2D()
    
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
            let longPress = UILongPressGestureRecognizer(target: self, action: "dropPin:")
            longPress.minimumPressDuration = Constants.longPressDuration
            mapView.addGestureRecognizer(longPress)
        }
    }
    
    func dropPin(gesture: UIGestureRecognizer) {
        
        switch gesture.state {
        case .Began:
            let newAnnotation = MKPointAnnotation()
            activeAnnotion = newAnnotation
            updatePinLocatin(gesture)
            newAnnotation.coordinate = coordinate
            newAnnotation.title = "Test"
            mapView.addAnnotation(newAnnotation)
        case .Changed:
            updatePinLocatin(gesture)
            activeAnnotion.coordinate = coordinate
        case .Ended:
            updatePinLocatin(gesture)
            activeAnnotion.coordinate = coordinate
        default:
            break
        }
    }
    
    func updatePinLocatin(gesture: UIGestureRecognizer) {
        pointPressed = gesture.locationInView(mapView)
        coordinate = mapView.convertPoint(pointPressed, toCoordinateFromView: mapView)
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        
        var annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier("location") as? MKPinAnnotationView
        
        if annotationView == nil {
            annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "location")
            annotationView?.canShowCallout = true
            annotationView?.pinTintColor = MKPinAnnotationView.redPinColor()
            
        } else {
            annotationView?.annotation = annotation
        }
        
        annotationView?.draggable = true
        
        return annotationView
    }
    
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        
        if newState == .Ending {
            print("dropped")
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

