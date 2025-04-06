import Foundation

open class Analyzer {
    
    public enum ANSI {
        public static let reset  = "\u{001B}[0m"
        public static let white  = "\u{001B}[0;37m"
        public static let yellow = "\u{001B}[0;33m"
        public static let green  = "\u{001B}[0;32m"
        public static let blue   = "\u{001B}[0;34m"
        public static let red    = "\u{001B}[0;31m"
        public static let cyan   = "\u{001B}[0;36m"
    }
    
    public init() {}
    
    // Helper methods could go here if needed
}
