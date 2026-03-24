//
//  SearchXMLParser.swift
//  iSub
//
//  Created by François Navarro on 2026-03-24.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

@objc(SearchXMLParser) class SearchXMLParser: NSObject, XMLParserDelegate {
    @objc private(set) var listOfArtists: [Artist] = []
    @objc private(set) var listOfAlbums: [Album] = []
    @objc private(set) var listOfSongs: [Song] = []

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // TODO: surface parse error to caller
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "match" || elementName == "song" {
            if attributeDict["isVideo"] != "true" {
                let song = Song(attributeDict: attributeDict)
                if song.path != nil {
                    listOfSongs.append(song)
                }
            }
        } else if elementName == "album" {
            listOfAlbums.append(Album(attributeDict: attributeDict))
        } else if elementName == "artist" {
            listOfArtists.append(Artist(attributeDict: attributeDict))
        }
    }
}
