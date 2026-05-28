import SwiftUI

struct ProGateView: View {
    let feature: String
    var onUpgrade: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.forgeOrange)
            Text("Forge Pro")
                .font(.title2).bold()
                .foregroundStyle(.white)
            Text("\(feature) is a Forge Pro feature.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button("Upgrade to Pro") {
                onUpgrade()
            }
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.forgeOrange)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("pro_upgrade_button")
        }
        .padding(24)
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(24)
    }
}

#Preview {
    ZStack {
        Color.forgeDark.ignoresSafeArea()
        ProGateView(feature: "Full history")
    }
}
