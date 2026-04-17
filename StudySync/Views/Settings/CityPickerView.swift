import SwiftUI

// MARK: - City Item

struct CityItem: Identifiable {
    var id: String { "\(timeZoneId)-\(englishName)" }
    let timeZoneId: String // e.g. "Asia/Shanghai"
    let cityName: String   // display name e.g. "上海"
    let regionName: String // e.g. "中国"
    let englishName: String // for search e.g. "Shanghai"

    init(id timeZoneId: String, cityName: String, regionName: String, englishName: String) {
        self.timeZoneId = timeZoneId
        self.cityName = cityName
        self.regionName = regionName
        self.englishName = englishName
    }
}

// MARK: - City Picker View

struct CityPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let title: String
    let onSelect: (String, String) -> Void  // (timeZoneId, cityName)

    @State private var searchText = ""
    @State private var selectedTimeZoneId: String?
    @State private var selectedCityName: String?

    private var isEnglish: Bool {
        locale.language.languageCode?.identifier == "en"
    }

    private var allCities: [CityItem] {
        CityDatabase.allCities
    }

    private var filteredCities: [CityItem] {
        if searchText.isEmpty { return allCities }
        let query = searchText.lowercased()
        return allCities.filter {
            $0.cityName.lowercased().contains(query) ||
            $0.englishName.lowercased().contains(query) ||
            $0.regionName.lowercased().contains(query)
        }
    }

    private var groupedCities: [(String, [CityItem])] {
        let grouped = Dictionary(grouping: filteredCities) { $0.regionName }
        let order = ["中国", "加拿大", "美国", "英国", "澳大利亚", "日本", "韩国", "东南亚", "新西兰", "欧洲", "中东", "南亚"]
        let englishRegions: [String: String] = [
            "中国": "China", "加拿大": "Canada", "美国": "USA", "英国": "UK",
            "澳大利亚": "Australia", "日本": "Japan", "韩国": "South Korea",
            "东南亚": "Southeast Asia", "新西兰": "New Zealand", "欧洲": "Europe",
            "中东": "Middle East", "南亚": "South Asia"
        ]
        return order.compactMap { region in
            guard let cities = grouped[region], !cities.isEmpty else { return nil }
            let displayRegion = isEnglish ? (englishRegions[region] ?? region) : region
            let sorted = cities.sorted {
                isEnglish ? $0.englishName < $1.englishName : $0.cityName < $1.cityName
            }
            return (displayRegion, sorted)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedCities, id: \.0) { region, cities in
                    Section(region) {
                        ForEach(cities) { city in
                            Button {
                                let displayName = isEnglish ? city.englishName : city.cityName
                                selectedTimeZoneId = city.timeZoneId
                                selectedCityName = displayName
                                onSelect(city.timeZoneId, displayName)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(isEnglish ? city.englishName : city.cityName)
                                            .font(.system(size: 16))
                                            .foregroundStyle(.primary)

                                        if city.cityName != city.englishName {
                                            Text(isEnglish ? city.cityName : city.englishName)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if let tz = TimeZone(identifier: city.timeZoneId) {
                                        let hours = Double(tz.secondsFromGMT()) / 3600.0
                                        let offsetStr: String = {
                                            if hours == hours.rounded() {
                                                return "UTC\(hours >= 0 ? "+" : "")\(Int(hours))"
                                            } else {
                                                let h = Int(hours.rounded(.towardZero))
                                                let m = Int(abs(hours.truncatingRemainder(dividingBy: 1)) * 60)
                                                return "UTC\(hours >= 0 ? "+" : "")\(h):\(String(format: "%02d", m))"
                                            }
                                        }()
                                        Text(offsetStr)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: L10n.searchCity)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
        }
    }
}

// MARK: - City Database

struct CityDatabase {
    static let allCities: [CityItem] = [
        // 🇨🇳 中国
        CityItem(id: "Asia/Shanghai", cityName: "上海", regionName: "中国", englishName: "Shanghai"),
        CityItem(id: "Asia/Shanghai", cityName: "北京", regionName: "中国", englishName: "Beijing"),
        CityItem(id: "Asia/Shanghai", cityName: "广州", regionName: "中国", englishName: "Guangzhou"),
        CityItem(id: "Asia/Shanghai", cityName: "深圳", regionName: "中国", englishName: "Shenzhen"),
        CityItem(id: "Asia/Shanghai", cityName: "成都", regionName: "中国", englishName: "Chengdu"),
        CityItem(id: "Asia/Shanghai", cityName: "杭州", regionName: "中国", englishName: "Hangzhou"),
        CityItem(id: "Asia/Shanghai", cityName: "南京", regionName: "中国", englishName: "Nanjing"),
        CityItem(id: "Asia/Shanghai", cityName: "武汉", regionName: "中国", englishName: "Wuhan"),
        CityItem(id: "Asia/Shanghai", cityName: "西安", regionName: "中国", englishName: "Xi'an"),
        CityItem(id: "Asia/Shanghai", cityName: "重庆", regionName: "中国", englishName: "Chongqing"),
        CityItem(id: "Asia/Shanghai", cityName: "天津", regionName: "中国", englishName: "Tianjin"),
        CityItem(id: "Asia/Shanghai", cityName: "长沙", regionName: "中国", englishName: "Changsha"),
        CityItem(id: "Asia/Shanghai", cityName: "苏州", regionName: "中国", englishName: "Suzhou"),
        CityItem(id: "Asia/Shanghai", cityName: "大连", regionName: "中国", englishName: "Dalian"),
        CityItem(id: "Asia/Shanghai", cityName: "厦门", regionName: "中国", englishName: "Xiamen"),
        CityItem(id: "Asia/Hong_Kong", cityName: "香港", regionName: "中国", englishName: "Hong Kong"),
        CityItem(id: "Asia/Macau", cityName: "澳门", regionName: "中国", englishName: "Macau"),
        CityItem(id: "Asia/Taipei", cityName: "台北", regionName: "中国", englishName: "Taipei"),

        // 🇨🇦 加拿大
        CityItem(id: "America/Toronto", cityName: "多伦多", regionName: "加拿大", englishName: "Toronto"),
        CityItem(id: "America/Vancouver", cityName: "温哥华", regionName: "加拿大", englishName: "Vancouver"),
        CityItem(id: "America/Montreal", cityName: "蒙特利尔", regionName: "加拿大", englishName: "Montreal"),
        CityItem(id: "America/Edmonton", cityName: "埃德蒙顿", regionName: "加拿大", englishName: "Edmonton"),
        CityItem(id: "America/Winnipeg", cityName: "温尼伯", regionName: "加拿大", englishName: "Winnipeg"),
        CityItem(id: "America/Halifax", cityName: "哈利法克斯", regionName: "加拿大", englishName: "Halifax"),
        CityItem(id: "America/Edmonton", cityName: "卡尔加里", regionName: "加拿大", englishName: "Calgary"),
        CityItem(id: "America/Vancouver", cityName: "维多利亚", regionName: "加拿大", englishName: "Victoria"),
        CityItem(id: "America/Toronto", cityName: "渥太华", regionName: "加拿大", englishName: "Ottawa"),

        // 🇺🇸 美国
        CityItem(id: "America/New_York", cityName: "纽约", regionName: "美国", englishName: "New York"),
        CityItem(id: "America/Los_Angeles", cityName: "洛杉矶", regionName: "美国", englishName: "Los Angeles"),
        CityItem(id: "America/Chicago", cityName: "芝加哥", regionName: "美国", englishName: "Chicago"),
        CityItem(id: "America/Los_Angeles", cityName: "旧金山", regionName: "美国", englishName: "San Francisco"),
        CityItem(id: "America/New_York", cityName: "波士顿", regionName: "美国", englishName: "Boston"),
        CityItem(id: "America/Los_Angeles", cityName: "西雅图", regionName: "美国", englishName: "Seattle"),
        CityItem(id: "America/New_York", cityName: "华盛顿", regionName: "美国", englishName: "Washington DC"),
        CityItem(id: "America/Chicago", cityName: "休斯顿", regionName: "美国", englishName: "Houston"),
        CityItem(id: "America/New_York", cityName: "费城", regionName: "美国", englishName: "Philadelphia"),
        CityItem(id: "America/New_York", cityName: "匹兹堡", regionName: "美国", englishName: "Pittsburgh"),
        CityItem(id: "America/Denver", cityName: "丹佛", regionName: "美国", englishName: "Denver"),
        CityItem(id: "America/Los_Angeles", cityName: "圣地亚哥", regionName: "美国", englishName: "San Diego"),
        CityItem(id: "Pacific/Honolulu", cityName: "檀香山", regionName: "美国", englishName: "Honolulu"),

        // 🇬🇧 英国
        CityItem(id: "Europe/London", cityName: "伦敦", regionName: "英国", englishName: "London"),
        CityItem(id: "Europe/London", cityName: "曼彻斯特", regionName: "英国", englishName: "Manchester"),
        CityItem(id: "Europe/London", cityName: "爱丁堡", regionName: "英国", englishName: "Edinburgh"),
        CityItem(id: "Europe/London", cityName: "伯明翰", regionName: "英国", englishName: "Birmingham"),
        CityItem(id: "Europe/London", cityName: "利兹", regionName: "英国", englishName: "Leeds"),
        CityItem(id: "Europe/London", cityName: "格拉斯哥", regionName: "英国", englishName: "Glasgow"),

        // 🇦🇺 澳大利亚
        CityItem(id: "Australia/Sydney", cityName: "悉尼", regionName: "澳大利亚", englishName: "Sydney"),
        CityItem(id: "Australia/Melbourne", cityName: "墨尔本", regionName: "澳大利亚", englishName: "Melbourne"),
        CityItem(id: "Australia/Brisbane", cityName: "布里斯班", regionName: "澳大利亚", englishName: "Brisbane"),
        CityItem(id: "Australia/Perth", cityName: "珀斯", regionName: "澳大利亚", englishName: "Perth"),
        CityItem(id: "Australia/Adelaide", cityName: "阿德莱德", regionName: "澳大利亚", englishName: "Adelaide"),
        CityItem(id: "Australia/Hobart", cityName: "霍巴特", regionName: "澳大利亚", englishName: "Hobart"),
        CityItem(id: "Australia/Darwin", cityName: "达尔文", regionName: "澳大利亚", englishName: "Darwin"),

        // 🇯🇵 日本
        CityItem(id: "Asia/Tokyo", cityName: "东京", regionName: "日本", englishName: "Tokyo"),
        CityItem(id: "Asia/Tokyo", cityName: "大阪", regionName: "日本", englishName: "Osaka"),
        CityItem(id: "Asia/Tokyo", cityName: "京都", regionName: "日本", englishName: "Kyoto"),
        CityItem(id: "Asia/Tokyo", cityName: "名古屋", regionName: "日本", englishName: "Nagoya"),

        // 🇰🇷 韩国
        CityItem(id: "Asia/Seoul", cityName: "首尔", regionName: "韩国", englishName: "Seoul"),
        CityItem(id: "Asia/Seoul", cityName: "釜山", regionName: "韩国", englishName: "Busan"),

        // 🇸🇬🇲🇾🇹🇭 东南亚
        CityItem(id: "Asia/Singapore", cityName: "新加坡", regionName: "东南亚", englishName: "Singapore"),
        CityItem(id: "Asia/Kuala_Lumpur", cityName: "吉隆坡", regionName: "东南亚", englishName: "Kuala Lumpur"),
        CityItem(id: "Asia/Bangkok", cityName: "曼谷", regionName: "东南亚", englishName: "Bangkok"),
        CityItem(id: "Asia/Manila", cityName: "马尼拉", regionName: "东南亚", englishName: "Manila"),
        CityItem(id: "Asia/Jakarta", cityName: "雅加达", regionName: "东南亚", englishName: "Jakarta"),
        CityItem(id: "Asia/Ho_Chi_Minh", cityName: "胡志明市", regionName: "东南亚", englishName: "Ho Chi Minh"),

        // 🇳🇿 新西兰
        CityItem(id: "Pacific/Auckland", cityName: "奥克兰", regionName: "新西兰", englishName: "Auckland"),
        CityItem(id: "Pacific/Auckland", cityName: "惠灵顿", regionName: "新西兰", englishName: "Wellington"),

        // 🇪🇺 欧洲其他
        CityItem(id: "Europe/Paris", cityName: "巴黎", regionName: "欧洲", englishName: "Paris"),
        CityItem(id: "Europe/Berlin", cityName: "柏林", regionName: "欧洲", englishName: "Berlin"),
        CityItem(id: "Europe/Amsterdam", cityName: "阿姆斯特丹", regionName: "欧洲", englishName: "Amsterdam"),
        CityItem(id: "Europe/Zurich", cityName: "苏黎世", regionName: "欧洲", englishName: "Zurich"),
        CityItem(id: "Europe/Rome", cityName: "罗马", regionName: "欧洲", englishName: "Rome"),
        CityItem(id: "Europe/Madrid", cityName: "马德里", regionName: "欧洲", englishName: "Madrid"),
        CityItem(id: "Europe/Dublin", cityName: "都柏林", regionName: "欧洲", englishName: "Dublin"),
        CityItem(id: "Europe/Vienna", cityName: "维也纳", regionName: "欧洲", englishName: "Vienna"),
        CityItem(id: "Europe/Stockholm", cityName: "斯德哥尔摩", regionName: "欧洲", englishName: "Stockholm"),
        CityItem(id: "Europe/Copenhagen", cityName: "哥本哈根", regionName: "欧洲", englishName: "Copenhagen"),
        CityItem(id: "Europe/Helsinki", cityName: "赫尔辛基", regionName: "欧洲", englishName: "Helsinki"),
        CityItem(id: "Europe/Moscow", cityName: "莫斯科", regionName: "欧洲", englishName: "Moscow"),
        CityItem(id: "Europe/Brussels", cityName: "布鲁塞尔", regionName: "欧洲", englishName: "Brussels"),
        CityItem(id: "Europe/Prague", cityName: "布拉格", regionName: "欧洲", englishName: "Prague"),
        CityItem(id: "Europe/Warsaw", cityName: "华沙", regionName: "欧洲", englishName: "Warsaw"),
        CityItem(id: "Europe/Lisbon", cityName: "里斯本", regionName: "欧洲", englishName: "Lisbon"),

        // 🇦🇪🇮🇳 其他
        CityItem(id: "Asia/Dubai", cityName: "迪拜", regionName: "中东", englishName: "Dubai"),
        CityItem(id: "Asia/Kolkata", cityName: "孟买", regionName: "南亚", englishName: "Mumbai"),
        CityItem(id: "Asia/Kolkata", cityName: "新德里", regionName: "南亚", englishName: "New Delhi"),
    ]
}

#Preview {
    CityPickerView(title: "选择城市") { _, _ in }
}
