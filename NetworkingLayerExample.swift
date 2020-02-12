//
//  NetworkingLayerExample.swift
//  Example
//
//  Created by Artak Gevorgyan on 20/11/18.
//

/**
For API calls it's using Alomafire 3rd party framework
Class FontsService responsible to fetch fonts via API
Usage:
FontsService().performFontsRequest(objectId: 45,
				success: { (result) in
				// Success, find fetched fonts in result												
			}) { (error) in
			  print(error.message)
			}

*/
class FontsService {
	
	// NetworkRequest type object to make API request
	var networkRequest: NetworkRequest!
	
	init() {
		self.networkRequest = NetworkRequest()
	}
	
	/**
	Parameters:
	objectId - Int type identifier, for which should be fetched fonts
	success - Block to notify about success fetching, returns collection of FontModel object,
	FontModel object represents Font
	failure - optional, not mandatory Block to notify about fetching fail. 
	 Returns RequestError object which represents Error
	*/
	func performFontsRequest(objectId: Int,
				 success: @escaping(([FontModel]) -> ()),
				 failure: ((RequestError) -> ())?) {
		// Create url object by using API structure, createURL method receives endPoint (in this case 'font') 
		// and parameter objectId which will be used as a parameter in GET request
		let url = API.createURL(endPoint: .fonts, params: ["objectId" : objectId])
		// Create header parameters for request, in this case "Authorization" : "Bearer " + <token_value> 
		let headerParams = API.createHeaderParameters(endPoint: .fonts)
		// So, GET request should be like this
		// https://productionhost.company.com/api/v1/fonts?objectId=45 with Bearer token type Authorization
		
		// Calling NetworkRequest's request function with GET method, url, headerParamaters (bodyParams in our case are empty)
		// success Block with response (FontResponse type object)
		self.networkRequest.request(method: "GET", 
					    with: url,
					    bodyParameters: [:],
					    headerParameters: headerParams,
					    success: { (response) in
						      // Here we should be sure that response is decodable, i.e.
						      // contains all necessary fields which are described in 
						      // FontsResponse class
						      GenericJSONDecoder<Data?, FontsResponse>.decode(response, completion: { (reponseData, errorString) in
								guard let fontsResponseObject = reponseData else { return }
								let fonts = fontsResponseObject.data
								success(fonts)
							})
					   }) { (error) in
					       failure?(error)
		}	
	}
}

struct DefinedValues {
	static let dummyIntValue = -1
}

final class GlobalVariables {
	static var isProdServer = true
}


struct API {
    
    static let scheme = "https"
    static let stageHost = "stagehost.company.com"
    static let productionHost = "productionhost.company.com"
    static let version = "v1"
	
    enum Endpoint: String {
		case fonts
        
        var endpoint: String {
            let path = "/api/" + version + "/"
            switch self {
				case .fonts:
					return path + "fonts"
				default:
					return ""
				}
        }
    }
    
	static func createURL(endPoint: Endpoint,
						  params: [String: Any]) -> URL {
        var urlComponent = URLComponents()
        urlComponent.scheme = scheme
		urlComponent.host = GlobalVariables.isProdServer ? productionHost : stageHost
		urlComponent.path = endPoint.endpoint
		let queryItems = self.createQueryItems(params: params)
		switch endPoint {
			case .fonts:
				urlComponent.queryItems = queryItems
			default:
				urlComponent.queryItems = []
		}
        guard let url = urlComponent.url else {
            fatalError("Error with creation of url.")
        }
        return url
    }
    
    static func createHeaderParameters(endPoint: Endpoint) -> [String: String] {
        switch endPoint {
        case .fonts:
            return ["Authorization" : "Bearer " + UserManager.currentUser.token]
        default:
            return [:]
        }
    }
	
	static func createQueryItems(params: [String: Any]) -> [URLQueryItem] {
		var queryItems = [URLQueryItem]()
		for param in params {
			queryItems.append(URLQueryItem(name: param.key,
											value: "\(param.value)"))
		}
		return queryItems
	}

}

import Alamofire

class NetworkRequest {
					
