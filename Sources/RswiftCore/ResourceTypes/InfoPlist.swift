//
//  InfoPlist.swift
//  Commander
//
//  Created by Tom Lokhorst on 2018-07-08.
//

import Foundation

struct InfoPlist {
  let buildConfigurationName: String
  let contents: [String: Any]
  let url: URL

  init(buildConfigurationName: String, url: URL) throws {
    guard
      let nsDictionary = NSDictionary(contentsOf: url),
      let dictionary = nsDictionary as? [String: Any]
    else {
      throw ResourceParsingError.parsingFailed("File could not be parsed as InfoPlist from URL: \(url.absoluteString)")
    }

    self.buildConfigurationName = buildConfigurationName
    self.contents = dictionary
    self.url = url
  }
}
