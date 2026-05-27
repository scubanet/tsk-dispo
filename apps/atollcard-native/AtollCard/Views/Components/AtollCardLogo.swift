import SwiftUI

struct AtollCardLogo: View {
    var size: CGFloat

    init(size: CGFloat = 48) {
        self.size = size
    }

    var body: some View {
        Image("AtollCardLogo")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 20) {
        AtollCardLogo(size: 32)
        AtollCardLogo(size: 64)
        AtollCardLogo(size: 128)
    }
    .padding()
}
