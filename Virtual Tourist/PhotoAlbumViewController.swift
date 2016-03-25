//
//  PhotoAlbumViewController.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/13/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import UIKit

class PhotoAlbumViewController: UIViewController {

    var localityName: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if localityName != nil {
            title = localityName
        } else {
            title = "Photos"
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
