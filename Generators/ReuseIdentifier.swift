//
//  ReuseIdentifier.swift
//  R.swift
//
//  Created by Mathijs Kadijk on 10-12-15.
//  Copyright © 2015 Mathijs Kadijk. All rights reserved.
//

import Foundation

func reuseIdentifierStructFromReusables(reusables: [Reusable]) -> Struct {
  let groupedReusables = reusables.groupUniquesAndDuplicates { sanitizedSwiftName($0.identifier) }

  for duplicate in groupedReusables.duplicates {
    let names = duplicate.map { $0.identifier }.sort().joinWithSeparator(", ")
    warn("Skipping \(duplicate.count) reuseIdentifiers because symbol '\(sanitizedSwiftName(duplicate.first!.identifier))' would be generated for all of these reuseIdentifiers: \(names)")
  }

  let reuseIdentifierVars = groupedReusables
    .uniques
    .map(varFromReusable)

  return Struct(
    type: Type(name: "reuseIdentifier"),
    implements: [],
    typealiasses: [],
    vars: reuseIdentifierVars,
    functions: [],
    structs: []
  )
}

func varFromReusable(reusable: Reusable) -> Var {
  return Var(
    isStatic: true,
    name: reusable.identifier,
    type: Type.ReuseIdentifier.withGenericArgs([reusable.type.name]),
    getter: "return \(Type.ReuseIdentifier.name)(identifier: \"\(reusable.identifier)\")"
  )
}
