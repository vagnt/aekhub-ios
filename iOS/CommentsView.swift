import SwiftUI

/// 💬 Σχόλια (ίδιο σύστημα με το site: όνομα, likes, αναφορά, ένα επίπεδο απαντήσεων)
struct CItem: Identifiable, Hashable {
    let id: Int
    let name, ini, color, date, text, replyTo: String
    let staff, pinned, pending: Bool
    var likes: Int
    var liked: Bool
    var replies: [CItem]
    init(_ j: J) {
        id = j["id"].int; name = j["name"].str; ini = j["ini"].str.isEmpty ? "?" : j["ini"].str; color = j["color"].str
        date = j["date"].str; text = j["text"].str.htmlDecoded; replyTo = j["replyTo"].str
        staff = j["staff"].bool; pinned = j["pinned"].bool; pending = j["pending"].bool
        likes = j["likes"].int; liked = j["liked"].bool; replies = j["replies"].list(CItem.init)
    }
}

enum CommentsApi {
    static func base(_ p: String) -> URL { URL(string: Api.site + "/wp-json/aekhub/v1/app/" + p)! }
    static func req(_ p: String, form: [String: String]? = nil, timeout: TimeInterval = 20) -> URLRequest {
        var u = base(p)
        if form == nil { u = URL(string: u.absoluteString + (p.contains("?") ? "&" : "?") + "_=\(Int(Date().timeIntervalSince1970))")! }
        var r = URLRequest(url: u, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        r.setValue(Device.id, forHTTPHeaderField: "X-Aek-Device")
        r.setValue("AEKHubApp/\(Api.version) (iOS)", forHTTPHeaderField: "User-Agent")
        if let form {
            r.httpMethod = "POST"
            r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            r.httpBody = form.map { "\($0.key)=\(Api.q($0.value))" }.joined(separator: "&").data(using: .utf8)
        }
        return r
    }
    static func call(_ p: String, form: [String: String]? = nil, timeout: TimeInterval = 20) async throws -> J {
        let (data, resp) = try await URLSession.shared.data(for: req(p, form: form, timeout: timeout))
        guard let j = J.parse(data), j.isObject else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let snip = String(data: data.prefix(300), encoding: .utf8)?.plainText.prefix(90) ?? ""
            throw NSError(domain: "c", code: code, userInfo: [NSLocalizedDescriptionKey: "Ο server απάντησε HTTP \(code)" + (snip.isEmpty ? "" : " — \(snip)")])
        }
        return j
    }
}

