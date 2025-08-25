import ArgumentParser
import ProjectDrivers
import Foundation
import PeripheryKit
import SourceGraph
import Configuration
import Scan
import UseGraphCore
import Shared
import XcodeSupport

struct Reference: Hashable, Comparable {
    static func < (lhs: Reference, rhs: Reference) -> Bool {
        lhs.file < rhs.file || lhs.line < rhs.line
    }

    let line: Int
    let file: String
}

struct Edge: Hashable {
    let from: Node
    let to: Node
    let references: [Reference]
}

struct EdgeWithoutReference: Hashable {
    let from: Node
    let to: Node
}

enum PathError: Error {
    case pathIsNotCorrect
    case shouldBeOnlyOnePath

    var localizedDescription: String {
        switch self {
        case .pathIsNotCorrect:
            "Path is not correct. Check your path."
        case .shouldBeOnlyOnePath:
            "You should set strictly one path. Not a zero and not a both of them. Project or folder"
        }
    }
}

public struct UseGraphPeripheryBuildCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "usage_graph",
        abstract: "Command to build graph of usage.",
        version: "0.0.1"
    )

    @Option(help: "Path to project (.xcodeproj)")
    var projectPath: String? = nil

    @Option(help: "Schemes to analyze")
    var schemes: String
    
    @Option(help: "Paths to index store")
    var indexStore: String? = nil
    
    @Option(help: "Output file format. Now available: CSV, SVG, PNG, GV")
    var format: String = "csv"

    public func run() async throws {
        let configuration = Configuration()
        if let projectPath {
            configuration.project = .init(projectPath)
            configuration.schemes = schemes.components(separatedBy: ",")
        }

        let project = try Project(configuration: configuration)

        if let indexStore {
            configuration.indexStorePath = [.makeAbsolute(indexStore)]
        } else {
            let driver = try project.driver()
            try driver.build()
        }
        let graph = SourceGraph(configuration: configuration, logger: .init(quiet: true))
        
        _ = try Scan(
            configuration: configuration,
            sourceGraph: graph
        )
            .perform(project: project)

        var edgeDict: [EdgeWithoutReference: [Reference]] = [:]

        graph.allReferences
            .forEach {
                if let declaration = graph.allDeclarationsByUsr[$0.usr],
                   declaration.parent != $0.parent
                {
                    
                    guard let entity = $0.parent?.findEntity(),
                          entity != declaration.findEntity(),
                          let entityParent = entity.presentAsNode(),
                          let declarationParent = declaration.presentAsNode() else { return }
                    let edge = EdgeWithoutReference(
                        from: entityParent,
                        to: declarationParent
                    )
                    if !edgeDict.keys.contains(edge) {
                        edgeDict[edge] = []
                    }
                    edgeDict[edge]?.append(
                        Reference(
                            line: $0.location.line,
                            file: $0.location.file.path.string
                        )
                    )
                }
            }
        
        let edges = edgeDict.compactMap {
            Edge(from: $0.key.from, to: $0.key.to, references: $0.value)
        }
        try await GraphBuilder.shared.buildGraph(edges: edges, format: OutputFormat.parse(format: format))
    }
}

extension Declaration {
    func findEntity() -> Declaration? {
        var parent: Declaration? = self
        while parent != nil,
              parent?.kind != .class,
              parent?.kind != .enum,
              parent?.kind != .struct,
              parent?.kind != .extension,
              parent?.kind != .protocol,
              parent?.kind != .typealias,
              parent?.kind != .extensionEnum,
              parent?.kind != .extensionStruct,
              parent?.kind != .extensionClass,
              parent?.kind != .extensionProtocol
        {
            parent = parent?.parent
        }
        return parent
    }

    func presentAsNode() -> Node? {
        let entity = findEntity()
        guard let entity else { return nil }

        // Безопасное извлечение модуля
        let moduleName = entity.location.file.modules.first ?? "UnknownModule"

        return Node(
            moduleName: moduleName,
            fileName: entity.location.file.path.string,
            line: String(entity.location.line),
            entityName: entity.name,
            containerName: entity.parent?.name,
            entityType: entity.kind.rawValue,
            usrs: entity.usrs
        )
    }
}
