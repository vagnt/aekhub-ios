import SwiftUI

struct SavedView: View {
    @ObservedObject var p = Prefs.shared
    var body: some View {
        ScrollView {
            if p.saved.isEmpty { EmptyState(icon: "bookmark", text: "Δεν έχεις αποθηκεύσει άρθρα.\nΠάτα 🔖 πάνω σε ένα άρθρο για να το κρατήσεις εδώ.") }
            LazyVGrid(columns: adaptiveCols, spacing: 0) {
                ForEach(p.saved) { a in
                    PostRow(p: a).contextMenu { Button(role: .destructive) { p.toggleSaved(a) } label: { Label("Αφαίρεση", systemImage: "trash") } }
                }
            }
        }
        .background(C.ink)
        .navigationTitle("Αποθηκευμένα")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Άνοιγμα της εφαρμογής (όπως στο Android): το λογότυπο «χτίζεται» κομμάτι-κομμάτι —
/// a από αριστερά, e από πάνω, ο κύκλος hub γυρίζει και «σκάει», το K από δεξιά — ένας παλμός και σβήνει (~1,6″).
struct IntroSplash: View {
    var done: () -> Void
    @State private var box = 0.0
    @State private var a = 0.0
    @State private var e = 0.0
    @State private var hub = 0.0
    @State private var k = 0.0
    @State private var pulse = 1.0
    @State private var out = 0.0

    var body: some View {
        ZStack {
            C.ink.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    piece("intro_a").opacity(a).offset(x: -46 * (1 - a))
                    piece("intro_e").opacity(e).offset(y: -46 * (1 - e))
                }
                HStack(spacing: 0) {
                    piece("intro_hub").opacity(min(1, hub)).scaleEffect(hub).rotationEffect(.degrees(-200 * (1 - hub)))
                    piece("intro_k").opacity(k).offset(x: 46 * (1 - k))
                }
            }
            .frame(width: 220, height: 220)
            .background(RoundedRectangle(cornerRadius: 48, style: .continuous).fill(.black))
            .scaleEffect((0.86 + 0.14 * box) * pulse * (1 + 0.25 * out))
            .opacity(box)
        }
        .opacity(1 - out)
        .task {
            withAnimation(.easeOut(duration: 0.28)) { box = 1 }
            withAnimation(.easeInOut(duration: 0.36).delay(0.12)) { a = 1 }
            withAnimation(.easeInOut(duration: 0.36).delay(0.23)) { e = 1 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.45).delay(0.34)) { hub = 1 }
            withAnimation(.easeInOut(duration: 0.36).delay(0.45)) { k = 1 }
            try? await Task.sleep(nanoseconds: 950_000_000)
            haptic(.soft)
            withAnimation(.easeOut(duration: 0.14)) { pulse = 1.07 }
            try? await Task.sleep(nanoseconds: 140_000_000)
            withAnimation(.easeOut(duration: 0.18)) { pulse = 1 }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.easeInOut(duration: 0.3)) { out = 1 }
            try? await Task.sleep(nanoseconds: 300_000_000)
            done()
        }
    }
    func piece(_ n: String) -> some View { Image(n).resizable().scaledToFit().frame(width: 110, height: 110) }
}
