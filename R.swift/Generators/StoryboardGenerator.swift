//
//  Storyboard.swift
//  R.swift
//
//  Created by Mathijs Kadijk on 10-12-15.
//  Copyright © 2015 Mathijs Kadijk. All rights reserved.
//

import Foundation

struct StoryboardGenerator: Generator {
  let externalStruct: Struct?
  let internalStruct: Struct?

  init(storyboards: [Storyboard]) {
    let groupedStoryboards = storyboards.groupUniquesAndDuplicates { sanitizedSwiftName($0.name) }

    for duplicate in groupedStoryboards.duplicates {
      let names = duplicate.map { $0.name }.sort().joinWithSeparator(", ")
      warn("Skipping \(duplicate.count) storyboards because symbol '\(sanitizedSwiftName(duplicate.first!.name))' would be generated for all of these storyboards: \(names)")
    }

    let storyboardStructs = groupedStoryboards
      .uniques
      .map(StoryboardGenerator.storyboardStructForStoryboard)

    externalStruct = Struct(
        type: Type(module: .Host, name: "storyboard"),
        implements: [],
        typealiasses: [],
        properties: storyboardStructs.map {
          Let(isStatic: false, name: $0.type.name, type: nil, value: "_R.storyboard.\($0.type.name)()")
        },
        functions: [],
        structs: []
      )

    internalStruct = Struct(
      type: Type(module: .Host, name: "storyboard"),
      implements: [],
      typealiasses: [],
      properties: [],
      functions: [],
      structs: storyboardStructs
    )
  }

  private static func storyboardStructForStoryboard(storyboard: Storyboard) -> Struct {

    let instantiateViewControllerFunctions = storyboard.viewControllers
      .flatMap { (vc) -> Function? in
        let getterCast = (vc.type.asNonOptional() == Type._UIViewController) ? "" : " as? \(vc.type.asNonOptional())"
        return vc.storyboardIdentifier.map {
          Function(
            isStatic: false,
            name: $0,
            generics: nil,
            parameters: [],
            doesThrow: false,
            returnType: vc.type.asOptional(),
            body: "return UIStoryboard(resource: self).instantiateViewControllerWithIdentifier(\"\($0)\")\(getterCast)"
          )
        }
      }

    let validateImagesLines = Set(storyboard.usedImageIdentifiers)
      .map {
        "if UIImage(named: \"\($0)\") == nil { throw ValidationError(description: \"[R.swift] Image named '\($0)' is used in storyboard '\(storyboard.name)', but couldn't be loaded.\") }"
      }
    let validateViewControllersLines = storyboard.viewControllers
      .flatMap { vc in
        vc.storyboardIdentifier.map {
          "if \(sanitizedSwiftName(storyboard.name))().\(sanitizedSwiftName($0))() == nil { throw ValidationError(description:\"[R.swift] ViewController with identifier '\(sanitizedSwiftName($0))' could not be loaded from storyboard '\(storyboard.name)' as '\(vc.type)'.\") }"
        }
      }

    var implements = [Type.Validatable]
    var typealiasses: [Typealias] = []
    if let initialViewController = storyboard.initialViewController {
      implements.append(Type.StoryboardResourceWithInitialControllerProtocol)
      typealiasses.append(Typealias(alias: "InitialController", type: initialViewController.type))
    } else {
      implements.append(Type.StoryboardResource)
    }

    let validateFunction = Function(
      isStatic: true,
      name: "validate",
      generics: nil,
      parameters: [],
      doesThrow: true,
      returnType: Type._Void,
      body: (validateImagesLines + validateViewControllersLines).joinWithSeparator("\n")
    )

    return Struct(
      type: Type(module: .Host, name: sanitizedSwiftName(storyboard.name)),
      implements: implements,
      typealiasses: typealiasses,
      properties: [
        Let(isStatic: false, name: "name", type: nil, value: "\"\(storyboard.name)\""),
        Let(isStatic: false, name: "bundle", type: nil, value: "_R.hostingBundle"),
      ],
      functions: [
        validateFunction,
        ] + instantiateViewControllerFunctions,
      structs: []
    )
  }
}
