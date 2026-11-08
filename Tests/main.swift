import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let songs = LibraryReader.load(root)
precondition(!songs.isEmpty, "Expected importable song packages")
precondition(Set(songs.map(\.id)).count == songs.count)
for song in songs {
 precondition(!song.notes.isEmpty && !song.lines.isEmpty)
 precondition(song.notes.allSatisfy { $0.end > $0.start && $0.start.isFinite && $0.end.isFinite })
 precondition(FileManager.default.fileExists(atPath: song.audio.path))
 precondition(song.lines.flatMap(\.notes).count == song.notes.count)
}
print("PASS: \(songs.count) local packages parsed")
