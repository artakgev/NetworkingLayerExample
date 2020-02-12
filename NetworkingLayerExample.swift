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
		
		// Calling NetworkRequest's request function with GET method, 
		// url, 
		// headerParamaters (bodyParams in our case are empty)
		// success Block with response (FontResponse type object)
		self.networkRequest.request(method: "GET", 
					    with: url,
					    bodyParameters: [:],
					    headerParameters: headerParams,
					    success: { (response) in
						      // Here we should be sure that response is decodable, i.e.
						      // contains all necessary fields which are described in 
						      // FontsResponse class
						      // If response object is a type of FontsResponse, than
						      // we should get it's 'data' property which are actual fonts
						      // success(fonts) block will pass fonts to the caller
						      GenericJSONDecoder<Data?, FontsResponse>.decode(response, completion: { (reponseData, errorString) in
								guard let fontsResponseObject = reponseData else { return }
								let fonts = fontsResponseObject.data
								success(fonts)
							})
					   }) { (error) in
					       // If smth is wrong, than we are passing error with failure block
					       failure?(error)
		}	
	}
}

/**
This is just Defined values, for Integer it's -1
*/
struct DefinedValues {
	static let dummyIntValue = -1
}

/**
Class to declare some global variables.
In this case isProdServer variable
*/
final class GlobalVariables {
	static var isProdServer = true
}

/**
API structure
This structure used to operate with endpoints
*/
struct API {
	// constants which used to compose URL string
	static let scheme = "https"
	static let stageHost = "stagehost.company.com"
    	static let productionHost = "productionhost.company.com"
    	static let version = "v1"

    	// enum to represent endpoint,
	// currently there is only one value - fonts endpoint, can be also many
   	enum Endpoint: String {
		case fonts
        
       		// construct "fonts" endpoint. Should be "/api/v1/fonts"
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
    
	// Function to create URL based on provided endpoint and parameters
	// return - URL 
    	static func createURL(endPoint: Endpoint, params: [String: Any]) -> URL {
        	var urlComponent = URLComponents()
        	urlComponent.scheme = scheme // set "https" as a scheme
		urlComponent.host = GlobalVariables.isProdServer ? productionHost : stageHost // in our case it's "productionhost.company.com"
		urlComponent.path = endPoint.endpoint // path will be "/api/v1/fonts"
		let queryItems = self.createQueryItems(params: params)
		switch endPoint {
			case .fonts:
				urlComponent.queryItems = queryItems
			default:
				urlComponent.queryItems = []
		}
        	guard let url = urlComponent.url else { fatalError("Error with creation of url.") }
        	return url
    	}
    
	// Create header parameters based on provided endpoint
    	static func createHeaderParameters(endPoint: Endpoint) -> [String: String] {
        	switch endPoint {
        		case .fonts:
				// UserManager.currentUser.token is String vairable. 
			        // This variable stored in currentUser object of the UserManager class
				// Those classes are absent here, token should be initialized with another API call
			        // for example login API call which will return as a success result token string
            			return ["Authorization" : "Bearer " + UserManager.currentUser.token]
        		default:
            			return [:]
        	}
    	}
	
	// Create query items if there are params
	static func createQueryItems(params: [String: Any]) -> [URLQueryItem] {
		var queryItems = [URLQueryItem]()
		for param in params {
			queryItems.append(URLQueryItem(name: param.key, value: "\(param.value)"))
		}
		return queryItems
	}
}

// this is just third party framework import
import Alamofire

/**
NetworkRequest class is responsible to send requests
*/
class NetworkRequest {
	
    // Method for make requests with provided
    // method, url, body, header params, success and failure blocks
    func request(method: String,
		with url: URL,
                 bodyParameters: [String: Any],
                 headerParameters: [String: Any],
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
	
	 // Create background queue to run request on background thread, as AfNetworking will do it on main thread
	 // this may cause to screen freez
	let queue = DispatchQueue(label: "com.networkbgthread.com", qos: .background)
	queue.async {
		AF.request(finalURL)
			.responseJSON() { responseJSON in
			switch responseJSON.result {
				case .success(let json):
					let response = json as! NSDictionary
					switch statusCode {
						case 200, 201:
							// If everything is ok, than let's move to the main thread and
							// return result with success block
							DispatchQueue.main.async {
								success(responseJSON.data)
							}
						default:
							// If we are in the shit), than let's move to the main thread and
							// return error with failure block
							// As there can be case when response not contains "message" field
							// to show some detailed info, in this case to prevent 
						        // force unwrap scenario we will return "'message' field absent" value
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

// Class to represent error
// Can be extended functionality for example to
// identify error types based on some messages,
// or special function like valueOnUI() to return more user friendly error rather than 
// server's returned pure technical string
struct RequestError:Error {
	var message: String	
	init(message: String) {
		self.message = message
	}
}
	
// Object to represent response of our API call
// struct FontsRepsonse is Codable, this is cool feature in swift to
// automatically parse json response for requests.
// Name of the each member in Codable structure should be exactly the same like in response.
// If there are exceptions, than we should use
// enum CodingKeys: String, CodingKey {
//		case memberName = "value_from_request"
//}
// In our case response JSON is
/** {
	"data" : [
		{
		"id": 2,
		"isDefault": true,
		"name": "FontName",
		"thumbnailImagePath": "http://www.google.com/abc/image.png"
		}
		{
		"id": 2,
		"isDefault": true,
		"name": "FontName"
		}
	]
}
 As you can see thumbnailImagePath is absent from second font, 
	that's why thumbnailImagePath is marked as an optional with ? sign
*/
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
		case thumbnail = "thumbnailImagePath"
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
