//
//  ViewController.swift
//  MapClustering
//
//  Created by Shóna Nunez on 25/11/2015.
//  Copyright © 2015-2017. All rights reserved.
//

import UIKit
import GoogleMaps

class ViewController: UIViewController
{
    fileprivate var markerArray = [MapMarker]()
    fileprivate let mapUtils = MapUtils()

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let camera = GMSCameraPosition.camera(withLatitude: 53.3478, longitude: -6.2597, zoom: 2)
        let mapView: GMSMapView = GMSMapView.map(withFrame: CGRect.zero, camera: camera)
        mapView.delegate = self;
        
        self.view = mapView
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        markerArray = mapUtils.randomLocations(withCount: 25000)
        
        if let visibleMap = self.view as? GMSMapView {
            mapUtils.generateQuadTreeWithMarkers(markerArray, forVisibleArea: visibleMap)
        }
    }
}

extension ViewController: GMSMapViewDelegate
{
    func mapView(_ mapView: GMSMapView!, idleAt position: GMSCameraPosition!)
    {
        mapUtils.mainQueue.cancelAllOperations()
        mapUtils.backgroundQueue.cancelAllOperations()
        
        if let visibleMap = self.view as? GMSMapView {
            mapUtils.generateQuadTreeWithMarkers(markerArray, forVisibleArea: visibleMap)
        }
    }
    
    func mapView(_ mapView: GMSMapView!, didTap marker: GMSMarker!) -> Bool
    {
        mapView.selectedMarker = marker
        return true
    }
}

