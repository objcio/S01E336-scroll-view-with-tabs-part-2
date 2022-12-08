import SwiftUI

struct Item: Identifiable {
    var saturation: CGFloat = 0.8
    var hue = CGFloat.random(in: 0...1)
    var id = UUID()

    var color: Color {
        Color(hue: hue, saturation: saturation, brightness: 0.9)
    }
}
