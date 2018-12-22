#!/usr/bin/swift
//
//  main.swift
//  NodeChecker
//
//  Created by Joao Nunes on 16/10/2018.
//

extension URLSession {
    func sendSynchronousRequest(with request: URLRequest) -> (Data?, URLResponse?, Error?) {
        var data: Data?, response: URLResponse?, error: Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        dataTask(with: request) {
            data = $0; response = $1; error = $2
            semaphore.signal()
            }.resume()
        
        semaphore.wait()
        
        return (data, response, error)
    }
}


struct TopLevel: Codable {
    let last1_Days: Last1_Days
    let nodeData: NodeData

    enum CodingKeys: String, CodingKey {
        case last1_Days = "last_1_days"
        case nodeData
    }
}

struct Last1_Days: Codable {
    let year, month, day, last24Hrs: Int
    let hour: Int
    let hashesReceivedToday: [String]
}

struct NodeData: Codable {
    let audits: [Audit]
    let core: Core
    let node: Node
    let nodeRegistered: Bool
    let nodePublicURI, nodeTntAddr, dataFromCoreLastReceived: String

    enum CodingKeys: String, CodingKey {
        case audits, core, node
        case nodeRegistered = "node_registered"
        case nodePublicURI = "node_public_uri"
        case nodeTntAddr = "node_tnt_addr"
        case dataFromCoreLastReceived
    }
}

struct Audit: Codable {
    let auditAt: Int
    let auditPassed, publicIPPass: Bool
    let publicURI: String
    let nodeMSDelta: Int
    let timePass, calStatePass, minCreditsPass: Bool
    let nodeVersion: String
    let nodeVersionPass: Bool
    let tntBalanceGrains: Int
    let tntBalancePass: Bool

    enum CodingKeys: String, CodingKey {
        case auditAt = "audit_at"
        case auditPassed = "audit_passed"
        case publicIPPass = "public_ip_pass"
        case publicURI = "public_uri"
        case nodeMSDelta = "node_ms_delta"
        case timePass = "time_pass"
        case calStatePass = "cal_state_pass"
        case minCreditsPass = "min_credits_pass"
        case nodeVersion = "node_version"
        case nodeVersionPass = "node_version_pass"
        case tntBalanceGrains = "tnt_balance_grains"
        case tntBalancePass = "tnt_balance_pass"
    }
}

struct Core: Codable {
    let totalActiveNodes: Int

    enum CodingKeys: String, CodingKey {
        case totalActiveNodes = "total_active_nodes"
    }
}

struct Node: Codable {
    let tntAddr: String
    let createdAt, updatedAt, passCount, failCount: Int
    let consecutivePasses, consecutiveFails: Int

    enum CodingKeys: String, CodingKey {
        case tntAddr = "tnt_addr"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case passCount = "pass_count"
        case failCount = "fail_count"
        case consecutivePasses = "consecutive_passes"
        case consecutiveFails = "consecutive_fails"
    }
}


struct NodeFile: Codable {
    let ipAddress: String
    let tntAddress: String
    
    enum CodingKeys: String, CodingKey {
        case ipAddress = "ip_addr"
        case tntAddress = "tnt_addr"
    }
}


import Foundation

let fileURL = URL(fileURLWithPath: "./nodes.json")

let jsonDecoder = JSONDecoder()

func parseNodes(jsonData: TopLevel) {
    
    let nodeAddress = jsonData.nodeData.nodeTntAddr
    let nodeURI = jsonData.nodeData.nodePublicURI
    
    if !jsonData.nodeData.audits[0].auditPassed {
      print("Failed audit for node \(nodeAddress) / \(nodeURI) on auditPassed.")
    }
    if !jsonData.nodeData.audits[0].publicIPPass {
        print("Failed audit for node \(nodeAddress) / \(nodeURI) on publicIPPass.")
    }
    if !jsonData.nodeData.audits[0].timePass {
        print("Failed audit for node \(nodeAddress) / \(nodeURI) on timePass.")
    }
    if !jsonData.nodeData.audits[0].calStatePass {
        print("Failed audit for node \(nodeAddress) / \(nodeURI) on calStatePass.")
    }
    if !jsonData.nodeData.audits[0].minCreditsPass {
        print("Failed audit for node \(nodeAddress) / \(nodeURI) on minCreditsPass.")
    }
    if !jsonData.nodeData.audits[0].tntBalancePass {
        print("Failed audit for node \(nodeAddress) / \(nodeURI) on tntBalancePass.")
    }

    if (jsonData.nodeData.node.consecutivePasses > 0) {
        print("[OK] \(jsonData.nodeData.audits[0].nodeVersion) \(nodeAddress) / \(nodeURI) with \(jsonData.nodeData.node.consecutivePasses) consecutive passes.")
    }
    if (jsonData.nodeData.node.consecutiveFails > 0) {
        print("[FAIL] \(nodeAddress) / \(nodeURI) with \(jsonData.nodeData.node.consecutiveFails) consecutive fails.")
    }
    if (!jsonData.nodeData.nodeRegistered) {
        print("[FAIL] \(nodeAddress) / \(nodeURI) not registered.")
    }
}


if let jsonData = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
    let nodes = try? jsonDecoder.decode([NodeFile].self, from: jsonData) {
    
    for node in nodes {
        var request = URLRequest(url: URL(string: "http://\(node.ipAddress)/stats?filter=last_1_days&verbose=true")!)
        request.addValue("\(node.tntAddress.lowercased())", forHTTPHeaderField: "auth")
        let (data, _, _) = URLSession.shared.sendSynchronousRequest(with: request)
        
        if let data = data,
            let jsonData = try? jsonDecoder.decode(TopLevel.self, from: data) {
            parseNodes(jsonData: jsonData)
            //print(jsonData)
        } else {
            print("[FAIL] \(node.tntAddress.lowercased()) / \(node.ipAddress) is down.")
        }
    }
}
