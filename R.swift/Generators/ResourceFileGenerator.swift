//
//  ResourceFile.swift
//  R.swift
//
//  Created by Mathijs Kadijk on 10-12-15.
//  Copyright © 2015 Mathijs Kadijk. All rights reserved.
//

import Foundation

struct ResourceFileGenerator: Generator {
  let externalStruct: Struct?
  let internalStruct: Struct? = nil

  init(resourceFiles: [ResourceFile]) {
    let groupedResourceFiles = resourceFiles.groupBySwiftNames { $0.fullname }

    for (name, duplicates) in groupedResourceFiles.duplicates {
      warn("Skipping \(duplicates.count) resource files because symbol '\(name)' would be generated for all of these files: \(duplicates.joinWithSeparator(", "))")
    }

    let empties = groupedResourceFiles.empties
    if let empty = empties.first where empties.count == 1 {
      warn("Skipping 1 resource file because no swift identifier can be generated for file: \(empty)")
    }
    else if empties.count > 1 {
      warn("Skipping \(empties.count) resource files because no swift identifier can be generated for all of these files: \(empties.joinWithSeparator(", "))")
    }

    externalStruct = Struct(
      type: Type(module: .Host, name: "file"),
      implements: [],
      typealiasses: [],
      properties: groupedResourceFiles
        .uniques
        .map {
          let pathExtensionOrNilString = $0.pathExtension.map { "\"\($0)\"" } ?? "nil"
          return Let(isStatic: true, name: $0.fullname, typeDefinition: .Inferred(Type.FileResource), value: "FileResource(bundle: _R.hostingBundle, name: \"\($0.filename)\", pathExtension: \(pathExtensionOrNilString))")
        },
      functions: groupedResourceFiles
        .uniques
        .flatMap {
          [
            Function(
              isStatic: true,
              name: $0.fullname,
              generics: nil,
              parameters: [
                Function.Parameter(name: "_", type: Type._Void)
              ],
              doesThrow: false,
              returnType: Type._NSURL.asOptional(),
              body: "let fileResource = R.file.\(sanitizedSwiftName($0.fullname))\nreturn fileResource.bundle.URLForResource(fileResource)"
            )
          ]
        },
      structs: []
    )
  }
}
