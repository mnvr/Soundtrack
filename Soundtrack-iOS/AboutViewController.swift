//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import UIKit

class AboutViewController: UIViewController {

    @IBOutlet var versionLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        versionLabel.text = Bundle.main.humanReadableVersion!
    }

    @IBAction func tapDroneZone(_ sender: Any) {
        let url = URL(string: "https://SomaFM.com/dronezone/")!
        UIApplication.shared.openURL(url)
    }

    @IBAction func tapOpenSource(_ sender: Any) {
        let url = URL(string: "https://github.com/mnvr/Soundtrack")!
        UIApplication.shared.openURL(url)
    }
}
