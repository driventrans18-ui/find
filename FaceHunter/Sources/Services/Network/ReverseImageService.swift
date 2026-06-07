import Foundation
import UIKit

protocol ReverseImageSearchService {
    func search(imageData: Data) async throws -> [SearchResult]
}

func makeMultipartBody(imageData: Data, fieldName: String, fileName: String, boundary: String) -> Data {
    var body = Data()
    let crlf = "\r\n"
    body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\(crlf)".data(using: .utf8)!)
    body.append("Content-Type: image/jpeg\(crlf)\(crlf)".data(using: .utf8)!)
    body.append(imageData)
    body.append("\(crlf)--\(boundary)--\(crlf)".data(using: .utf8)!)
    return body
}

func urlSession() -> URLSession {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = Constants.Network.requestTimeout
    config.timeoutIntervalForResource = 60
    return URLSession(configuration: config)
}
