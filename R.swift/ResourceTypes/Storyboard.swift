//
//  Storyboard.swift
//  R.swift
//
//  Created by Mathijs Kadijk on 09-12-15.
//  Copyright © 2015 Mathijs Kadijk. All rights reserved.
//

import Foundation

private let ElementNameToTypeMapping = [
  "viewController": Type._UIViewController,
  "tableViewCell": Type(name: "UITableViewCell"),
  "tabBarController": Type(name: "UITabBarController"),
  "glkViewController": Type(module: "GLKit", name: "GLKViewController"),
  "pageViewController": Type(name: "UIPageViewController"),
  "tableViewController": Type(name: "UITableViewController"),
  "splitViewController": Type(name: "UISplitViewController"),
  "navigationController": Type(name: "UINavigationController"),
  "avPlayerViewController": Type(module: "AVKit", name: "AVPlayerViewController"),
  "collectionViewController": Type(name: "UICollectionViewController"),
]

struct Storyboard: WhiteListedExtensionsResourceType, ReusableContainer {
  static let supportedExtensions: Set<String> = ["storyboard"]

  let name: String
  private let initialViewControllerIdentifier: String?
  let viewControllers: [ViewController]
  let usedImageIdentifiers: [String]
  let reusables: [Reusable]

  var initialViewController: ViewController? {
    return viewControllers
      .filter { $0.id == self.initialViewControllerIdentifier }
      .first
  }

  init(url: NSURL) throws {
    try Storyboard.throwIfUnsupportedExtension(url.pathExtension)

    name = url.filename!

    let parserDelegate = StoryboardParserDelegate()

    let parser = NSXMLParser(contentsOfURL: url)!
    parser.delegate = parserDelegate
    parser.parse()

    initialViewControllerIdentifier = parserDelegate.initialViewControllerIdentifier
    viewControllers = parserDelegate.viewControllers
    usedImageIdentifiers = parserDelegate.usedImageIdentifiers
    reusables = parserDelegate.reusables
  }

  struct ViewController {
    let id: String
    let storyboardIdentifier: String?
    let type: Type
    private(set) var segues: [Segue]

    private mutating func addSegue(segue: Segue) {
      segues.append(segue)
    }
  }

  struct Segue {
    let identifier: String
    let type: Type
    let destination: String
  }
}

private class StoryboardParserDelegate: NSObject, NSXMLParserDelegate {
  var initialViewControllerIdentifier: String?
  var viewControllers: [Storyboard.ViewController] = []
  var usedImageIdentifiers: [String] = []
  var reusables: [Reusable] = []

  // State
  var currentViewController: (String, Storyboard.ViewController)?

  @objc func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
    switch elementName {
    case "document":
      if let initialViewController = attributeDict["initialViewController"] {
        initialViewControllerIdentifier = initialViewController
      }

    case "segue":
      if let segueIdentifier = attributeDict["identifier"], segueDestination = attributeDict["destination"] {
        let customModuleProvider = attributeDict["customModuleProvider"]
        let customModule = (customModuleProvider == "target") ? nil : attributeDict["customModule"]
        let customClass = attributeDict["customClass"]

        let module = customModule.map { Module(name: $0) }
        let customType = customClass.map { Type(module: module, name: $0, optional: false) }

        let type = customType ?? Type._UIStoryboardSegue

        let segue = Storyboard.Segue(identifier: segueIdentifier, type: type, destination: segueDestination)
        currentViewController!.1.addSegue(segue)
      }

    case "image":
      if let imageIdentifier = attributeDict["name"] {
        usedImageIdentifiers.append(imageIdentifier)
      }

    default:
      if let viewController = viewControllerFromAttributes(attributeDict, elementName: elementName) {
        currentViewController = (elementName, viewController)
      }

      if let reusable = reusableFromAttributes(attributeDict, elementName: elementName) {
        reusables.append(reusable)
      }
    }
  }

  @objc func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
    if let currentViewController = currentViewController where elementName == currentViewController.0 {
      viewControllers.append(currentViewController.1)
      self.currentViewController = nil
    }
  }

  func viewControllerFromAttributes(attributeDict: [String : String], elementName: String) -> Storyboard.ViewController? {
    guard let id = attributeDict["id"] where attributeDict["sceneMemberID"] == "viewController" else {
      return nil
    }

    let storyboardIdentifier = attributeDict["storyboardIdentifier"]

    let customModuleProvider = attributeDict["customModuleProvider"]
    let customModule = (customModuleProvider == "target") ? nil : attributeDict["customModule"]
    let customClass = attributeDict["customClass"]

    let module = customModule.map { Module(name: $0) }
    let customType = customClass.map { Type(module: module, name: $0, optional: false) }

    let type = customType ?? ElementNameToTypeMapping[elementName] ?? Type._UIViewController

    return Storyboard.ViewController(id: id, storyboardIdentifier: storyboardIdentifier, type: type, segues: [])
  }

  func reusableFromAttributes(attributeDict: [String : String], elementName: String) -> Reusable? {
    guard let reuseIdentifier = attributeDict["reuseIdentifier"] else {
      return nil
    }

    let customModuleProvider = attributeDict["customModuleProvider"]
    let customModule = (customModuleProvider == "target") ? nil : attributeDict["customModule"]
    let customClass = attributeDict["customClass"]

    let module = customModule.map { Module(name: $0) }
    let customType = customClass.map { Type(module: module, name: $0, optional: false) }

    let type = customType ?? ElementNameToTypeMapping[elementName] ?? Type._UIView
    
    return Reusable(identifier: reuseIdentifier, type: type)
  }
}

