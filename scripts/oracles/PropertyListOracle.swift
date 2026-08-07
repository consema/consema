// Consema's repository-owned Property List differential driver.
//
// Pinned Swift driver for the plist macOS differential oracle
// (docs/plist-implementation-plan.md M10 and 6.3;
// docs/rfcs/0013-plist-family-profiles-v1.md 13).
//
// The driver exercises Foundation `PropertyListSerialization` in both
// directions over the fixture set:
//   parse:  propertyList(from:options:format:)
//   write:  data(from:format:options:)
// for the format pair xml1 (PropertyListFormat.xml) and binary1
// (PropertyListFormat.binary), and reports lint validity, conversion
// outcomes with a reparse closure, and a deterministic typed value dump.
//
// Version-stability rule: only long-stable Foundation APIs are used
// (PropertyListSerialization, FileManager, ProcessInfo, Date). No
// modern-OS-only API and no async/await. The pinned macOS/Xcode/Swift
// toolchain versions are recorded in
// conformance/oracles/plist-macos-v1/manifest.json; the driver itself must
// compile and behave identically across the pinned toolchain family.
//
// Transport contract (ASCII TSV):
//   strings   -> lowercase UTF-8 hex
//   bytes     -> lowercase hex
//   real/date -> lowercase hex of the 64-bit IEEE 754 bit pattern
//   integers  -> signed decimal
// The value dump is deterministic: dictionary entries are sorted by their
// hex-encoded key, arrays keep source order (Foundation itself does not
// guarantee NSDictionary iteration order, so the driver must not rely on
// it). UIDs surface as an opaque CF object family; they are dumped from
// their description so identical values compare equal across legs.

import Foundation

// MARK: - Transport helpers

func hex(_ data: Data) -> String {
    return data.map { String(format: "%02x", $0) }.joined()
}

func hex(_ string: String) -> String {
    return hex(Data(string.utf8))
}

func bits(_ double: Double) -> String {
    return String(format: "%016llx", double.bitPattern)
}

func classify(_ error: Error) -> String {
    let ns = error as NSError
    return "\(ns.domain)\t\(ns.code)"
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(2)
}

// MARK: - Foundation access

func parsePlist(_ path: String) throws -> (Any, PropertyListSerialization.PropertyListFormat) {
    guard let source = FileManager.default.contents(atPath: path) else {
        throw NSError(domain: "consema.oracle",
                      code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "cannot read \(path)"])
    }
    var format = PropertyListSerialization.PropertyListFormat.openStep
    let value = try PropertyListSerialization.propertyList(from: source,
                                                           options: [],
                                                           format: &format)
    return (value, format)
}

func formatName(_ format: PropertyListSerialization.PropertyListFormat) -> String {
    switch format {
    case .xml: return "xml1"
    case .binary: return "binary1"
    case .openStep: return "openstep"
    @unknown default: return "unknown"
    }
}

// MARK: - Value dump

func dumpValue(_ value: Any, into lines: inout [String]) {
    if let string = value as? String {
        lines.append("v\tstring\t\(hex(string))")
    } else if let data = value as? Data {
        lines.append("v\tdata\t\(hex(data))")
    } else if let date = value as? Date {
        lines.append("v\tdate\t\(bits(date.timeIntervalSinceReferenceDate))")
    } else if let bool = value as? Bool {
        lines.append("v\tbool\t\(bool ? "true" : "false")")
    } else if let number = value as? NSNumber {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            lines.append("v\tbool\t\(number.boolValue ? "true" : "false")")
        } else if CFNumberIsFloatType(number) {
            lines.append("v\treal\t\(bits(number.doubleValue))")
        } else {
            lines.append("v\tinteger\t\(number.int64Value)")
        }
    } else if let array = value as? [Any] {
        lines.append("v\tarray\t\(array.count)")
        for element in array {
            dumpValue(element, into: &lines)
        }
    } else if let dict = value as? [String: Any] {
        lines.append("v\tdict\t\(dict.count)")
        for key in dict.keys.sorted() {
            lines.append("k\t\(hex(key))")
            if let element = dict[key] {
                dumpValue(element, into: &lines)
            }
        }
    } else {
        // UID values surface as an opaque CF object (the NSKeyedArchiverUID
        // family) that does not bridge to a public Swift type; dump the
        // description so identical values compare equal across legs.
        lines.append("v\tother\t\(hex(String(describing: value)))")
    }
}

// MARK: - Modes

func runRuntime() {
    print("os.version\t\(ProcessInfo.processInfo.operatingSystemVersionString)")
    print("corefoundation.version\t\(String(kCFCoreFoundationVersionNumber))")
}

func runLint(_ path: String) {
    do {
        let (_, format) = try parsePlist(path)
        print("lint\tok\t\(formatName(format))")
    } catch {
        print("lint\terror\t\(classify(error))")
    }
}

func runConvert(_ target: String, _ input: String, _ output: String) {
    guard let outFormat = target == "xml1"
        ? PropertyListSerialization.PropertyListFormat.xml
        : (target == "binary1" ? .binary : nil) else {
        fail("unknown target format: \(target)")
    }
    do {
        let (value, _) = try parsePlist(input)
        let data = try PropertyListSerialization.data(from: value,
                                                      format: outFormat,
                                                      options: [])
        try data.write(to: URL(fileURLWithPath: output))
        print("convert\tok\t\(formatName(outFormat))")
        var reparseFormat = PropertyListSerialization.PropertyListFormat.openStep
        _ = try PropertyListSerialization.propertyList(from: data,
                                                       options: [],
                                                       format: &reparseFormat)
        print("reparse\tok\t\(formatName(reparseFormat))")
    } catch {
        print("convert\terror\t\(classify(error))")
    }
}

func runValues(_ path: String) {
    do {
        let (value, _) = try parsePlist(path)
        var lines: [String] = []
        dumpValue(value, into: &lines)
        for line in lines {
            print(line)
        }
    } catch {
        print("values\terror\t\(classify(error))")
    }
}

// MARK: - Entry point

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data(("usage: PropertyListOracle --runtime | " +
        "lint <input> | convert <xml1|binary1> <input> <output> | values <input>\n").utf8))
    exit(2)
}

switch arguments[1] {
case "--runtime":
    runRuntime()
case "lint":
    guard arguments.count == 3 else { fail("lint requires <input>") }
    runLint(arguments[2])
case "convert":
    guard arguments.count == 5 else { fail("convert requires <xml1|binary1> <input> <output>") }
    runConvert(arguments[2], arguments[3], arguments[4])
case "values":
    guard arguments.count == 3 else { fail("values requires <input>") }
    runValues(arguments[2])
default:
    fail("unknown mode: \(arguments[1])")
}
