//
//  AddImportOperation.swift
//  Import
//
//  Created by Marko Hlebar on 05/10/2016.
//  Copyright © 2016 Marko Hlebar. All rights reserved.
//

import XcodeKit

fileprivate struct AddImportOperationRegex {
    
    static let objcImport = ".*#.*(import|include).*[\",<].*[\",>]"
    static let objcModuleImport = ".*@.*(import).*.;"
    static let swiftModuleImport = ".*(import) +.*."
}

class AddImportOperation {

    let buffer: XCSourceTextBuffer
    
    lazy var importRegex = try! NSRegularExpression(pattern: AddImportOperationRegex.objcImport, options: NSRegularExpression.Options(rawValue: UInt(0)))
    lazy var moduleImportRegex = try! NSRegularExpression(pattern: AddImportOperationRegex.objcModuleImport, options: NSRegularExpression.Options(rawValue: UInt(0)))
    lazy var swiftModuleImportRegex = try! NSRegularExpression(pattern: AddImportOperationRegex.swiftModuleImport, options: NSRegularExpression.Options(rawValue: UInt(0)))

    init(with buffer:XCSourceTextBuffer) {
        self.buffer = buffer
    }
    
    func execute() {
        let selection = self.buffer.selections.firstObject as! XCSourceTextRange
        var selectionLine = selection.start.line
        
        var importString = (self.buffer.lines[selectionLine] as! String).trimmingCharacters(in: CharacterSet.whitespaces)
        importString = importString.trimmingCharacters(in: CharacterSet.init(charactersIn: " \t\n"))
        
        guard isValid(importString: importString) else {
            return
        }
        
        //remove duplicate imports
        let removeNum = removeDuplicate(importString: importString)
        selectionLine = selectionLine-removeNum
        
        let line = appropriateLine()
        guard line != NSNotFound else {
            return
        }
        
        self.buffer.lines.insert(importString, at: line)
        
        //add a new selection. Bug fix for #7
        let selectionPosition = XCSourceTextRange.init(start: XCSourceTextPosition.init(line: selectionLine, column: 0), end: XCSourceTextPosition.init(line: selectionLine, column: 0))
        self.buffer.selections.removeAllObjects()
        self.buffer.selections.insert(selectionPosition, at: 0)
    }
    
    func removeDuplicate(importString: String) -> Int {
        
        //do not forget itself
        var lineNumber = -1;
        
        let tempLines = NSMutableArray.init(array: buffer.lines)
        tempLines.enumerateObjects(options: .reverse) { (line, index, stop) in
            let string = (line as! String).trimmingCharacters(in: CharacterSet.init(charactersIn: " \t\n"))
            if string == importString {
                buffer.lines.removeObject(at: index)
                lineNumber += 1
            }
        }
        
        return lineNumber
    }
    
    func isValid(importString: String) -> Bool {
        var numberOfMatches = 0
        let matchingOptions = NSRegularExpression.MatchingOptions(rawValue: UInt(0))
        let range = NSMakeRange(0, importString.characters.count)
        
        if buffer.isSwiftSource {
            numberOfMatches = swiftModuleImportRegex.numberOfMatches(in: importString, options: matchingOptions, range: range)
        }
        else {
            numberOfMatches = importRegex.numberOfMatches(in: importString, options: matchingOptions, range: range)
            numberOfMatches = numberOfMatches > 0 ? numberOfMatches : moduleImportRegex.numberOfMatches(in: importString, options: matchingOptions, range: range)
        }
        
        return numberOfMatches > 0
    }
    
    func appropriateLine() -> Int {
        var lineNumber = NSNotFound
        let lines = buffer.lines as NSArray as! [String]
        
        //Find the line that is first after all the imports
        for (index, line) in lines.enumerated() {
            
            if isValid(importString: line) {
                lineNumber = index
            }
        }
        
        guard lineNumber == NSNotFound else {
            return lineNumber + 1
        }
        
        //if a line is not found, find first free line after comments
        for (index, line) in lines.enumerated() {
            lineNumber = index
            if line.isWhitespaceOrNewline() {
                break
            }
        }
        
        return lineNumber + 1
    }
}

fileprivate extension XCSourceTextBuffer {
    
    var isSwiftSource: Bool {
        return self.contentUTI == "public.swift-source"
    }
}

fileprivate extension String {
    
    func isWhitespaceOrNewline() -> Bool {
        let string = self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return string.characters.count == 0
        
    }
}
