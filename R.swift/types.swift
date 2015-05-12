//
//  types.swift
//  R.swift
//
//  Created by Mathijs Kadijk on 30-01-15.
//  From: https://github.com/mac-cain13/R.swift
//  License: MIT License
//

import Foundation

/// MARK: Swift types

struct Type: Printable, Equatable {
  static let _Void = Type(name: "Void")
  static let _AnyObject = Type(name: "AnyObject")
  static let _String = Type(name: "String")
  static let _UINib = Type(name: "UINib")
  static let _UIImage = Type(name: "UIImage")
  static let _UIStoryboard = Type(name: "UIStoryboard")
  static let _UIViewController = Type(name: "UIViewController")

  let module: String?
  let name: String
  let optional: Bool

  var fullyQualifiedName: String {
    let optionalString = optional ? "?" : ""

    if let module = module {
      return "\(module).\((name))\(optionalString)"
    }

    return "\(name)\(optionalString)"
  }

  var description: String {
    return fullyQualifiedName
  }

  init(name: String, optional: Bool = false) {
    self.module = nil
    self.name = name
    self.optional = optional
  }

  init(module: String?, name: String, optional: Bool = false) {
    self.module = module
    self.name = name
    self.optional = optional
  }

  func asOptional() -> Type {
    return Type(module: module, name: name, optional: true)
  }

  func asNonOptional() -> Type {
    return Type(module: module, name: name, optional: false)
  }
}

func ==(lhs: Type, rhs: Type) -> Bool {
  return (lhs.module == rhs.module && lhs.name == rhs.name && lhs.optional == rhs.optional)
}

struct Var: Printable {
  let name: String
  let type: Type
  let getter: String

  var description: String {
    let swiftName = sanitizedSwiftName(name, lowercaseFirstCharacter: true)
    return "static var \(swiftName): \(type) { \(getter) }"
  }
}

struct Function: Printable {
  let name: String
  let parameters: [Parameter]
  let returnType: Type
  let body: String

  var description: String {
    let swiftName = sanitizedSwiftName(name, lowercaseFirstCharacter: true)
    let parameterString = join(", ", parameters)
    let returnString = Type._Void == returnType ? "" : " -> \(returnType)"
    return "static func \(swiftName)(\(parameterString))\(returnString) {\n\(indent(body))\n}"
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
      self.localName = nil
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
  let lowercaseFirstCharacter: Bool

  init(name: String, vars: [Var], functions: [Function], structs: [Struct], lowercaseFirstCharacter: Bool = true) {
    self.name = name
    self.vars = vars
    self.functions = functions
    self.structs = structs
    self.lowercaseFirstCharacter = lowercaseFirstCharacter
  }

  var description: String {
    let swiftName = sanitizedSwiftName(name, lowercaseFirstCharacter: lowercaseFirstCharacter)
    let varsString = join("\n", vars.sorted { sanitizedSwiftName($0.name) < sanitizedSwiftName($1.name) })
    let functionsString = join("\n\n", functions.sorted { sanitizedSwiftName($0.name) < sanitizedSwiftName($1.name) })
    let structsString = join("\n\n", structs.sorted { sanitizedSwiftName($0.name) < sanitizedSwiftName($1.name) })

    let bodyComponents = [varsString, functionsString, structsString].filter { $0 != "" }
    let bodyString = indent(join("\n\n", bodyComponents))
    return "struct \(swiftName) {\n\(bodyString)\n}"
  }
}

/// MARK: Asset types

protocol ReuseIdentifierContainer {
  var reuseIdentifiers: [String] { get }
}

struct AssetFolder {
  let name: String
  let imageAssets: [String]

  init(url: NSURL, fileManager: NSFileManager) {
    name = url.filename!

    // Browse asset directory recursively and list only the assets folders
    var assets = [NSURL]()
    let enumerator = fileManager.enumeratorAtURL(url, includingPropertiesForKeys: nil, options: .SkipsHiddenFiles, errorHandler: nil)
    if let enumerator = enumerator {
      for file in enumerator {
        if let fileURL = file as? NSURL, pathExtension = fileURL.pathExtension where find(AssetExtensions, pathExtension) != nil {
          assets.append(fileURL)
        }
      }
    }
    
    imageAssets = assets.map { $0.filename! }
  }
}

struct Storyboard: ReuseIdentifierContainer {
  let name: String
  let segues: [String]
  private let initialViewControllerIdentifier: String?
  let viewControllers: [ViewController]
  let usedImageIdentifiers: [String]
  let reuseIdentifiers: [String]

