//
//  ClusterManager.swift
//  MapClustering
//
//  Created by Shóna Nunez on 08/12/2015.
//  Copyright © 2015-2017. All rights reserved.
//

import CoreLocation

class ClusterManager: NSObject
{
    //Query the QuadTree in order to create the clusters
    func clusteredAnnotationsWithinMapRect(_ quadTree: QuadTree, zoomLevel: Double, boundaryNE: CLLocationCoordinate2D, boundarySW: CLLocationCoordinate2D, boundingBox: BoundingBox) -> [MapMarker]
    {
        let minLat:Int = Int(floor(boundarySW.latitude))
        let maxLat:Int = Int(ceil(boundaryNE.latitude))
        
        let minLong:Int = Int(floor(boundarySW.longitude))
        let maxLong:Int = Int(ceil(boundaryNE.longitude))
        
        var clusteredMapMarkers = [MapMarker]()
        var coordinateAreaSize: Double = 32768 / (256 * pow(2, zoomLevel)) //32768 = 2^15
        
        if zoomLevel > 10 { //The area becomes too small at this point so increase it
            coordinateAreaSize = 1
        }
        
        var i = Double(minLong)
        while i < Double(maxLong) + coordinateAreaSize {
            
            var j = Double(minLat)
            while j < Double(maxLat) + coordinateAreaSize {
                
                let northEastCoord: CLLocationCoordinate2D = CLLocationCoordinate2DMake(j + coordinateAreaSize, i + coordinateAreaSize)
                let southWestCoord: CLLocationCoordinate2D = CLLocationCoordinate2DMake(j, i)
                
                let areaBox: BoundingBox = quadTree.boundingBoxForCoordinates(northEastCoord, southWestCoord: southWestCoord) //An area within the boundary to cluster
                
                var totalLatitude: Double = 0
                var totalLongitude: Double = 0
                var mapMarkers = [MapMarker]()
                
                let objectArray = quadTree.queryRegion(boundingBox, region: areaBox)
                
                for object in objectArray {
                    
                    totalLatitude += object.markerCoordinate.latitude
                    totalLongitude += object.markerCoordinate.longitude
                    mapMarkers.append(object)
                }
                
                let count = mapMarkers.count
                
                if count == 1 {
                    clusteredMapMarkers += mapMarkers
                }
                
                if count > 1 {
                    let coordinate = CLLocationCoordinate2D(
                        latitude: CLLocationDegrees(totalLatitude)/CLLocationDegrees(count),
                        longitude: CLLocationDegrees(totalLongitude)/CLLocationDegrees(count)
                    )
                    
                    let cluster = Annotation()
                    cluster.markerCoordinate = coordinate
                    cluster.markerClusterTitle = "Marker Count: \(count)"
                    cluster.markerClusterCount = count
                    
                    clusteredMapMarkers.append(cluster)
                }
                
                j = j + coordinateAreaSize
            }
            
            i = i + coordinateAreaSize
        }
        
        return clusteredMapMarkers
    }
}
