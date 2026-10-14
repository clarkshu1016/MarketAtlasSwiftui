import Testing
@testable import MarketAtlas

struct AIAvailabilityTests {
    @Test func mainlandStorefrontTurnsAIOff() {
        #expect(AIAvailability.isMainlandChina(storefront: "CHN", deviceRegion: "US"))
        #expect(AIAvailability.isMainlandChina(storefront: "chn", deviceRegion: nil))
    }

    @Test func mainlandDeviceRegionTurnsAIOffEvenWithAnotherStorefront() {
        #expect(AIAvailability.isMainlandChina(storefront: "USA", deviceRegion: "CN"))
        #expect(AIAvailability.isMainlandChina(storefront: nil, deviceRegion: "CN"))
    }

    @Test func otherRegionsKeepAI() {
        // Hong Kong, Macau and Taiwan are their own storefronts and regions.
        for region in ["HK", "MO", "TW", "SG", "JP", "US"] {
            #expect(!AIAvailability.isMainlandChina(storefront: nil, deviceRegion: region))
        }
        for storefront in ["HKG", "MAC", "TWN", "USA"] {
            #expect(!AIAvailability.isMainlandChina(storefront: storefront, deviceRegion: "US"))
        }
        #expect(!AIAvailability.isMainlandChina(storefront: nil, deviceRegion: nil))
    }
}
