//
//  useprocessApp.swift
//  useprocess
//
//  Created by Amine Ennasri on 13/06/2026.
//

import SwiftUI
import CoreData

@main
struct useprocessApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
