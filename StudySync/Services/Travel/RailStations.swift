import Foundation

/// Station database for high-speed rail (mainland China).
/// Used by the manual entry form to auto-complete station names + time zones.
/// Covers the top ~60 HSR hubs — enough for most student routes.
///
/// Adding more: Each entry is (Chinese name, English name, station code, city).
/// All mainland-China stations share `Asia/Shanghai` timezone.
enum RailStations {
    struct Station: Hashable, Identifiable {
        let nameZh: String
        let nameEn: String
        let code: String
        let city: String
        let timeZoneID: String = "Asia/Shanghai"
        var id: String { code }
    }

    /// Primary HSR / rail hubs. Sorted roughly by traffic.
    static let all: [Station] = [
        // Beijing
        .init(nameZh: "北京南", nameEn: "Beijing South", code: "VNP", city: "北京"),
        .init(nameZh: "北京西", nameEn: "Beijing West", code: "BXP", city: "北京"),
        .init(nameZh: "北京", nameEn: "Beijing", code: "BJP", city: "北京"),
        .init(nameZh: "北京朝阳", nameEn: "Beijing Chaoyang", code: "CYF", city: "北京"),
        .init(nameZh: "北京丰台", nameEn: "Beijing Fengtai", code: "FTP", city: "北京"),

        // Shanghai
        .init(nameZh: "上海虹桥", nameEn: "Shanghai Hongqiao", code: "AOH", city: "上海"),
        .init(nameZh: "上海", nameEn: "Shanghai", code: "SHH", city: "上海"),
        .init(nameZh: "上海南", nameEn: "Shanghai South", code: "SNH", city: "上海"),

        // Guangdong cluster
        .init(nameZh: "广州南", nameEn: "Guangzhou South", code: "IZQ", city: "广州"),
        .init(nameZh: "广州", nameEn: "Guangzhou", code: "GZQ", city: "广州"),
        .init(nameZh: "深圳北", nameEn: "Shenzhen North", code: "IOQ", city: "深圳"),
        .init(nameZh: "深圳", nameEn: "Shenzhen", code: "SZQ", city: "深圳"),
        .init(nameZh: "香港西九龙", nameEn: "Hong Kong West Kowloon", code: "XJA", city: "香港"),

        // Yangtze River Delta
        .init(nameZh: "杭州东", nameEn: "Hangzhou East", code: "HGH", city: "杭州"),
        .init(nameZh: "杭州", nameEn: "Hangzhou", code: "HZH", city: "杭州"),
        .init(nameZh: "南京南", nameEn: "Nanjing South", code: "NJH", city: "南京"),
        .init(nameZh: "南京", nameEn: "Nanjing", code: "NJH", city: "南京"),
        .init(nameZh: "苏州", nameEn: "Suzhou", code: "SZH", city: "苏州"),
        .init(nameZh: "无锡", nameEn: "Wuxi", code: "WXH", city: "无锡"),

        // Major interior hubs
        .init(nameZh: "武汉", nameEn: "Wuhan", code: "WHN", city: "武汉"),
        .init(nameZh: "长沙南", nameEn: "Changsha South", code: "CWQ", city: "长沙"),
        .init(nameZh: "成都东", nameEn: "Chengdu East", code: "ICW", city: "成都"),
        .init(nameZh: "成都", nameEn: "Chengdu", code: "CDW", city: "成都"),
        .init(nameZh: "重庆北", nameEn: "Chongqing North", code: "CUW", city: "重庆"),
        .init(nameZh: "西安北", nameEn: "Xi'an North", code: "EAY", city: "西安"),
        .init(nameZh: "西安", nameEn: "Xi'an", code: "XAY", city: "西安"),

        // Northeast
        .init(nameZh: "哈尔滨西", nameEn: "Harbin West", code: "VAB", city: "哈尔滨"),
        .init(nameZh: "长春", nameEn: "Changchun", code: "CCT", city: "长春"),
        .init(nameZh: "沈阳北", nameEn: "Shenyang North", code: "SBT", city: "沈阳"),
        .init(nameZh: "大连北", nameEn: "Dalian North", code: "DFT", city: "大连"),

        // Tianjin / Hebei
        .init(nameZh: "天津", nameEn: "Tianjin", code: "TJP", city: "天津"),
        .init(nameZh: "天津西", nameEn: "Tianjin West", code: "TXP", city: "天津"),
        .init(nameZh: "石家庄", nameEn: "Shijiazhuang", code: "SJP", city: "石家庄"),

        // Shandong
        .init(nameZh: "济南西", nameEn: "Jinan West", code: "JGK", city: "济南"),
        .init(nameZh: "济南", nameEn: "Jinan", code: "JNK", city: "济南"),
        .init(nameZh: "青岛", nameEn: "Qingdao", code: "QDK", city: "青岛"),
        .init(nameZh: "青岛北", nameEn: "Qingdao North", code: "QHK", city: "青岛"),

        // Southwest
        .init(nameZh: "昆明南", nameEn: "Kunming South", code: "KOM", city: "昆明"),
        .init(nameZh: "昆明", nameEn: "Kunming", code: "KMM", city: "昆明"),
        .init(nameZh: "贵阳北", nameEn: "Guiyang North", code: "KQW", city: "贵阳"),

        // Central
        .init(nameZh: "郑州东", nameEn: "Zhengzhou East", code: "ZAF", city: "郑州"),
        .init(nameZh: "郑州", nameEn: "Zhengzhou", code: "ZZF", city: "郑州"),
        .init(nameZh: "合肥南", nameEn: "Hefei South", code: "EFH", city: "合肥"),
        .init(nameZh: "合肥", nameEn: "Hefei", code: "HFH", city: "合肥"),

        // Southeast
        .init(nameZh: "福州", nameEn: "Fuzhou", code: "FZS", city: "福州"),
        .init(nameZh: "厦门北", nameEn: "Xiamen North", code: "XKS", city: "厦门"),
        .init(nameZh: "厦门", nameEn: "Xiamen", code: "XMS", city: "厦门"),
        .init(nameZh: "南昌西", nameEn: "Nanchang West", code: "NXG", city: "南昌"),
        .init(nameZh: "南昌", nameEn: "Nanchang", code: "NCG", city: "南昌"),

        // West
        .init(nameZh: "兰州西", nameEn: "Lanzhou West", code: "LAJ", city: "兰州"),
        .init(nameZh: "兰州", nameEn: "Lanzhou", code: "LZJ", city: "兰州"),
        .init(nameZh: "乌鲁木齐", nameEn: "Urumqi", code: "WMR", city: "乌鲁木齐"),

        // Inner Mongolia / Ningxia
        .init(nameZh: "呼和浩特东", nameEn: "Hohhot East", code: "NDC", city: "呼和浩特"),
        .init(nameZh: "银川", nameEn: "Yinchuan", code: "YIJ", city: "银川"),

        // Southwest extended
        .init(nameZh: "南宁东", nameEn: "Nanning East", code: "NFZ", city: "南宁"),
        .init(nameZh: "桂林北", nameEn: "Guilin North", code: "GBZ", city: "桂林"),

        // Hainan
        .init(nameZh: "海口", nameEn: "Haikou", code: "VUQ", city: "海口"),
        .init(nameZh: "三亚", nameEn: "Sanya", code: "SEQ", city: "三亚"),

        // Tibet / Qinghai
        .init(nameZh: "拉萨", nameEn: "Lhasa", code: "LSO", city: "拉萨"),
        .init(nameZh: "西宁", nameEn: "Xining", code: "XNO", city: "西宁"),
    ]

    /// Case-insensitive fuzzy search across Chinese name, English name, or code.
    static func search(_ query: String) -> [Station] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        let lower = q.lowercased()
        return all.filter {
            $0.nameZh.contains(q)
                || $0.nameEn.lowercased().contains(lower)
                || $0.code.lowercased().contains(lower)
                || $0.city.contains(q)
        }
    }

    static func station(withCode code: String) -> Station? {
        all.first { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }
}
