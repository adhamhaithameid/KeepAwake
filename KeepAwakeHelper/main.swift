import Foundation

@main
struct KeepAwakeHelper {
    static func main() {
        RunLoop.main.run(until: Date())
    }
}
