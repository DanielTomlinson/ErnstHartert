import Commander
import Foundation
import PathKit

class StandardErrorOutputStream: OutputStreamType {
    func write(string: String) {
        fputs(string, stderr)
    }
}

var eh_stderr = StandardErrorOutputStream()
let tab = "    "

let main = command(Argument("input", description: "Path to the input directory")) { (input: Path) in
    let absoluteInput = input.absolute()

    guard absoluteInput.isDirectory else {
        print("`\(input)` is not a directory", toStream: &eh_stderr)
        exit(1)
    }

    var generatedCode = [String]()
    generatedCode += [
        "////////////////////////////////////",
        "// AUTO-GENERATED BY ERNSTHARTERT //",
        "////////////////////////////////////",
        "",
    ]

    generatedCode += [
        "import XCTest",
        "",
    ]

    var classNames = [String]()
    var hasWarning = false

    let files = absoluteInput.glob("Tests/*.swift").filter { $0.lastComponent != "main.swift" }
    for file in files {
        let contents: String = try! file.read()
        let fullRange = NSRange(0..<(contents as NSString).length)

        guard let classNameMatch = classNameDeclaration.firstMatchInString(contents, options: [], range: fullRange) else {
            print("\(file.absolute()):1: warning: No XCTestCase subclass found", toStream: &eh_stderr)
            exit(1)
        }

        let classNameRange = classNameMatch.rangeAtIndex(1)
        let className = (contents as NSString).substringWithRange(classNameRange)
        classNames.append(className)

        if let allTestsMatch = allTestsDeclaration.firstMatchInString(contents, options: [], range: fullRange) {
            let allTestsRange = allTestsMatch.rangeAtIndex(0)
            let allTestsLineRange = (contents as NSString).lineRangeForRange(allTestsRange)

            var lineNumber = 1
            var range = NSRange(0..<allTestsLineRange.location)
            while range.location < allTestsLineRange.location {
                range = (contents as NSString).lineRangeForRange(NSRange(location: range.location, length: 0))
                range.location = NSMaxRange(range)
                lineNumber += 1
            }

            hasWarning = true
            print("\(file.absolute()):\(lineNumber): warning: Class \"\(className)\" already has a \"var allTests\" declaration", toStream: &eh_stderr)
            continue
        }

        generatedCode += [
            "extension \(className) {",
            "\(tab)var allTests: [(String, () -> Void)] {",
            "\(tab)\(tab)return [",
        ]

        let matches = testFuncDeclaration.matchesInString(contents, options: [], range: fullRange)
        for match in matches {
            let range = match.rangeAtIndex(1)
            let subrange = (contents as NSString).substringWithRange(range)
            generatedCode.append("\(tab)\(tab)\(tab)(\"\(subrange)\", \(subrange)),")
        }

        generatedCode += [
            "\(tab)\(tab)]",
            "\(tab)}",
            "}",
            "",
        ]
    }

    guard !hasWarning else {
        exit(1)
    }

    generatedCode.append("XCTMain([")
    for className in classNames {
        generatedCode.append("\(tab)\(className)(),")
    }
    generatedCode.append("])")

    print(generatedCode.joinWithSeparator("\n"))
    exit(0)
}

main.run()
