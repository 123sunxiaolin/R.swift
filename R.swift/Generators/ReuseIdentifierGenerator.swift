//
//  ReuseIdentifier.swift
//  R.swift
//
//  Created by Mathijs Kadijk on 10-12-15.
//  Copyright © 2015 Mathijs Kadijk. All rights reserved.
//

import Foundation

struct ReuseIdentifierGenerator: Generator {
  let externalStruct: Struct?
  let internalStruct: Struct? = nil

  init(reusables: [Reusable]) {
    let deduplicatedReusables = reusables
      .groupBy { $0.hashValue }
      .values
      .flatMap { $0.first }

    let groupedReusables = deduplicatedReusables.groupUniquesAndDuplicates { sanitizedSwiftName($0.identifier) }

    for duplicate in groupedReusables.duplicates {
      let names = duplicate.map { $0.identifier }.sort().joinWithSeparator(", ")
      warn("Skipping \(duplicate.count) reuseIdentifiers because symbol '\(sanitizedSwiftName(duplicate.first!.identifier))' would be generated for all of these reuseIdentifiers: \(names)")
    }

    let reuseIdentifierVars = groupedReusables
      .uniques
      .map(ReuseIdentifierGenerator.varFromReusable)

    externalStruct = Struct(
      type: Type(module: .Host, name: "reuseIdentifier"),
      implements: [],
      typealiasses: [],
      vars: reuseIdentifierVars,
      functions: [],
      structs: []
    )
  }

  private static func varFromReusable(reusable: Reusable) -> Var {
    // TODO: Report the generic arguments as used types of this var, now we're missing a module!
    return Var(
      isStatic: true,
      name: reusable.identifier,
      type: Type.ReuseIdentifier.withGenericArgs([reusable.type]),
      getter: "return \(Type.ReuseIdentifier.name)(identifier: \"\(reusable.identifier)\")"
    )
  }
}
