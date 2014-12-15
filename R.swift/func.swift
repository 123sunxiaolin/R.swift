//
//  func.swift
//  R.swift
//
//  Created by Mathijs Kadijk on 14-12-14.
//  From: https://github.com/mac-cain13/R.swift
//  License: MIT License
//

import Foundation

// MARK: Types

let ResourceFilename = "R.generated.swift"

struct AssetFolder {
  let name: String
  let imageAssets: [String]

  init(url: NSURL, fileManager: NSFileManager) {
    name = url.filename!

    let contents = fileManager.contentsOfDirectoryAtURL(url, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions.SkipsHiddenFiles, error: nil) as [NSURL]
    imageAssets = contents.map { $0.filename! }
  }
}

struct Storyboard {
  let name: String
  let segues: [String]
  let usedImageIdentifiers: [String]

  init(url: NSURL) {
    name = url.filename!

    let parserDelegate = StoryboardParserDelegate()
    let parser = NSXMLParser(contentsOfURL: url)!
    parser.delegate = parserDelegate
    parser.parse()

    segues = parserDelegate.segues
    usedImageIdentifiers = parserDelegate.usedImageIdentifiers
  }
}

class StoryboardParserDelegate: NSObject, NSXMLParserDelegate {
  var segues: [String] = []
  var usedImageIdentifiers: [String] = []

  func parser(parser: NSXMLParser!, didStartElement elementName: String!, namespaceURI: String!, qualifiedName qName: String!, attributes attributeDict: [NSObject : AnyObject]!) {
    switch elementName {
    case "segue":
      if let segueIdentifier = attributeDict["identifier"] as? String {
        segues.append(segueIdentifier)
      }

    case "image":
      if let imageIdentifier = attributeDict["name"] as? String {
        usedImageIdentifiers.append(imageIdentifier)
      }

    default:
      break
    }
  }
}

// MARK: Functions

func inputDirectories(processInfo: NSProcessInfo) -> [NSURL] {
  return processInfo.arguments.skip(1).map { NSURL(fileURLWithPath: $0 as String)! }
}

func filterDirectoryContentsRecursively(fileManager: NSFileManager, filter: (NSURL) -> Bool)(url: NSURL) -> [NSURL] {
  var assetFolders = [NSURL]()

  if let enumerator = fileManager.enumeratorAtURL(url, includingPropertiesForKeys: [NSURLIsDirectoryKey], options: NSDirectoryEnumerationOptions.SkipsHiddenFiles|NSDirectoryEnumerationOptions.SkipsPackageDescendants, errorHandler: nil) {

    while let enumeratorItem: AnyObject = enumerator.nextObject() {
      if let url = enumeratorItem as? NSURL {
        if filter(url) {
          assetFolders.append(url)
          enumerator.skipDescendants()
        }
      }
    }

  }

  return assetFolders
}

func swiftStructForAssetFolder(assetFolder: AssetFolder) -> String {
  return distinct(assetFolder.imageAssets).reduce("  struct \(sanitizedSwiftName(assetFolder.name)) {\n") {
    $0 + "    static var \(sanitizedSwiftName($1)): UIImage? { return UIImage(named: \"\($1)\") }\n"
  } + "  }\n"
}

func swiftStructForStoryboard(storyboard: Storyboard) -> String {
  let segueIdentifiers = distinct(storyboard.segues).reduce("") {
      $0 + "    static var \(sanitizedSwiftName($1)): String { return \"\($1)\" }\n"
    }

  let validateStoryboardImages = distinct(storyboard.usedImageIdentifiers).reduce("    static func validateStoryboardImages() {\n") {
      $0 + "      assert(UIImage(named: \"\($1)\") != nil, \"[R.swift] Image named '\($1)' is used in storyboard '\(storyboard.name)', but couldn't be loaded.\")\n"
    } + "    }\n"

  return "  struct \(sanitizedSwiftName(storyboard.name)) {\n" + segueIdentifiers + "\n" + validateStoryboardImages + "  }\n"
}

func swiftCallStoryboardImageValidation(storyboard: Storyboard) -> String {
  return "    \(sanitizedSwiftName(storyboard.name)).validateStoryboardImages()\n"
}

func sanitizedSwiftName(name: String) -> String {
  var components = name.componentsSeparatedByString("-")
  let firstComponent = components.removeAtIndex(0)
  return components.reduce(firstComponent) { $0 + $1.capitalizedString }.lowercaseFirstCharacter
}

func writeResourceFile(code: String, toFolderURL folderURL: NSURL) {
  let outputURL = folderURL.URLByAppendingPathComponent(ResourceFilename)
  code.writeToURL(outputURL, atomically: true, encoding: NSUTF8StringEncoding, error: nil)
}
