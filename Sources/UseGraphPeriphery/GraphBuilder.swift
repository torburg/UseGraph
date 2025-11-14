import Foundation
import GraphViz
import UseGraphCore
import Utils

enum OutputFormat {
    case svg
    case png
    case gv
    case csv
    case json
    
    public static func parse(format: String) throws -> OutputFormat {
        switch format.lowercased() {
        case "svg":
                .svg
        case "png":
                .png
        case "gv":
                .gv
        case "csv":
                .csv
        case "json":
                .json
        default:
            throw FormatError.formatIsNotCorrect
        }
    }
}

final class GraphBuilder {
    static let shared = GraphBuilder()
    let csvBuilder: CSVBuilding
    let jsonBuilder: JSONBuilding
    let outputGraphBuilder: OutputGraphBuilding
    
    private init(
        csvBuilder: CSVBuilding = CSVBuilder(),
        jsonBuilder: JSONBuilding = JSONBuilder(),
        outputGraphBuilder: OutputGraphBuilding = OutputGraphBuilder()
    ) {
        self.csvBuilder = csvBuilder
        self.jsonBuilder = jsonBuilder
        self.outputGraphBuilder = outputGraphBuilder
    }
    
    private func prepareGraphData(from edges: [UseGraphPeriphery.Edge]) -> (nodes: [UseGraphCore.Node], coreEdges: [UseGraphCore.Edge]) {
        var uniqueSet = Set<UseGraphCore.Node>()
        edges.map { [$0.from, $0.to] }.flatMap { $0 }.forEach { uniqueSet.insert($0) }
        
        let nodes = Array(uniqueSet)
        let coreEdges = edges.map { UseGraphCore.Edge(source: $0.from.id, target: $0.to.id) }
        
        return (nodes, coreEdges)
    }
    
    func csvBuildGraph(edges: [UseGraphPeriphery.Edge]) {
        let (nodes, coreEdges) = prepareGraphData(from: edges)
        
        let edgesCSV = csvBuilder.createCSV(from: coreEdges)
        let nodesCSV = csvBuilder.createCSV(from: nodes)
        
        let nodesUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: "Nodes.csv")
        let edgesUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: "Edges.csv")
        
        guard let edgesData = edgesCSV.data(using: .utf8),
              let nodesData = nodesCSV.data(using: .utf8) else { fatalError() }
        FileManager.default.createFile(atPath: edgesUrl.path(), contents: edgesData)
        FileManager.default.createFile(atPath: nodesUrl.path(), contents: nodesData)
    }
    
    func jsonBuildGraph(edges: [UseGraphPeriphery.Edge]) throws {
        let (nodes, _) = prepareGraphData(from: edges)
        
        let edgesJSON = edges.map { edge in
            [
                "source": edge.from.id,
                "target": edge.to.id,
                "type": "directed",
                "references": edge.references.map { ref in
                    [
                        "file": ref.file,
                        "line": ref.line
                    ]
                }
            ]
        }
        
        let jsonData = try jsonBuilder.createJSON(nodes: nodes, edges: edgesJSON)
        
        let jsonUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: "Graph.json")
        FileManager.default.createFile(atPath: jsonUrl.path(), contents: jsonData)
    }
    
    func buildGraph(edges: [Edge], format: OutputFormat) async throws {
        switch format {
        case .svg, .png, .gv:
            guard let format = mapFormat(format: format) else { fatalError() }
            let data = try await buildGraphData(edges: edges, format: format)
            let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: "Graph.\(format.rawValue)")
            FileManager.default.createFile(atPath: url.path(), contents: data)
            System.shared.run("open \(url.path())")
        case .csv:
            csvBuildGraph(edges: edges)
        case .json:
            try jsonBuildGraph(edges: edges)
        }
    }
    
    func buildGraphData(edges: [Edge], format: Format) async throws -> Data {
        var graph = Graph(directed: true)
        
        for edge in edges {
            graph.append(
                GraphViz.Edge(
                    from: GraphViz.Node(edge.from.id),
                    to: GraphViz.Node(edge.to.id)
                )
            )
        }
        
        return try await outputGraphBuilder.buildGraphData(graph: graph, format: format)
    }
}

extension GraphBuilder {
    func mapFormat(format: OutputFormat) -> Format? {
        switch format {
        case .svg:
                .svg
        case .png:
                .png
        case .gv:
                .gv
        case .json:
                .json
        case .csv:
            nil
        }
    }
}
