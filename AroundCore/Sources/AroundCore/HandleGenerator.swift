import Foundation

/// Generates anonymous-but-memorable default handles like "amber-fox-42".
public enum HandleGenerator {
    static let adjectives = [
        "amber", "brisk", "cobalt", "dusty", "ember", "frosty", "golden",
        "hazel", "indigo", "jade", "keen", "lunar", "mellow", "nimble",
        "olive", "plucky", "quiet", "rusty", "scarlet", "tidal", "umber",
        "velvet", "wandering", "zesty",
    ]

    static let animals = [
        "fox", "otter", "heron", "lynx", "badger", "swift", "raven",
        "newt", "ibis", "marten", "puffin", "stoat", "wren", "gecko",
        "orca", "bison", "crane", "dingo", "eagle", "ferret",
    ]

    public static func random(using generator: inout some RandomNumberGenerator) -> String {
        let adjective = adjectives.randomElement(using: &generator)!
        let animal = animals.randomElement(using: &generator)!
        let number = Int.random(in: 1...99, using: &generator)
        return "\(adjective)-\(animal)-\(number)"
    }

    public static func random() -> String {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }
}
