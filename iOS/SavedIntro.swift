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

/// Οθόνη υποδοχής (πρώτο άνοιγμα)
struct IntroView: View {
    var done: () -> Void
    @State private var page = 0
    var body: some View {
        ZStack {
            C.ink.ignoresSafeArea()
            Image("HeroBg").resizable().scaledToFill().opacity(0.25).ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                Image("HubLogo").resizable().scaledToFit().frame(width: 110, height: 110).clipShape(RoundedRectangle(cornerRadius: 24))
                TabView(selection: $page) {
                    slide("ΟΛΗ Η ΑΕΚ, ΟΛΑ ΤΑ ΤΜΗΜΑΤΑ", "Ειδήσεις, ποδόσφαιρο, μπάσκετ, βόλεϊ, χάντμπολ και όλη η ερασιτεχνική, σε ένα μέρος.").tag(0)
                    slide("LIVE ΑΓΩΝΕΣ", "Σκορ, πορεία, ενδεκάδες, στατιστικά και βαθμοί παικτών — λεπτό προς λεπτό.").tag(1)
                    slide("ΣΤΟ ΡΟΛΟΪ ΚΑΙ ΣΤΗΝ ΟΘΟΝΗ", "Widgets για την οθόνη αφετηρίας και κλειδώματος, και εφαρμογή για Apple Watch.").tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 200)
                Spacer()
                Button {
                    if page < 2 { withAnimation { page += 1 } }
                    else { Task { _ = await Notifier.shared.requestPermission(); done() } }
                } label: {
                    Text(page < 2 ? "ΣΥΝΕΧΕΙΑ" : "ΞΕΚΙΝΑ").font(F.body(16, .bold)).foregroundStyle(C.ink)
                        .frame(maxWidth: 420).padding(.vertical, 16).background(RoundedRectangle(cornerRadius: 14).fill(C.gold))
                }.padding(.horizontal, 24)
                Button("Παράλειψη", action: done).font(F.body(13, .bold)).foregroundStyle(C.muted).padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
    }
    func slide(_ t: String, _ s: String) -> some View {
        VStack(spacing: 10) {
            Text(t).font(F.disp(30, black: true)).foregroundStyle(C.gold).multilineTextAlignment(.center)
            Text(s).font(F.body(15, .medium)).foregroundStyle(C.text2).multilineTextAlignment(.center).padding(.horizontal, 30)
        }
    }
}
