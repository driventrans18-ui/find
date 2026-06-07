import Foundation

func faceMultipartBody(imageData: Data, field: String, fileName: String, boundary: String) -> Data {
    var body = Data()
    let crlf = "\r\n"
    body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(fileName)\"\(crlf)".data(using: .utf8)!)
    body.append("Content-Type: image/jpeg\(crlf)\(crlf)".data(using: .utf8)!)
    body.append(imageData)
    body.append("\(crlf)--\(boundary)--\(crlf)".data(using: .utf8)!)
    return body
}

func faceURLSession() -> URLSession {
    let c = URLSessionConfiguration.default
    c.timeoutIntervalForRequest = 30
    return URLSession(configuration: c)
}

let faceUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
