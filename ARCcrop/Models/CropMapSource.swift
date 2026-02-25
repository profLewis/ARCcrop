import SwiftUI

enum GEOGLAMCrop: String, CaseIterable, Identifiable, Sendable {
    case winterWheat = "Winter Wheat"
    case springWheat = "Spring Wheat"
    case maize = "Maize"
    case soybean = "Soybean"
    case rice = "Rice"

    var id: String { rawValue }

    var filename: String {
        switch self {
        case .winterWheat: "GEOGLAM_WinterWheat"
        case .springWheat: "GEOGLAM_SpringWheat"
        case .maize: "GEOGLAM_Maize"
        case .soybean: "GEOGLAM_Soybean"
        case .rice: "GEOGLAM_Rice"
        }
    }

    var color: Color {
        switch self {
        case .winterWheat: .brown
        case .springWheat: .orange
        case .maize: .yellow
        case .soybean: .green
        case .rice: .cyan
        }
    }
}

enum CropMapSource: Hashable, Identifiable, Sendable {
    case none
    case geoglamCropPicture
    case geoglam(GEOGLAMCrop)
    case usdaCDL(year: Int)
    case worldCereal
    case dynamicWorld
    case gladCropland(year: Int)
    case copernicusLandCover
    case fromGLC
    case mapBiomas(year: Int)

    var id: String {
        switch self {
        case .none: "none"
        case .geoglamCropPicture: "geoglam_crop_picture"
        case .geoglam(let crop): "geoglam_\(crop.rawValue)"
        case .usdaCDL(let year): "usda_cdl_\(year)"
        case .worldCereal: "worldcereal"
        case .dynamicWorld: "dynamic_world"
        case .gladCropland(let year): "glad_\(year)"
        case .copernicusLandCover: "copernicus_lc"
        case .fromGLC: "from_glc"
        case .mapBiomas(let year): "mapbiomas_\(year)"
        }
    }

    var displayName: String {
        switch self {
        case .none: "None"
        case .geoglamCropPicture: "GEOGLAM Crop Picture (2022)"
        case .geoglam(let crop): "GEOGLAM \(crop.rawValue) (2022)"
        case .usdaCDL(let year): "USDA CDL (\(year))"
        case .worldCereal: "ESA WorldCereal (2021)"
        case .dynamicWorld: "Dynamic World (2024)"
        case .gladCropland(let year): "GLAD Cropland (\(year))"
        case .copernicusLandCover: "Copernicus Land Cover (2019)"
        case .fromGLC: "FROM-GLC (2020)"
        case .mapBiomas(let year): "MapBiomas (\(year))"
        }
    }

    var subtitle: String {
        switch self {
        case .none: ""
        case .geoglamCropPicture: "Embedded · RGB composite · Global"
        case .geoglam: "Embedded · 5.6km · Global"
        case .usdaCDL: "WMS · 30m · US only"
        case .worldCereal: "10m · Global · Requires GEE"
        case .dynamicWorld: "10m · Near-realtime · Requires GEE"
        case .gladCropland: "30m · Global"
        case .copernicusLandCover: "100m · Global · Requires Copernicus"
        case .fromGLC: "30m · Global · Requires GEE"
        case .mapBiomas: "30m · S. America · Requires GEE"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .none, .geoglamCropPicture, .geoglam, .usdaCDL, .gladCropland: false
        case .worldCereal, .dynamicWorld, .fromGLC, .mapBiomas: true
        case .copernicusLandCover: true
        }
    }

    var apiKeyProvider: APIKeyProvider? {
        switch self {
        case .worldCereal, .dynamicWorld, .fromGLC, .mapBiomas: .googleEarthEngine
        case .copernicusLandCover: .copernicus
        case .none, .geoglamCropPicture, .geoglam, .usdaCDL, .gladCropland: nil
        }
    }

    var isAvailable: Bool {
        switch self {
        case .none, .geoglamCropPicture, .geoglam, .usdaCDL, .gladCropland:
            return true
        default:
            guard let provider = apiKeyProvider else { return false }
            return KeychainService.hasKey(for: provider)
        }
    }

    static var allSources: [CropMapSource] {
        var sources: [CropMapSource] = [.none, .geoglamCropPicture]
        for crop in GEOGLAMCrop.allCases {
            sources.append(.geoglam(crop))
        }
        sources.append(contentsOf: [
            .usdaCDL(year: 2023),
            .worldCereal,
            .dynamicWorld,
            .gladCropland(year: 2020),
            .copernicusLandCover,
            .fromGLC,
            .mapBiomas(year: 2022),
        ])
        return sources
    }
}

enum APIKeyProvider: String, CaseIterable, Sendable {
    case googleEarthEngine = "Google Earth Engine"
    case copernicus = "Copernicus Data Space"

    var signupURL: String {
        switch self {
        case .googleEarthEngine: "https://console.cloud.google.com/apis/credentials"
        case .copernicus: "https://dataspace.copernicus.eu/profile"
        }
    }

    var registrationURL: String {
        switch self {
        case .googleEarthEngine: "https://code.earthengine.google.com/register"
        case .copernicus: "https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/registrations"
        }
    }

    var documentationURL: String {
        switch self {
        case .googleEarthEngine: "https://developers.google.com/earth-engine/guides/service_account"
        case .copernicus: "https://documentation.dataspace.copernicus.eu/APIs/OData.html"
        }
    }

    var instructions: String {
        switch self {
        case .googleEarthEngine: """
            1. [Register for Earth Engine](https://code.earthengine.google.com/register) (requires a Google account)

            2. Go to [Google Cloud Console](https://console.cloud.google.com)

            3. Create a new project (or select existing)

            4. Enable the "Earth Engine API": APIs & Services → Library → search "Earth Engine" → Enable

            5. Create a Service Account: APIs & Services → Credentials → Create Credentials → Service Account → name it → Done

            6. Create a key for the service account: Click the service account → Keys tab → Add Key → Create new key → JSON → Download the JSON file

            7. Copy the entire JSON content and paste it as your API key below
            """
        case .copernicus: """
            1. [Register at Copernicus Data Space](https://dataspace.copernicus.eu) (click "Register" in the top right)

            2. Verify your email and log in

            3. Go to your [profile page](https://dataspace.copernicus.eu/profile)

            4. Scroll to "API Key" or "Access Tokens"

            5. Generate a new access token

            6. Copy the token and paste it below

            Note: Tokens may expire. If data stops loading, generate a new token and update it here.
            """
        }
    }

    var registrationHint: String {
        switch self {
        case .googleEarthEngine:
            "You need a Google account. Earth Engine registration is free for research and non-commercial use."
        case .copernicus:
            "Registration is free. You will need to verify your email address before you can log in."
        }
    }

    var usedBy: String {
        switch self {
        case .googleEarthEngine: "Dynamic World, WorldCereal, FROM-GLC, MapBiomas"
        case .copernicus: "Copernicus Land Cover"
        }
    }
}
