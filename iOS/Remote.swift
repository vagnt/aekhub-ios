import SwiftUI

/// 🎛 Έλεγχος app από το wp-admin (📱 AEK Hub App → 🎛 Έλεγχος app, AEK Hub App 1.8.0) — χωρίς νέα έκδοση:
/// 📣 ανακοίνωση στην αρχική · ⬆️ «Υπάρχει νέα έκδοση» · 🔀 διακόπτες ενοτήτων (`AppState.on`).

// MARK: - 📣 Ανακοίνωση στην αρχική

struct NoticeCard: View {
    let n: AppNotice
    @AppStorage("notice_closed") private var closed = ""
    @StateObject private var img = ImageLoader()
    @Environment(\.openURL) var openURL

    var body: some View {
        if closed != n.id {
            VStack(alignment: .leading, spacing: 0) {
                if !n.image.isEmpty {
                    Color.clear.frame(height: 150)
                        .overlay { if let i = img.image { Image(uiImage: i).resizable().scaledToFill() } else { C.panel2 } }
                        .clipped()
                        .task(id: n.image) { img.load(Img.url(n.image, w: 900)) }
                }
                VStack(alignment: .leading, spacing: 6) {
                    if !n.title.isEmpty {
                        Text(n.title).font(F.body(16, .heavy)).foregroundStyle(C.text).fixedSize(horizontal: false, vertical: true).padding(.trailing, n.image.isEmpty ? 26 : 0)
                    }
                    if !n.text.isEmpty { Text(n.text).font(F.body(13.5)).foregroundStyle(C.text2).fixedSize(horizontal: false, vertical: true) }
                    if !n.link.isEmpty {
                        Text((n.cta.isEmpty ? "Δες περισσότερα" : n.cta) + " ›").font(F.body(13, .heavy)).foregroundStyle(C.ink)
                            .padding(.horizontal, 12).padding(.vertical, 7).background(Capsule().fill(C.gold)).padding(.top, 4)
                    }
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(C.panel))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(C.gold.opacity(0.55), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { if let u = URL(string: n.link), !n.link.isEmpty { haptic(); openURL(u) } }
            .overlay(alignment: .topTrailing) {
                Button { haptic(); withAnimation(.easeOut(duration: 0.2)) { closed = n.id } } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(C.text)
                        .frame(width: 26, height: 26).background(Circle().fill(C.ink.opacity(0.7)))
                }
                .buttonStyle(.plain).padding(8).accessibilityLabel("Κλείσιμο")
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - ⬆️ Υπάρχει νέα έκδοση

/// Παλιότερη από `min` → παράθυρο που δεν κλείνει · παλιότερη από `latest` → μία φορά ανά έκδοση, με «Αργότερα».
struct UpdatePrompt: View {
    let u: AppUpdate
    @AppStorage("update_seen") private var seen = ""
    @State private var later = false

    var must: Bool { !u.min.isEmpty && AppUpdate.older(AppState.version, than: u.min) }
    var newer: Bool { !u.latest.isEmpty && AppUpdate.older(AppState.version, than: u.latest) }
    var show: Bool { must || (newer && seen != u.latest && !later) }

    var body: some View {
        if show {
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.app.fill").font(.system(size: 44)).foregroundStyle(C.gold)
                    Text("Υπάρχει νέα έκδοση").font(F.body(19, .heavy)).foregroundStyle(C.text)
                    Text(u.text.isEmpty ? "Ενημέρωσε το AEK Hub για να έχεις όλα τα καινούργια." : u.text)
                        .font(F.body(14)).foregroundStyle(C.text2).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    if !u.latest.isEmpty {
                        Text("Έκδοση " + u.latest + " · έχεις την " + AppState.version).font(F.body(12)).foregroundStyle(C.muted)
                    }
                    Button {
                        haptic()
                        if let url = URL(string: u.url.isEmpty ? "https://apps.apple.com/app/id6831797578" : u.url) { UIApplication.shared.open(url) }
                    } label: {
                        Text("Ενημέρωση").font(F.body(15, .heavy)).foregroundStyle(C.ink)
                            .frame(maxWidth: .infinity).padding(.vertical, 12).background(Capsule().fill(C.gold))
                    }
                    .buttonStyle(.plain).padding(.top, 4)
                    if !must {
                        Button { haptic(); seen = u.latest; later = true } label: {
                            Text("Αργότερα").font(F.body(14, .bold)).foregroundStyle(C.text2).padding(.vertical, 6)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(22)
                .frame(maxWidth: 340)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(C.panel))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(C.line2, lineWidth: 1))
                .padding(24)
            }
            .transition(.opacity)
            .zIndex(5)
        }
    }
}