  var initialViewController: ViewController? {
    return viewControllers.filter { $0.id == self.initialViewControllerIdentifier }.first
  }

  init(url: NSURL) {
    name = url.filename!

    let parserDelegate = StoryboardParserDelegate()

    let parser = NSXMLParser(contentsOfURL: url)!
    parser.delegate = parserDelegate
    parser.parse()

    segues = parserDelegate.segues
    initialViewControllerIdentifier = parserDelegate.initialViewControllerIdentifier
    viewControllers = parserDelegate.viewControllers
    usedImageIdentifiers = parserDelegate.usedImageIdentifiers
    reuseIdentifiers = parserDelegate.reuseIdentifiers
  }

  struct ViewController {
    let id: String
    let storyboardIdentifier: String?
    let type: Type
  }
}

struct Nib: ReuseIdentifierContainer {
  let name: String
  let rootViews: [Type]
  let reuseIdentifiers: [String]

  init(url: NSURL) {
    name = url.filename!

    let parserDelegate = NibParserDelegate();

    let parser = NSXMLParser(contentsOfURL: url)!
    parser.delegate = parserDelegate
    parser.parse()

    rootViews = parserDelegate.rootViews
    reuseIdentifiers = parserDelegate.reuseIdentifiers
  }
}

/// MARK: Parsers

class StoryboardParserDelegate: NSObject, NSXMLParserDelegate {
  var initialViewControllerIdentifier: String?
  var segues: [String] = []
  var viewControllers: [Storyboard.ViewController] = []
  var usedImageIdentifiers: [String] = []
  var reuseIdentifiers: [String] = []

  func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [NSObject : AnyObject]) {
    switch elementName {
    case "document":
      if let initialViewController = attributeDict["initialViewController"] as? String {
        initialViewControllerIdentifier = initialViewController
      }

    case "segue":
      if let segueIdentifier = attributeDict["identifier"] as? String {
        segues.append(segueIdentifier)
      }

    case "image":
      if let imageIdentifier = attributeDict["name"] as? String {
        usedImageIdentifiers.append(imageIdentifier)
      }

    default:
      if let viewController = viewControllerFromAttributes(attributeDict, elementName: elementName) {
        viewControllers.append(viewController)
      }
    }

    if let reuseIdentifier = attributeDict["reuseIdentifier"] as? String {
      reuseIdentifiers.append(reuseIdentifier)
    }
  }

  func viewControllerFromAttributes(attributeDict: [NSObject : AnyObject], elementName: String) -> Storyboard.ViewController? {
    if attributeDict["sceneMemberID"] as? String == "viewController" {
        if let id = attributeDict["id"] as? String {
            let storyboardIdentifier = attributeDict["storyboardIdentifier"] as? String

            let customModule = attributeDict["customModule"] as? String
            let customClass = attributeDict["customClass"] as? String
            let customType = customClass.map { Type(module: customModule, name: $0, optional: false) }

            let type = customType ?? ElementNameToTypeMapping[elementName] ?? Type._UIViewController

            return Storyboard.ViewController(id: id, storyboardIdentifier: storyboardIdentifier, type: type)
        }
    }

    return nil
  }
}

class NibParserDelegate: NSObject, NSXMLParserDelegate {
  let ignoredRootViewElements = ["placeholder"]
  var rootViews: [Type] = []
  var reuseIdentifiers: [String] = []

  // State
  var isObjectsTagOpened = false;
  var levelSinceObjectsTagOpened = 0;

  func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [NSObject : AnyObject]) {
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

    if let reuseIdentifier = attributeDict["reuseIdentifier"] as? String {
      reuseIdentifiers.append(reuseIdentifier)
    }
  }

  func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
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
    let customClass = (attributeDict["customClass"] as? String) ?? "UIView"
    
    return Type(module: customModule, name: customClass)
  }
}
