//
//  types.swift
//  R.swift
//
//  Created by Mathijs Kadijk on 30-01-15.
//  Copyright (c) 2015 Mathijs Kadijk. All rights reserved.
//

import Foundation

/// MARK: Swift types

struct Type: Printable {
  let moduleName: String?
  let className: String
  let optional: Bool

  var fullyQualifiedName: String {
    let optionalString = optional ? "?" : ""

    if let moduleName = moduleName {
      return "\(moduleName).\(className)\(optionalString)"
    }

    return "\(className)\(optionalString)"
  }

  var description: String {
    return fullyQualifiedName
  }

  init(className: String, optional: Bool = false) {
    self.moduleName = nil
    self.className = className
    self.optional = optional
  }

  init(moduleName: String?, className: String, optional: Bool = false) {
    self.moduleName = moduleName
    self.className = className
    self.optional = optional
  }

  func asOptional() -> Type {
    return Type(moduleName: self.moduleName, className: className, optional: true)
  }

  func asNonOptional() -> Type {
    return Type(moduleName: moduleName, className: className, optional: false)
  }
}

struct Var: Printable {
  let isStatic: Bool
  let name: String
  let type: Type
  let getter: String

  var description: String {
    let swiftName = sanitizedSwiftName(name, lowercaseFirstCharacter: true)
    return (isStatic ? "static " : "") + "var \(swiftName): \(type) { \(getter) }"
  }
}

struct Function: Printable {
  let isStatic: Bool
  let name: String
  let parameters: [Parameter]
  let returnType: Type
  let body: String

  var description: String {
    let swiftName = sanitizedSwiftName(name, lowercaseFirstCharacter: true)
    let parameterString = join(", ", parameters)
    return (isStatic ? "static " : "") + "func \(swiftName)(\(parameterString)) -> \(returnType) {\n\(indent(body))\n}"
  }

  struct Parameter: Printable {
    let name: String
    let localName: String?
    let type: Type

    var description: String {
      let swiftName = sanitizedSwiftName(name, lowercaseFirstCharacter: true)

      if let localName = localName {
        return "\(swiftName) \(localName): \(type)"
      }

      return "\(swiftName): \(type)"
    }

    init(name: String, type: Type) {
      self.name = name
      self.type = type
    }

    init(name: String, localName: String?, type: Type) {
      self.name = name
      self.localName = localName
      self.type = type
    }
  }
}

struct Struct: Printable {
  let name: String
  let vars: [Var]
  let functions: [Function]
  let structs: [Struct]

  var description: String {
    let swiftName = sanitizedSwiftName(name, lowercaseFirstCharacter: false)
    let varsString = join("\n", vars)
    let functionsString = join("\n\n", functions)
    let structsString = join("\n\n", structs)

    let bodyComponents = [varsString, functionsString, structsString].filter { $0 != "" }
    let bodyString = indent(join("\n\n", bodyComponents))
    return "struct \(swiftName) {\n\(bodyString)\n}"
  }
}

/// MARK: Asset types

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
  let viewControllers: [ViewController]
  let usedImageIdentifiers: [String]

  init(url: NSURL) {
    name = url.filename!

    let parserDelegate = StoryboardParserDelegate()

    let parser = NSXMLParser(contentsOfURL: url)!
    parser.delegate = parserDelegate
    parser.parse()

    segues = parserDelegate.segues
    viewControllers = parserDelegate.viewControllers
    usedImageIdentifiers = parserDelegate.usedImageIdentifiers
  }

  struct ViewController {
    let storyboardIdentifier: String
    let type: Type
  }
}

struct Nib {
  let name: String
  let rootViews: [Type]

  init(url: NSURL) {
    name = url.filename!

    let parserDelegate = NibParserDelegate();

    let parser = NSXMLParser(contentsOfURL: url)!
    parser.delegate = parserDelegate
    parser.parse()

    rootViews = parserDelegate.rootViews
  }
}

/// MARK: Parsers

class StoryboardParserDelegate: NSObject, NSXMLParserDelegate {
  var segues: [String] = []
  var viewControllers: [Storyboard.ViewController] = []
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
      if let viewController = viewControllerFromAttributes(attributeDict) {
        viewControllers.append(viewController)
      }
    }
  }

  func viewControllerFromAttributes(attributeDict: [NSObject : AnyObject]) -> Storyboard.ViewController? {
    if attributeDict["sceneMemberID"] as? String == "viewController" {
      if let storyboardIdentifier = attributeDict["storyboardIdentifier"] as? String {
        let customModule = attributeDict["customModule"] as? String
        let customClass = attributeDict["customClass"] as? String ?? "UIViewController"

        return Storyboard.ViewController(storyboardIdentifier: storyboardIdentifier, type: Type(moduleName: customModule, className: customClass, optional: false))
      }
    }
    
    return nil
  }
}

class NibParserDelegate: NSObject, NSXMLParserDelegate {
  let ignoredRootViewElements = ["placeholder"]
  var rootViews: [Type] = []

  // State
  var isObjectsTagOpened = false;
  var levelSinceObjectsTagOpened = 0;

  func parser(parser: NSXMLParser!, didStartElement elementName: String!, namespaceURI: String!, qualifiedName qName: String!, attributes attributeDict: [NSObject : AnyObject]!) {
    switch elementName {
    case "objects":
      isObjectsTagOpened = true;

    default:
      if isObjectsTagOpened {
        levelSinceObjectsTagOpened++;

        if levelSinceObjectsTagOpened == 1 && ignoredRootViewElements.filter({ $0 == elementName }).count == 0 {
          if let rootView = viewWithAttributes(attributeDict) {
            rootViews.append(rootView)
          }
        }
      }
    }
  }

  func parser(parser: NSXMLParser!, didEndElement elementName: String!, namespaceURI: String!, qualifiedName qName: String!) {
    switch elementName {
    case "objects":
      isObjectsTagOpened = false;

    default:
      if isObjectsTagOpened {
        levelSinceObjectsTagOpened--;
      }
    }
  }

  func viewWithAttributes(attributeDict: [NSObject : AnyObject]) -> Type? {
    let customModule = attributeDict["customModule"] as? String
    let customClass = attributeDict["customClass"] as? String ?? "UIView"
    
    return Type(moduleName: customModule, className: customClass)
  }
}
