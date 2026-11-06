import SwiftUI

/// Αρχική (καρτέλα «Ειδήσεις»): αντίστροφη μέτρηση/live, κύριο θέμα, τελευταία νέα, αγώνες, ενότητες κατηγοριών.
struct HomeView: View {
    @State private var data: HomeData? = Api.shared.peek(Api.pHome).map(HomeData.init)
    @State private var error: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let d = data { content(d) }
                else if let error { EmptyState(icon: "wifi.exclamationmark", text: error) { Task { await load() } } }
                else { ProgressView().tint(C.gold).frame(maxWidth: .infinity).padding(60) }
            }
            .padding(.bottom, 24)
        }
        .background(C.ink)
        .refreshable { await load() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { LogoTitle() }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    NavigationLink(value: Route.feed) { Image(systemName: "clock.arrow.circlepath") }
                    NavigationLink(value: Route.search) { Image(systemName: "magnifyingglass") }
                }.foregroundStyle(C.text)
            }
        }
        .task {
            await load()
            // Ανανέωση κάθε λεπτό (κάθε 15″ όταν παίζεται αγώνας)
            while !Task.isCancelled {
                let live = data?.matches.contains { $0.live } == true || data?.next?.live == true
                try? await Task.sleep(nanoseconds: (live ? 15 : 60) * 1_000_000_000)
                await load()
            }
        }
    }

    func load() async {
        do { data = try await Api.shared.home(); error = nil }
        catch { if data == nil { self.error = "Δεν ήταν δυνατή η σύνδεση με το aekhub.gr.\n" + error.localizedDescription } }
    }

    @ViewBuilder func content(_ d: HomeData) -> some View {
        if let b = d.breaking, !b.text.isEmpty {
            Link(destination: URL(string: b.url) ?? URL(string: Api.site)!) {
                HStack(spacing: 8) {
                    Text(b.label.upperGr).font(F.body(11, .extra)).padding(.horizontal, 6).padding(.vertical, 3).background(RoundedRectangle(cornerRadius: 4).fill(.white)).foregroundStyle(C.live)
                    Text(b.text).font(F.body(13, .extra)).foregroundStyle(.white).lineLimit(2)
                    Spacer(minLength: 0)
                }.padding(12).background(C.live)
            }
        }

        // 🔴 Live Hero (αγώνας ή γεγονός)
        if let h = d.liveHero {
            if let m = h.match { CountdownCard(m: m).padding(.top, 12) }
            else if h.type == "event" {
                NavigationLink(value: Route.event(h.id)) {
                    ZStack(alignment: .bottomLeading) {
                        NetImage(url: h.image, w: 1200).frame(height: 200).frame(maxWidth: .infinity).clipped()
                        LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .center, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) { LiveDot(); Text("LIVE").font(F.body(11, .extra)).foregroundStyle(C.live) }
                            Text(h.title).font(F.disp(26, black: true)).foregroundStyle(.white).lineLimit(3)
                        }.padding(16)
                    }.clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal, 16).padding(.top, 12)
                }.buttonStyle(.plain)
            }
        } else if let n = d.next {
            CountdownCard(m: n).padding(.top, 12)
        }

        if let f = d.featured { PostHero(p: f).padding(.top, 14) }

        if !d.top.isEmpty {
            GoldHeader(title: "Τελευταία νέα")
            LazyVGrid(columns: adaptiveCols, spacing: 0) { ForEach(d.top) { PostRow(p: $0) } }
            NavigationLink(value: Route.feed) {
                Text("ΠΕΡΙΣΣΟΤΕΡΑ ΑΡΘΡΑ").font(F.body(14, .extra)).foregroundStyle(C.ink)
                    .frame(maxWidth: .infinity).padding(.vertical, 13).background(RoundedRectangle(cornerRadius: 12).fill(C.gold))
                    .padding(.horizontal, 16).padding(.top, 8)
            }.buttonStyle(.plain)
        }

        if !d.matches.isEmpty {
            GoldHeader(title: "Αγώνες")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) { ForEach(d.matches) { MatchMini(m: $0) } }.padding(.horizontal, 16)
            }
        }

        ForEach(d.sections) { s in
            if !s.items.isEmpty {
                SectionBlock(s: s)
            }
        }
    }
}

private struct SectionBlock: View {
    let s: HomeSection
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                GoldHeader(title: s.name)
                NavigationLink(value: Route.category(s.slug, s.name)) {
                    HStack(spacing: 2) { Text("Όλα").font(F.body(13, .extra)); Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)) }
                        .foregroundStyle(C.gold)
                }.padding(.trailing, 16).padding(.top, 10)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) { ForEach(s.items) { PostTile(p: $0) } }.padding(.horizontal, 16)
            }
        }
    }
}
