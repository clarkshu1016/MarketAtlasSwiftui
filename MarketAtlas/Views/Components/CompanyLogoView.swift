import SwiftUI

struct CompanyLogoView: View {
    let company: Company
    var size: CGFloat = 40

    private var color: Color {
        let palette: [Color] = [.blue, .purple, .indigo, .teal, .orange, .pink, .cyan, .mint, .green]
        return palette[abs((company.ticker ?? company.name).hashValue) % palette.count]
    }

    private var initials: String {
        String((company.ticker ?? company.name).prefix(2)).uppercased()
    }

    var body: some View {
        Group {
            if let urlStr = company.logo_url, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit().padding(4)
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            color.opacity(0.18)
            Text(initials)
                .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        CompanyLogoView(company: .mockNVIDIA, size: 44)
        CompanyLogoView(company: .mockApple, size: 44)
        CompanyLogoView(company: .mockWalmart, size: 44)
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
