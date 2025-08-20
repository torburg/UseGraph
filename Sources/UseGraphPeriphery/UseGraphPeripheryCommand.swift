import ArgumentParser
import System
import ProjectDrivers
import Foundation
import Configuration
import SourceGraph
import Scan
import Shared
import Utils
import XcodeSupport

public struct UseGraphPeripheryAnalyzeCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "monolith_destroyer",
        abstract: "Command to build graph of usage.",
        version: "0.0.1"
    )

    @Option(help: "Path to project (.xcodeproj)")
    var projectPath: String? = nil
    
    @Option(help: "Paths to your monolith")
    var monolithPath: String
    
    @Option(help: "Paths to index store")
    var indexStore: String? = nil

    @Option(help: "Schemes to analyze")
    var schemes: String

    public func run() async throws {
        var projectURL: URL?
    
        let folderURLs: [String] = findSubdirectories(atPath: monolithPath)

        if let projectPath {
            projectURL = URL(string: projectPath)
        }

        guard let projectURL else { throw PathError.pathIsNotCorrect }
        let configuration = Configuration()
        if projectPath != nil {
            configuration.project = .init(projectURL.absoluteString)
            configuration.schemes = schemes.components(separatedBy: ",")
        }
        let project = try Project(configuration: configuration)

        if let indexStore {
            configuration.indexStorePath = [.makeAbsolute(indexStore)]
        } else {
            let driver = try project.driver()
            try driver.build()
        }
        
        let graph = SourceGraph(configuration: configuration, logger: .init())
        
        let _ = try Scan(
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

        var counter = 0
        for folderPath in folderURLs {
            let edgesInFolder = edges
                .filter {
                    $0.from.fileName.matches(.init("\(folderPath).*"))
                }
                .filter {
                    $0.to.fileName.matches("^(?!\(folderPath)).*") && $0.to.moduleName == $0.from.moduleName
                }

            guard let url = URL(string: folderPath) else {
                return
            }
            let data = try await GraphBuilder.shared.buildGraphData(edges: edgesInFolder, format: .svg)
            counter += edgesInFolder.count

            let htmlString = HTMLGenerator.shared.generateHTMLTable(
                withLinks: edgesInFolder
                    .sorted {
                        $0.from.id < $1.from.id
                    }
                    .sorted {
                        $0.to.id < $1.to.id
                    }
                    .map {
                        (
                            $0.from.fileName, $0.from.id, $0.to.fileName, $0.to.id, $0.references.sorted(by: { $0 < $1 })
                                .map {
                                    String($0.line)
                                }
                        )
                    },
                svgString: String(data: data, encoding: .utf8) ?? ""
            )
            guard let edgesData = htmlString.data(using: .utf8) else { fatalError() }

            FileManager.default.createFile(atPath: url.appending(path: "module-info.html").path(), contents: edgesData)

            print(folderPath + " - " + String(edgesInFolder.count))
        }
    }
    
    
    func findSubdirectories(atPath path: String) -> [String] {
        let fileManager = FileManager.default
        var subdirectories: [String] = []

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for item in contents {
                let fullPath = (path as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory), isDirectory.boolValue {
                    subdirectories.append(fullPath)
                }
            }
        } catch {
            print("Error while reading the document: \(error)")
        }

        return subdirectories
    }
}

extension String {
    func matches(_ regex: String) -> Bool {
        return range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}
