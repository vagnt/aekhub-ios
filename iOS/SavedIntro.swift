import SwiftUI
import AVFoundation

/// Αποθηκευμένα άρθρα ή ιστορικό ανάγνωσης
struct SavedView: View {
    var history = false
    @ObservedObject var p = Prefs.shared
    @Environment(\.dismiss) var dismiss
    var list: [PostCard] { history ? p.history : p.saved }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { dismiss() } label: { Image(systemName: "chevron.left").font(.system(size: 19, weight: .semibold)).foregroundStyle(C.text).frame(width: 44, height: 44) }
                ScreenTitle(text: history ? "Διάβασες πρόσφατα" : "Αποθηκευμένα")
                Spacer()
                if history && !p.history.isEmpty {
                    Button { p.history = [] } label: { Text("Καθάρισμα").font(F.body(14, .heavy)).foregroundStyle(C.gold) }.buttonStyle(.plain)
                }
            }
            .padding(.leading, 4).padding(.trailing, 16).padding(.vertical, 6)
            ScrollView {
                if list.isEmpty {
                    EmptyState(icon: history ? "clock" : "bookmark", text: history ? "Τα άρθρα που διαβάζεις θα εμφανίζονται εδώ." : "Δεν έχεις αποθηκεύσει άρθρα.\nΠάτα 🔖 πάνω σε ένα άρθρο για να το κρατήσεις εδώ.")
                }
                LazyVGrid(columns: adaptiveCols, spacing: 0) {
                    ForEach(list) { a in
                        PostRow(p: a).contextMenu {
                            if !history { Button(role: .destructive) { p.toggleSaved(a) } label: { Label("Αφαίρεση", systemImage: "trash") } }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(C.ink)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Άνοιγμα της εφαρμογής (10/11/2026, ζήτησε ο χρήστης): το βίντεο του AEK Hub σε όλη την οθόνη
/// (κινητό · iPad κάθετο · iPad οριζόντιο) με δονήσεις ΣΥΓΧΡΟΝΙΣΜΕΝΕΣ με το βίντεο:
/// «σκάει» ο κύκλος hub → γίνεται κουτί → πέφτουν a, e → το K (δυνατό) → το σύνθημα. Πάτημα = προσπέραση.
struct IntroSplash: View {
    var done: () -> Void
    @State private var out = 0.0
    @State private var ended = false

    var body: some View {
        GeometryReader { g in
            ZStack {
                Color.black.ignoresSafeArea()
                if let url = Self.video(g.size) {
                    SplashPlayer(url: url, beats: Self.beats) { finish() }.ignoresSafeArea()
                }
            }
            .opacity(1 - out)
            .contentShape(Rectangle())
            .onTapGesture { finish() }
            .onAppear { if Self.video(g.size) == nil { finish() } }
        }
        .ignoresSafeArea()
    }

    /// Στιγμές (δευτερόλεπτα του βίντεο) και ένταση της δόνησης
    static let beats: [(Double, UIImpactFeedbackGenerator.FeedbackStyle, CGFloat)] = [
        (1.92, .medium, 1.0),  // ο κύκλος hub «σκάει»
        (2.32, .light, 0.8),   // γίνεται το κουτί
        (2.97, .rigid, 0.9),   // πέφτει το a
        (3.26, .rigid, 0.9),   // το e
        (3.54, .heavy, 1.0),   // το K
        (4.15, .soft, 0.6),    // «Όλη η ΑΕΚ, σε ένα σημείο!»
    ]

    static func video(_ size: CGSize) -> URL? {
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        let name = !pad ? "splash_phone" : (size.width > size.height ? "splash_tab_l" : "splash_tab_p")
        return Bundle.main.url(forResource: name, withExtension: "mp4")
    }

    func finish() {
        guard !ended else { return }
        ended = true
        withAnimation(.easeInOut(duration: 0.35)) { out = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) { done() }
    }
}

/// AVPlayer χωρίς ήχο (δεν σταματά τη μουσική του χρήστη), γεμίζει την οθόνη, δονήσεις στις ακριβείς στιγμές του βίντεο
struct SplashPlayer: UIViewRepresentable {
    let url: URL
    let beats: [(Double, UIImpactFeedbackGenerator.FeedbackStyle, CGFloat)]
    var end: () -> Void

    final class PView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var pl: AVPlayerLayer { layer as! AVPlayerLayer }
        var obs: [Any] = []
        var timeObs: [Any] = []
        deinit {
            for o in obs { NotificationCenter.default.removeObserver(o) }
            for o in timeObs { pl.player?.removeTimeObserver(o) }
        }
    }

    func makeUIView(context: Context) -> PView {
        let v = PView()
        v.backgroundColor = .black
        // να μη σταματά η μουσική/το podcast του χρήστη στο άνοιγμα
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.isMuted = true
        p.preventsDisplaySleepDuringVideoPlayback = false
        v.pl.player = p
        v.pl.videoGravity = .resizeAspectFill
        // δονήσεις συγχρονισμένες με το βίντεο (όχι με χρονόμετρο: αν αργήσει το βίντεο, αργούν κι αυτές)
        for b in beats {
            let gen = UIImpactFeedbackGenerator(style: b.1); gen.prepare()
            let t = NSValue(time: CMTime(seconds: b.0, preferredTimescale: 600))
            v.timeObs.append(p.addBoundaryTimeObserver(forTimes: [t], queue: .main) { gen.impactOccurred(intensity: b.2) })
        }
        v.obs.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in end() })
        v.obs.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { _ in end() })
        p.play()
        return v
    }

    func updateUIView(_ v: PView, context: Context) {}
    static func dismantleUIView(_ v: PView, coordinator: ()) {
        v.pl.player?.pause()
        try? AVAudioSession.sharedInstance().setCategory(.soloAmbient) // η προεπιλογή του iOS (για τα βίντεο της εφαρμογής)
    }
}
