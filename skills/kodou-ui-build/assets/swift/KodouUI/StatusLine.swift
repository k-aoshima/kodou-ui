import SwiftUI

/// 画面の下の帯。左にモード（青の面、右を矢じりの形に切る）、続けて一言、右にキーの案内
public struct KodouStatusLine: View {
    let mode: String
    let message: String
    let keys: [(String, String)]
    public init(mode: String, message: String, keys: [(String, String)] = []) { self.mode = mode; self.message = message; self.keys = keys }
    public var body: some View {
        HStack(spacing: 0) {
            Text(mode).font(.kdMono(13, weight: .bold)).foregroundStyle(KD.panel)
                .padding(.horizontal, 10).frame(maxHeight: .infinity).background(KD.blue)
                .overlay(alignment: .trailing) { Arrow().fill(KD.blue).frame(width: 10).offset(x: 10) }
                .padding(.trailing, 10)
            Text(message).font(.kdRead(13)).foregroundStyle(KD.dim).lineLimit(1).truncationMode(.tail).padding(.horizontal, 10)
            Spacer(minLength: 8)
            ForEach(Array(keys.enumerated()), id: \.offset) { _, k in
                HStack(spacing: 4) { KodouKey(k.0); Text(k.1).foregroundStyle(KD.dim) }
                    .font(.kdMono(12)).padding(.horizontal, 10).frame(maxHeight: .infinity)
                    .overlay(alignment: .leading) { Rectangle().fill(KD.ruleSoft).frame(width: 1) }
            }
        }
        .frame(height: 26)
        .background(KD.panel)
        .overlay(alignment: .top) { Rectangle().fill(KD.rule).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
    struct Arrow: Shape {
        func path(in r: CGRect) -> Path { Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: r.width, y: r.midY)); p.addLine(to: CGPoint(x: 0, y: r.height)); p.closeSubpath() } }
    }
}
