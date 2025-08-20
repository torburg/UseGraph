import Foundation

public protocol CSVBuilding {
  func createCSV(from recArray: [CSVRepresentable]) -> String
}

public final class CSVBuilder: CSVBuilding {
  public init() {}
  
  public func createCSV(from recArray: [CSVRepresentable]) -> String {
      guard let fields = recArray.first?.fields else { return "" }
      
      // Используем более эффективный способ построения строки
      var lines = [String]()
      lines.reserveCapacity(recArray.count + 1)
      
      // Добавляем заголовок
      lines.append(fields.joined(separator: ","))
      
      // Добавляем данные
      for record in recArray {
          lines.append(record.csvRepresentation)
      }
      
      return lines.joined(separator: "\n") + "\n"
  }
}
