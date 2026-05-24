import Foundation

/// Pre-computed search tokens for one app. Built once at scan time so search
/// is just a few `String.contains` calls per keystroke.
struct SearchTokens: Hashable {
    /// Lowercased original name. Catches latin + Chinese exact substring.
    let nameLower: String
    /// e.g. "微信" → "wei xin". Lowercased, space-separated syllables.
    let pinyin: String
    /// Syllable initials, e.g. "微信" → "wx". Useful for short queries.
    let pinyinInitials: String

    static func build(from name: String) -> SearchTokens {
        let lower = name.lowercased()
        let py = Pinyin.transform(name)
        let initials = py
            .split(separator: " ")
            .compactMap { $0.first.map { String($0) } }
            .joined()
        return SearchTokens(nameLower: lower,
                            pinyin: py,
                            pinyinInitials: initials)
    }

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let q = query.lowercased()
        if nameLower.contains(q) { return true }
        if !pinyin.isEmpty, pinyin.contains(q) { return true }
        if !pinyinInitials.isEmpty, pinyinInitials.hasPrefix(q) { return true }
        return false
    }
}

/// Mandarin → latin pinyin using CoreFoundation's bundled transform table.
enum Pinyin {
    static func transform(_ source: String) -> String {
        guard source.unicodeScalars.contains(where: { $0.value > 0x7F }) else {
            // ASCII-only — no work to do; return lowercased original.
            return source.lowercased()
        }
        let mutable = NSMutableString(string: source) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false)
        return (mutable as String).lowercased()
    }
}
