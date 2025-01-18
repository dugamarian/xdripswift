//
//  SceneDelegate.swift
//  xdrip
//
//  Created by Marian Dugaesescu on 16/01/2025.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        // Asigură-te că în Main.storyboard, ViewController-ul are Storyboard ID: "LandscapeValueViewController".
        guard let fullScreenVC = storyboard.instantiateViewController(
            withIdentifier: "LandscapeValueViewController"
        ) as? LandscapeValueViewController else {
            fatalError("LandscapeValueViewController not found in Main.storyboard")
        }

        // Setați direct ca rootViewController pentru a fi sigur că este pe tot ecranul.
        // Dacă îl puneți într-un UINavigationController, asigurați-vă că folosiți modalPresentationStyle = .fullScreen și că
        // preferința de ascundere a Home Indicator nu e suprascrisă de alt controller.
        window.rootViewController = fullScreenVC
        
        self.window = window
        window.makeKeyAndVisible()
    }
}