    func request(method: String,
				 with url: URL,
                 bodyParameters: [String: Any],
                 headerParameters: [String: Any],
				 showIndicator: Bool = true,
                 success: @escaping ((Data?) -> ()), failure:((RequestError) -> ())?) {
		var finalURL = Router.get(url: url, headerParams: [:])
        if (method == "GET") {
			finalURL = Router.get(url: url, headerParams: headerParameters)
        } else if (method == "POST") {
			finalURL = Router.post(url: url, bodyParams: bodyParameters, headerParams: headerParameters)
        } else if (method == "PATCH") {
			finalURL = Router.patch(url: url, bodyParams: bodyParameters, headerParams: headerParameters)
		} else if (method == "DELETE") {
			finalURL = Router.delete(url: url, bodyParams: bodyParameters, headerParams: headerParameters)
		}
		let queue = DispatchQueue(label: "com.networkbgthread.com",
								  qos: .background)

		queue.async {

			AF.request(finalURL)
				.responseJSON() { responseJSON in
				switch responseJSON.result {
				case .success(let json):
					let response = json as! NSDictionary
					switch statusCode {
						case 200, 201:
							DispatchQueue.main.async {
								success(responseJSON.data)
							}
						default:
							let message = response["message"] as? String ?? "\'message\' field absent"
							DispatchQueue.main.async {
								failure?(RequestError.init(message: message))
							}
					}
				case .failure(_):
					DispatchQueue.main.async {
						failure?(RequestError.init(message: responseJSON.error.debugDescription))
					}
				}
		}
    }
}

struct RequestError:Error {
	
	var message: String
	
	init(message: String) {
		self.message = message
	}
}
	
struct FontsResponse: Codable {
	
	var data: [FontModel]
}

struct FontModel: Codable {
	
	var id: Int
	var isDefault: Bool
	var name: String
	var thumbnail: String?
	
	enum CodingKeys: String, CodingKey {
		case id
		case isDefault
		case name
		case thumbnail = "thumb"
	}

}

/**
	
*/
open class GenericDecoder<IN, OUT: Codable> {
    public class func decode(_ inObject: IN, completion: @escaping((OUT?, String) -> ())) {
        fatalError("This method is empty please implement it on a subclass")
    }
}

 class GenericJSONDecoder<IN, OUT: Codable> : GenericDecoder<IN, OUT> {
    public override class func decode(_ inObject: IN, completion: @escaping((OUT?
        , String) -> ())) {
        do {
            let jsonDecoder = JSONDecoder()
			if let safeInObject = inObject as? Data {
				let response = try jsonDecoder.decode(OUT.self, from: safeInObject)
				completion(response, "")
			} else {
				completion(nil, "Input object is nil")
			}
        } catch DecodingError.dataCorrupted(let context) {
            print(context.debugDescription)
            completion(nil, context.debugDescription)
        } catch DecodingError.keyNotFound(let key, let context) {
            print("Key '\(key)' not Found")
            print("Debug Description:", context.debugDescription)
            completion(nil, context.debugDescription)
        } catch DecodingError.valueNotFound(let value, let context) {
            print("Value '\(value)' not Found")
            print("Debug Description:", context.debugDescription)
            completion(nil, context.debugDescription)
        } catch DecodingError.typeMismatch(let type, let context)  {
            print("Type '\(type)' mismatch")
            print("Debug Description:", context.debugDescription)
            completion(nil, context.debugDescription)
        } catch {
            print("error: ", error)
            completion(nil, "Unknown error")
        }
    }
}
enum Router: URLRequestConvertible {
    case get(url: URL, headerParams: [String : Any])
    case post(url: URL, bodyParams: [String: Any], headerParams: [String : Any])
	case patch(url: URL, bodyParams: [String: Any], headerParams: [String : Any])
	case delete(url: URL, bodyParams: [String: Any], headerParams: [String : Any])
    
    func asURLRequest() throws -> URLRequest {
        
        let bodyParams: ([String: Any]?) = {
            switch self {
			case .get:
				return nil
            case .post(_, let bodyParams, _):
                return (bodyParams)
			case .patch(_, let bodyParams, _):
				return (bodyParams)
			case .delete(_, let bodyParams, _):
				return (bodyParams)
			}
        }()
        
        let headerParams: ([String: Any]?) = {
            switch self {
			case .get(_, let headerParams):
				return (headerParams)
            case .post(_, _, let headerParams):
                return (headerParams)
			case .patch(_, _, let headerParams):
				return (headerParams)
			case .delete(_, _, let headerParams):
				return (headerParams)
			}
        }()

        let url: URL = {
            switch self {
            case .get(let url, _):
                return (url)
            case .post(let url, _, _):
                return (url)
			case .patch(let url, _, _):
				return (url)
			case .delete(let url, _, _):
				return (url)
			}
        }()
        
        let method: String = {
            switch self {
            case .get:
                return "GET"
            case .post:
                return "POST"
			case .patch:
				return "PATCH"
			case .delete:
				return "DELETE"
			}
        }()
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        for headerParam in headerParams! {
            urlRequest.setValue(headerParam.value as? String,
								forHTTPHeaderField: headerParam.key)
        }
        let encoding = JSONEncoding.default
        return try encoding.encode(urlRequest, with: bodyParams)
    }
}