struct CommentsView: View {
    let postId: Int
    let title: String
    @Environment(\.dismiss) var dismiss
    @State private var items: [CItem] = []
    @State private var sort = "new"
    @State private var page = 1
    @State private var more = false
    @State private var total = 0
    @State private var open = true
    @State private var closedMsg = ""
    @State private var loading = false
    @State private var error: String?
    @AppStorage("c_name") private var name = ""
    @State private var text = ""
    @State private var replyTo: CItem?
    @State private var sending = false
    @State private var info: String?
    @State private var openedAt = Date()
    @FocusState private var focus: Bool
    /// Όροι χρήσης (Apple 1.2: περιεχόμενο χρηστών) — μία φορά πριν από το πρώτο σχόλιο
    @AppStorage("c_terms") private var termsOK = false
    @State private var askTerms = false
    /// Χρήστες που έκρυψες (μόνο σε αυτό το κινητό)
    @AppStorage("c_blocked") private var blockedRaw = ""
    var blocked: Set<String> { Set(blockedRaw.split(separator: "\n").map(String.init)) }
    func hidden(_ c: CItem) -> Bool { !c.staff && blocked.contains(c.name) }
    func block(_ name: String) {
        var b = blocked; b.insert(name)
        blockedRaw = b.sorted().joined(separator: "\n")
        info = "Δεν θα βλέπεις πια σχόλια από «\(name)». Το αναίρεις από Εγώ → Κρυμμένοι χρήστες."
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        Picker("", selection: $sort) { Text("Νεότερα").tag("new"); Text("Δημοφιλή").tag("top"); Text("Παλαιότερα").tag("old") }
                            .pickerStyle(.segmented).onChange(of: sort) { _ in Task { await load(reset: true) } }
                        if let info { Text(info).font(F.body(13, .bold)).foregroundStyle(C.gold).padding(10).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 10).fill(C.panel2)) }
                        if items.isEmpty && !loading {
                            EmptyState(icon: "bubble.left.and.bubble.right", text: error ?? (open ? "Κανένα σχόλιο ακόμα. Γράψε πρώτος!" : (closedMsg.isEmpty ? "Τα σχόλια είναι κλειστά." : closedMsg)))
                        }
                        ForEach($items) { $c in
                            if !hidden(c) {
                                CommentRow(c: $c, onReply: { replyTo = c; focus = true }, onBlock: { block(c.name) }, onReported: { info = "Ευχαριστούμε — το σχόλιο θα ελεγχθεί από την ομάδα του AEK Hub." })
                                ForEach($c.replies) { $r in
                                    if !hidden(r) {
                                        CommentRow(c: $r, onReply: { replyTo = c; focus = true }, onBlock: { block(r.name) }, onReported: { info = "Ευχαριστούμε — το σχόλιο θα ελεγχθεί από την ομάδα του AEK Hub." }).padding(.leading, 36)
                                    }
                                }
                            }
                        }
                        if more { Button("Περισσότερα σχόλια") { Task { await load(reset: false) } }.font(F.body(14, .bold)).foregroundStyle(C.gold).frame(maxWidth: .infinity) }
                        if loading { ProgressView().tint(C.gold).frame(maxWidth: .infinity) }
                    }.padding(16)
                }
                if open { composer }
            }
            .background(C.ink)
            .navigationTitle(total > 0 ? "Σχόλια (\(total))" : "Σχόλια")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Κλείσιμο") { dismiss() } } }
            .task { await load(reset: true) }
            .alert("Όροι σχολίων", isPresented: $askTerms) {
                Button("Αποδέχομαι") { termsOK = true; Task { await send() } }
                Button("Διάβασε τους όρους") { if let u = URL(string: Api.site + "/oroi-xrisis/") { UIApplication.shared.open(u) } }
                Button("Άκυρο", role: .cancel) {}
            } message: {
                Text("Στο AEK Hub δεν επιτρέπονται προσβολές, ρατσισμός, απειλές, spam ή άλλο ακατάλληλο περιεχόμενο — μηδενική ανοχή. Τα σχόλια ελέγχονται και όσα παραβιάζουν τους όρους σβήνονται, ενώ ο χρήστης αποκλείεται. Μπορείς να αναφέρεις ένα σχόλιο (σημαία) ή να κρύψεις έναν χρήστη.")
            }
        }
        .preferredColorScheme(.dark)
    }

    var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let r = replyTo {
                HStack { Text("Απάντηση σε \(r.name)").font(F.body(12, .bold)).foregroundStyle(C.gold); Spacer(); Button { replyTo = nil } label: { Image(systemName: "xmark.circle.fill") }.foregroundStyle(C.muted) }
            }
            TextField("Το όνομά σου", text: $name).textInputAutocapitalization(.words)
                .font(F.body(14, .bold)).padding(10).background(RoundedRectangle(cornerRadius: 10).fill(C.panel2))
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Γράψε ένα σχόλιο…", text: $text, axis: .vertical).lineLimit(1...5).focused($focus)
                    .font(F.body(14, .medium)).padding(10).background(RoundedRectangle(cornerRadius: 10).fill(C.panel2))
                Button { if termsOK { Task { await send() } } else { askTerms = true } } label: {
                    if sending { ProgressView().tint(C.ink).frame(width: 42, height: 42) }
                    else { Image(systemName: "paperplane.fill").foregroundStyle(C.ink).frame(width: 42, height: 42) }
                }
                .background(Circle().fill(C.gold))
                .disabled(sending || text.trimmingCharacters(in: .whitespaces).isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(12).background(C.ink2)
    }

    func load(reset: Bool) async {
        if reset { page = 1 }
        loading = true; defer { loading = false }
        do {
            let j = try await CommentsApi.call("comments/\(postId)?sort=\(sort)&page=\(page)")
            let list = j["items"].list(CItem.init)
            items = reset ? list : items + list
            more = j["more"].bool; total = j["total"].int; open = j["open"].bool(true); closedMsg = j["message"].str
            page += 1; error = nil
        } catch { self.error = "Δεν φόρτωσαν τα σχόλια.\n" + error.localizedDescription }
    }

    func send() async {
        sending = true; defer { sending = false }
        let el = Int(Date().timeIntervalSince(openedAt) * 1000)
        do {
            let j = try await CommentsApi.call("comments/\(postId)", form: ["author": name, "comment": text, "parent": String(replyTo?.id ?? 0), "el": String(el)], timeout: 75)
            if j["ok"].bool {
                text = ""; replyTo = nil; focus = false
                info = j["approved"].bool ? "✓ Το σχόλιό σου δημοσιεύτηκε." : (j["message"].str.isEmpty ? "✓ Στάλθηκε — θα εμφανιστεί μόλις εγκριθεί." : j["message"].str)
                await load(reset: true)
            } else {
                info = j["message"].str.isEmpty ? "Δεν στάλθηκε." : j["message"].str
            }
        } catch {
            info = "Δεν στάλθηκε — " + error.localizedDescription + ". Το σχόλιο ίσως μπήκε· δες αν εμφανίστηκε."
        }
    }
}

