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

// MARK: - Credential type

enum CredentialType: Sendable {
    case apiKey                   // Single key/token
    case usernamePassword         // Username + password pair
    case none                     // No credentials needed
}

// MARK: - API Key Providers

enum APIKeyProvider: String, CaseIterable, Sendable {
    case googleEarthEngine = "Google Earth Engine"
    case copernicus = "Copernicus Data Space"
    case planetaryComputer = "Planetary Computer"
    case nasaEarthdata = "NASA Earthdata"
    case aws = "AWS (Element84)"

    var credentialType: CredentialType {
        switch self {
        case .googleEarthEngine: .apiKey
        case .copernicus: .usernamePassword
        case .planetaryComputer: .apiKey
        case .nasaEarthdata: .usernamePassword
        case .aws: .none
        }
    }

    /// Keychain keys used by this provider (matches eof-ios conventions)
    var credentialKeys: [String] {
        switch self {
        case .googleEarthEngine: ["gee.serviceaccount"]
        case .copernicus: ["cdse.username", "cdse.password"]
        case .planetaryComputer: ["planetary.apikey"]
        case .nasaEarthdata: ["earthdata.username", "earthdata.password"]
        case .aws: []
        }
    }

    var signupURL: String {
        switch self {
        case .googleEarthEngine: "https://console.cloud.google.com/apis/credentials"
        case .copernicus: "https://documentation.dataspace.copernicus.eu/APIs/Token.html"
        case .planetaryComputer: "https://planetarycomputer.microsoft.com/account/request"
        case .nasaEarthdata: "https://urs.earthdata.nasa.gov/profile"
        case .aws: "https://earth-search.aws.element84.com/v1"
        }
    }

    var registrationURL: String {
        switch self {
        case .googleEarthEngine: "https://code.earthengine.google.com/register"
        case .copernicus: "https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/auth?client_id=cdse-public&response_type=code&scope=openid&redirect_uri=https%3A//dataspace.copernicus.eu/account/confirmed/1883"
        case .planetaryComputer: "https://planetarycomputer.microsoft.com"
        case .nasaEarthdata: "https://urs.earthdata.nasa.gov/users/new"
        case .aws: "https://earth-search.aws.element84.com/v1"
        }
    }

    var documentationURL: String {
        switch self {
        case .googleEarthEngine: "https://developers.google.com/earth-engine/guides/service_account"
        case .copernicus: "https://documentation.dataspace.copernicus.eu/APIs/OData.html"
        case .planetaryComputer: "https://planetarycomputer.microsoft.com/docs/quickstarts/reading-stac/"
        case .nasaEarthdata: "https://www.earthdata.nasa.gov/learn/get-started"
        case .aws: "https://stacindex.org/catalogs/earth-search"
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
            1. [Register at Copernicus Data Space](https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/auth?client_id=cdse-public&response_type=code&scope=openid&redirect_uri=https%3A//dataspace.copernicus.eu/account/confirmed/1883) — click "Register" on the login page

            2. Fill in the form, accept terms, and click Register

            3. Check your email and click "Verify email address"

            4. Enter your CDSE username (email) and password below — the app will generate access tokens automatically when needed

            See [Token documentation](https://documentation.dataspace.copernicus.eu/APIs/Token.html) for details.
            """
        case .planetaryComputer: """
            1. Go to [Planetary Computer](https://planetarycomputer.microsoft.com) and sign in with a Microsoft account

            2. [Request access](https://planetarycomputer.microsoft.com/account/request) if you haven't already (approval is usually immediate)

            3. An API key is **optional** — public data (Sentinel-2, Landsat) works without one, but a key gives higher rate limits

            4. If you have a subscription key, find it in your [Azure portal](https://portal.azure.com) under API Management → Subscriptions

            5. Paste the key below (or leave blank for public access)
            """
        case .nasaEarthdata: """
            1. [Create an Earthdata account](https://urs.earthdata.nasa.gov/users/new) — registration is free

            2. After registering, go to your [profile](https://urs.earthdata.nasa.gov/profile) and note your username

            3. Enter your Earthdata username and password below — the app will generate bearer tokens automatically

            Required for: HLS (Harmonized Landsat Sentinel-2), MODIS, VIIRS, and other NASA LP DAAC products
            """
        case .aws: """
            No credentials are needed. AWS Earth Search (Element84) provides free public access to Sentinel-2 L2A, Landsat, and other collections via STAC.

            Data endpoint: [earth-search.aws.element84.com/v1](https://earth-search.aws.element84.com/v1)
            """
        }
    }

    var registrationHint: String {
        switch self {
        case .googleEarthEngine:
            "You need a Google account. Earth Engine registration is free for research and non-commercial use."
        case .copernicus:
            "Registration is free. Click the avatar icon in the top right, then tap Register."
        case .planetaryComputer:
            "Sign in with any Microsoft account. API key is optional for public datasets."
        case .nasaEarthdata:
            "Registration is free. You will need a username and password."
        case .aws:
            "No registration required. Public access to Sentinel-2, Landsat, and more."
        }
    }

    var usedBy: String {
        switch self {
        case .googleEarthEngine: "Dynamic World, WorldCereal, FROM-GLC, MapBiomas"
        case .copernicus: "Copernicus Land Cover, Sentinel-2 (CDSE)"
        case .planetaryComputer: "Sentinel-2, Landsat (Planetary Computer)"
        case .nasaEarthdata: "HLS, MODIS, VIIRS (NASA LP DAAC)"
        case .aws: "Sentinel-2, Landsat (Element84 Earth Search)"
        }
    }
}
