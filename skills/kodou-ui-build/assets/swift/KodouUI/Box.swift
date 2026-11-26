import SwiftUI

/// 罫線の枠。題は枠の上の線に載せる（Web の .box と .ttl）
public struct KodouBox<Content: View>: View {
    let title: String
    let content: Content
    let padding: EdgeInsets
    /// padding は中身の余白。既定は Web の .box-in と同じ（上 16、左右 14、下 12）
    public init(_ title: String, padding: EdgeInsets = .init(top: 16, leading: 14, bottom: 12, trailing: 14), @ViewBuilder content: () -> Content) {
        self.title = title; self.padding = padding; self.content = content()
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(KD.panel)
            .overlay(Rectangle().strokeBorder(KD.rule, lineWidth: 1))
            .overlay(alignment: .topLeading) {
                Text(title).font(.kdMono(12)).foregroundStyle(KD.dim).lineLimit(1)
                    .padding(.horizontal, 6).background(KD.panel)
                    .offset(x: 10, y: -9)
                    .accessibilityAddTraits(.isHeader)
            }
    }
}
