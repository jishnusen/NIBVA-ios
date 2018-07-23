//
//  DataView.swift
//  SimpleBLE
//
//  Created by Jishnu Sen on 7/22/18.
//  Copyright © 2018 Jishnu Sen. All rights reserved.
//

import UIKit

struct cellData {
    var opened = Bool()
    var title = String()
    var sectionData = [String]()
}

class DataView: UITableViewController {
    let leds = ["LED 1", "LED 2", "LED 3", "LED 4", "LED 5", "LED 6", "LED 7", "LED 8"]
    
    static var tableViewData = [cellData](repeating: cellData(), count: 8)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var i: Int = 0
        for led in leds {
            DataView.tableViewData[i] = cellData(opened: false, title: led, sectionData: ["    Diode 1", "    Diode 2", "    Diode 3", "    Diode 4", "    Diode 5", "    Diode 6", "    Diode 7", "    Diode 8"])
            i += 1
        }
    }
    
    static func updateDiode(led: Int, diode: Int, value: String) {
        if (diode > 7) {
            tableViewData[led].title = "LED \(led + 1): \(value)"
            return
        }
        tableViewData[led].sectionData[diode] = "    Diode \(diode + 1): \(value)"
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return leds.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if DataView.tableViewData[section].opened == true {
            return DataView.tableViewData[section].sectionData.count + 1
        }
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (indexPath.row == 0) {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell") else {
                return UITableViewCell()
            }
            cell.textLabel?.text = DataView.tableViewData[indexPath.section].title
            return cell
        } else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell") else {
                return UITableViewCell()
            }
            cell.textLabel?.text = DataView.tableViewData[indexPath.section].sectionData[indexPath.row - 1]
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            if DataView.tableViewData[indexPath.section].opened == true {
                DataView.tableViewData[indexPath.section].opened = false
                let sections = IndexSet.init(integer: indexPath.section)
                tableView.reloadSections(sections, with: .none)
            } else {
                DataView.tableViewData[indexPath.section].opened = true
                let sections = IndexSet.init(integer: indexPath.section)
                tableView.reloadSections(sections, with: .none)
            }
        }
        
    }
}
