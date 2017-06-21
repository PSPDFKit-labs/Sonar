import Alamofire
import Foundation

class OpenRadar: BugTracker {
    private let manager: Alamofire.SessionManager

    init(token: String) {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["Authorization": token]

        self.manager = Alamofire.SessionManager(configuration: configuration)
    }

    /// Login into open radar. This is actually a NOP for now (token is saved into the session).
    ///
    /// - parameter getTwoFactorCode: A closure to retrieve a two factor auth code from the user
    /// - parameter closure:          A closure that will be called when the login is completed, on success it
    ///                               will contain a list of `Product`s; on failure a `SonarError`.
    func login(getTwoFactorCode: @escaping (_ closure: @escaping (_ code: String?) -> Void) -> Void,
               closure: @escaping (Result<Void, SonarError>) -> Void)
    {
        closure(.success())
    }

    /// Fetches an open radar item. Works without authentication.
    ///
    /// - parameter: rardarID: The ID for the radar.
    /// - parameter closure: A closure that will be called when the login is completed, on success it will
    ///                      contain the radar object; on failure a `SonarError`.
    func fetch(radarID: Int, closure: @escaping (Result<Radar, SonarError>) -> Void) {
        guard radarID > 0 else {
            closure(.failure(SonarError(message: "Invalid radar ID")))
            return
        }

        self.manager
            .request(OpenRadarRouter.read(radarID: radarID))
            .validate()
            .responseJSON { response in
                guard case .success = response.result else {
                    closure(.failure(SonarError.from(response)))
                    return
                }

                print(response)

                guard let JSON = try! response.result.unwrap() as? [String:Any],
                      let result = JSON["result"] as? [String:Any] else {
                        closure(.failure(SonarError(message: "Unable to parse JSON")))
                        return
                }

                let rawClassification = result["classification"] as? String ?? ""
                let classification = Classification.All.first(where: {
                    $0.name.lowercased() == rawClassification.lowercased()
                }) ?? Classification.Enhancement

                let rawReproducibility = result["reproducible"] as? String ?? ""
                let reproducibility = Reproducibility.All.first(where: {
                    return $0.name.lowercased() == rawReproducibility.lowercased()
                }) ?? Reproducibility.Always

                let rawProduct = result["product"] as? String ?? ""
                let product = Product.All.first(where: {
                    return $0.name.lowercased() == rawProduct.lowercased()
                }) ?? Product.iOS

                let title = result["title"] as? String ?? ""
                let productVersion = result["product_version"] as? String ?? ""

                // We try to restore the original structure and split up the string
                enum Structure : String {
                    case summary = "Summary:"
                    case steps = "Steps to Reproduce:"
                    case expectedResults = "Expected Results:"
                    case actualResults = "Actual Results:"
                    case observedResults = "Observed Results:" // alternative from Actual
                    case version = "Version:"
                    case notes = "Notes:"
                    case configuration = "Configuration:"
                    case nothing = ""
                }
                let description = result["description"] as? String ?? ""
                func StructureExtractor(_ beginStruct: Structure, _ endStruct: Structure) -> String? {
                    return description.match(pattern: "\(beginStruct.rawValue)(.*)\(endStruct.rawValue)", group: 1, options: [.dotMatchesLineSeparators])
                }
                let summary = StructureExtractor(.summary, .steps) ?? ""
                let steps = StructureExtractor(.steps, .expectedResults) ?? ""
                let expected = StructureExtractor(.expectedResults, .actualResults) ?? StructureExtractor(.expectedResults, .observedResults) ?? ""
                let actual = StructureExtractor(.actualResults, .version) ??  StructureExtractor(.observedResults, .version) ?? ""
                let configuration = StructureExtractor(.configuration, .nothing) ?? ""

                // if note extraction failed, just use full string
                // If there are no notes, add a space to allow submission
                var notes = StructureExtractor(.notes, .configuration) ?? StructureExtractor(.notes, .nothing) ?? description
                if notes.characters.count == 0 {
                    notes = " "
                }

                let radar = Radar(classification: classification, product: product, reproducibility: reproducibility, title: title, description: summary, steps: steps, expected: expected, actual: actual, configuration: configuration, version: productVersion, notes: notes, attachments: [])

                closure(.success(radar))
        }
    }

    /// Creates a new ticket into open radar (needs authentication first).
    ///
    /// - parameter radar:   The radar model with the information for the ticket.
    /// - parameter closure: A closure that will be called when the login is completed, on success it will
    ///                      contain a radar ID; on failure a `SonarError`.
    func create(radar: Radar, closure: @escaping (Result<Int, SonarError>) -> Void) {
        guard let ID = radar.ID else {
            closure(.failure(SonarError(message: "Invalid radar ID")))
            return
        }

        self.manager
            .request(OpenRadarRouter.create(radar: radar))
            .validate()
            .responseJSON { response in
                guard case .success = response.result else {
                    closure(.failure(SonarError.from(response)))
                    return
                }

                closure(.success(ID))
            }
    }
}