private struct CommentRow: View {
    @Binding var c: CItem
    var onReply: () -> Void
    var onBlock: () -> Void
    var onReported: () -> Void
    @State private var reported = false
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(c.ini).font(F.body(14, .bold)).foregroundStyle(.white).frame(width: 34, height: 34)
                .background(Circle().fill(Color(hexString: c.color) ?? C.panel3))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(c.name).font(F.body(14, .bold)).foregroundStyle(C.text)
                    if c.staff { Text("AEK HUB").font(F.body(9, .bold)).foregroundStyle(C.ink).padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(C.gold)) }
                    if c.pinned { Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(C.gold) }
                    Spacer()
                    Text(c.date).font(F.body(11, .bold)).foregroundStyle(C.muted)
                }
                if c.pending { Text("Αναμένει έγκριση").font(F.body(11, .bold)).foregroundStyle(C.gold) }
                Text(c.text).font(F.body(14, .medium)).foregroundStyle(C.text2)
                HStack(spacing: 18) {
                    Button { Task { await like() } } label: { Label("\(c.likes)", systemImage: c.liked ? "heart.fill" : "heart") }
                        .foregroundStyle(c.liked ? C.live : C.muted)
                    Button("Απάντηση", action: onReply).foregroundStyle(C.muted)
                    Spacer()
                    Menu {
                        Button(role: .destructive) { Task { await report() } } label: { Label(reported ? "Αναφέρθηκε" : "Αναφορά σχολίου", systemImage: "flag") }.disabled(reported)
                        if !c.staff { Button(role: .destructive) { onBlock() } label: { Label("Απόκρυψη χρήστη «\(c.name)»", systemImage: "person.crop.circle.badge.xmark") } }
                    } label: { Image(systemName: reported ? "flag.fill" : "ellipsis").frame(width: 30, height: 22) }.foregroundStyle(C.muted)
                }.font(F.body(12, .bold)).buttonStyle(.plain).padding(.top, 2)
            }
        }
        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(c.pinned ? C.panel2 : C.panel))
    }
    func like() async {
        let on = !c.liked
        c.liked = on; c.likes += on ? 1 : -1
        if let j = try? await CommentsApi.call("comment/\(c.id)/like", form: ["on": on ? "1" : ""]), j["ok"].bool { c.likes = j["likes"].int; c.liked = j["liked"].bool }
    }
    func report() async {
        reported = true
        onReported()
        _ = try? await CommentsApi.call("comment/\(c.id)/report", form: ["x": "1"])
    }
}
