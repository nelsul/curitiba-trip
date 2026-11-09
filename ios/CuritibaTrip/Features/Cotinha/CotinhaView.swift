import SwiftUI

/// Cotinha (web /cotinha): someone paid for the group, leaves their Pix key, and everyone marks when they paid.
struct CotinhaView: View {
	@Environment(AppState.self) private var app
	@State private var list: SplitList?
	@State private var error: String?
	@State private var showAll = false
	/** Cotinhas, or what I owe grouped by who paid ("Por pessoa", to pay everything with one Pix) */
	@State private var byPerson = false
	@State private var paying: Debt?
	@State private var creating = false
	@State private var toast: String?
	@State private var deleting: Split?

	private var me: String { app.me?.id ?? "" }
	private var splits: [Split] { (list?.splits ?? []).filter { showAll || $0.open } }
	private var iOwe: Int { (list?.splits ?? []).filter { $0.payerId != me }.flatMap(\.shares).filter { $0.userId == me && $0.paidAt == nil }.map(\.amountCents).reduce(0, +) }
	/// What I still owe, per person who paid (newest Pix key of theirs), biggest first.
	private var debts: [Debt] {
		var by: [String: Debt] = [:]
		for s in list?.splits ?? [] where s.payerId != me {
			guard let mine = s.shares.first(where: { $0.userId == me && $0.paidAt == nil }) else { continue }
			var d = by[s.payerId] ?? Debt(payerId: s.payerId)
			d.totalCents += mine.amountCents
			if d.pixKey.isEmpty { d.pixKey = s.pixKey }
			d.items.append(.init(id: s.id, title: s.title, amountCents: mine.amountCents, createdAt: s.createdAt))
			by[s.payerId] = d
		}
		return by.values.sorted { $0.totalCents > $1.totalCents }
	}
	private var owedToMe: Int { (list?.splits ?? []).filter { $0.payerId == me }.flatMap(\.shares).filter { $0.userId != me && $0.paidAt == nil }.map(\.amountCents).reduce(0, +) }

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 14) {
				TitleRow(icon: .wallet, title: "Cotinha")
				Text("Pagou algo para o grupo? Crie uma cotinha com sua chave Pix: cada um vê quanto deve e marca quando pagar.")
					.font(.text(16)).foregroundStyle(Color.muted)
				HStack(spacing: 10) {
					total("Você deve", iOwe, .coral)
					total("Te devem", owedToMe, .leaf)
				}
				Button { creating = true } label: { Label { Text("Nova cotinha") } icon: { Icon(.plus, size: 20) } }
					.buttonStyle(.chunky(.sun, fullWidth: true))
				ViewSwitch(byPerson: $byPerson)
				if let error, list == nil { EmptyState(text: error, retry: { Task { await load() } }) }
				if byPerson {
					Text("Quanto você deve para cada pessoa, somando as cotinhas. Pague tudo de uma vez com um Pix só e marque “Paguei tudo”.")
						.font(.text(14)).foregroundStyle(Color.muted)
					ForEach(debts) { d in DebtCard(debt: d, copy: { copy($0) }, payAll: { paying = d }).popIn() }
					if list != nil && debts.isEmpty {
						VStack(spacing: 8) {
							Icon(.check, size: 40).foregroundStyle(Color.leaf)
							Text("Você não deve nada para ninguém.").font(.text(16)).foregroundStyle(Color.muted)
						}
						.frame(maxWidth: .infinity).card()
					}
				} else {
				HStack(spacing: 8) {
					Chip(selected: !showAll, action: { showAll = false }) { Text("Em aberto") }
					Chip(selected: showAll, action: { showAll = true }) { Text("Todas") }
				}
				ForEach(splits) { s in SplitCard(split: s, reload: load, say: say, delete: { deleting = s }).popIn() }
				}
				if !byPerson && list != nil && splits.isEmpty {
					VStack(spacing: 8) {
						Icon(.wallet, size: 40).foregroundStyle(Color.muted)
						Text(showAll ? "Nenhuma cotinha ainda." : "Nenhuma cotinha em aberto.").font(.text(16)).foregroundStyle(Color.muted)
					}
					.frame(maxWidth: .infinity).card()
				}
			}
			.padding(16)
			.frame(maxWidth: 640)
			.frame(maxWidth: .infinity)
		}
		.refreshable { await load() }
		.task { await load() }
		.overlay(alignment: .bottom) {
			if let toast {
				Text(toast).font(.text(14, .extraBold)).foregroundStyle(Color.onLeaf)
					.padding(.horizontal, 16).padding(.vertical, 8).background(Capsule().fill(Color.leaf))
					.padding(.bottom, 120).transition(.opacity)
			}
		}
		.sheet(isPresented: $creating) { NewSplitView(myPix: list?.myPix ?? "") { Task { await load() } } }
		.confirmationDialog("Marcar como pago tudo o que você deve para \(app.person(paying?.payerId ?? "")?.name ?? "essa pessoa") (\(Money.brl(paying?.totalCents ?? 0)))?",
							isPresented: Binding(get: { paying != nil }, set: { if !$0 { paying = nil } }), titleVisibility: .visible) {
			Button("Paguei tudo") {
				guard let d = paying else { return }
				Task {
					do {
						let _: PayAllResult = try await API.shared.post("/api/splits/pay-all", PayAllBody(payerId: d.payerId))
						say(d.items.count == 1 ? "Pronto! A cotinha foi marcada como paga." : "Pronto! As \(d.items.count) cotinhas foram marcadas como pagas.")
						await load()
					} catch { app.handle(error); say(error.localizedDescription) }
				}
			}
		}
		.confirmationDialog("Apagar a cotinha \"\(deleting?.title ?? "")\"?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
			Button("Apagar", role: .destructive) {
				guard let s = deleting else { return }
				Task {
					do { try await API.shared.delete("/api/splits/\(s.id)"); await load() } catch { app.handle(error); say(error.localizedDescription) }
				}
			}
		}
	}

	private func total(_ label: String, _ cents: Int, _ color: Color) -> some View {
		VStack(alignment: .leading, spacing: 2) {
			Text(label).font(.text(14)).foregroundStyle(Color.ink)
			Text(Money.brl(cents)).font(.display(22)).foregroundStyle(color)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.card(padding: 12)
	}

	private func load() async {
		do {
			list = try await API.shared.get("/api/splits")
			error = nil
			CotinhaBadge.shared.update(list?.splits ?? [], me: me)
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}

	private func copy(_ key: String) {
		UIPasteboard.general.string = key
		say("Chave Pix copiada!")
	}

	private func say(_ text: String) {
		withAnimation { toast = text }
		Task { try? await Task.sleep(for: .seconds(2.5)); withAnimation { toast = nil } }
	}
}

/// How many cotinhas I still owe (the dock's badge).
@MainActor @Observable
final class CotinhaBadge {
	static let shared = CotinhaBadge()
	var owing = 0

	func update(_ splits: [Split], me: String) {
		owing = splits.filter { s in s.payerId != me && s.shares.contains { $0.userId == me && $0.paidAt == nil } }.count
	}

	func refresh(me: String) async {
		if let l: SplitList = try? await API.shared.get("/api/splits") { update(l.splits, me: me) }
	}
}

private struct SplitCard: View {
	let split: Split
	let reload: () async -> Void
	let say: (String) -> Void
	let delete: () -> Void
	@Environment(AppState.self) private var app

	private var me: String { app.me?.id ?? "" }
	private var mine: Bool { split.payerId == me }
	private func name(_ id: String) -> String { id == me ? "Você" : (app.person(id)?.name ?? "Alguém") }

	var body: some View {
		let payer = app.person(split.payerId)
		let paid = split.shares.filter { $0.paidAt != nil }.count
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 10) {
				AvatarView(name: payer?.name ?? "?", color: payer?.tint ?? .muted, photo: payer?.photo, size: 40)
				VStack(alignment: .leading, spacing: 0) {
					Text(split.title).font(.display(18)).foregroundStyle(Color.ink)
					Text("\(mine ? "Você pagou" : "\(name(split.payerId)) pagou") · \(TripTime.ago(split.createdAt))").font(.text(13)).foregroundStyle(Color.muted)
				}
				Spacer()
				Text(Money.brl(split.totalCents)).font(.display(19)).foregroundStyle(Color.sun)
			}
			if !mine, let share = split.shares.first(where: { $0.userId == me }) {
				HStack {
					Text(share.paidAt != nil ? "Você já pagou" : "Sua parte").font(.text(15, .extraBold))
					Spacer()
					Text(Money.brl(share.amountCents)).font(.display(19))
				}
				.foregroundStyle(Color.ink)
				.padding(.horizontal, 12).padding(.vertical, 8)
				.background(RoundedRectangle(cornerRadius: 14).fill((share.paidAt != nil ? Color.leaf : Color.coral).opacity(0.22)))
			}
			if !split.pixKey.isEmpty {
				Button {
					UIPasteboard.general.string = split.pixKey
					say("Chave Pix copiada!")
				} label: {
					HStack {
						VStack(alignment: .leading, spacing: 0) {
							Text("\(mine ? "Sua chave Pix" : "Pix de \(name(split.payerId))") · toque para copiar").font(.text(13)).foregroundStyle(Color.muted)
							Text(split.pixKey).font(.text(16, .extraBold)).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
						}
						Spacer()
						Icon(.copy, size: 18).foregroundStyle(Color.sea)
					}
					.padding(.horizontal, 12).padding(.vertical, 8)
					.overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.sea, style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])))
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Copiar a chave Pix \(split.pixKey)")
			}
			if !split.note.isEmpty { Text(split.note).font(.text(14)).foregroundStyle(Color.ink) }
			GeometryReader { g in
				Capsule().fill(Color.track).overlay(alignment: .leading) {
					Capsule().fill(Color.leaf).frame(width: g.size.width * CGFloat(paid) / CGFloat(max(1, split.shares.count)))
				}
			}
			.frame(height: 8)
			.accessibilityLabel("\(paid) de \(split.shares.count) pagaram")
			ForEach(split.shares, id: \.userId) { x in shareRow(x) }
			if mine || app.me?.isAdmin == true {
				HStack {
					if split.open && mine {
						Button { Task { await remind() } } label: { Label { Text("Cobrar quem falta") } icon: { Icon(.bell, size: 16) } }
							.buttonStyle(.chunky(.secondary, small: true))
					}
					Spacer()
					Button("Apagar", action: delete).font(.text(15, .extraBold)).tint(.danger)
				}
			}
		}
		.card()
		.opacity(split.open ? 1 : 0.75)
	}

	private func shareRow(_ x: SplitShare) -> some View {
		let p = app.person(x.userId)
		let canMark = x.userId == me || mine || app.me?.isAdmin == true
		return HStack(spacing: 8) {
			AvatarView(name: p?.name ?? "?", color: p?.tint ?? .muted, photo: p?.photo, size: 30)
			Text(name(x.userId) + (x.userId == split.payerId ? " (pagou)" : "")).font(.text(15, .bold)).foregroundStyle(Color.ink).lineLimit(1)
			Spacer()
			Text(Money.brl(x.amountCents)).font(.text(15, .extraBold)).monospacedDigit().foregroundStyle(Color.ink)
			if x.userId == split.payerId {
				state(true, "")
			} else if canMark {
				Button { Task { await setPaid(x.userId, x.paidAt == nil) } } label: {
					state(x.paidAt != nil, x.paidAt != nil ? "Pago" : (x.userId == me ? "Já paguei" : "Pagou?"), button: true)
				}
				.buttonStyle(.plain)
				.accessibilityLabel(x.paidAt != nil ? "Desmarcar pagamento de \(name(x.userId))" : "Marcar que \(name(x.userId)) pagou")
			} else {
				state(x.paidAt != nil, x.paidAt != nil ? "" : "Falta")
			}
		}
	}

	private func state(_ ok: Bool, _ text: String, button: Bool = false) -> some View {
		HStack(spacing: 3) {
			if ok { Icon(.check, size: 15) }
			if !text.isEmpty { Text(text) }
		}
		.font(.text(13, .extraBold))
		.foregroundStyle(ok ? Color.onLeaf : (button ? Color.ink : Color.muted))
		.frame(minWidth: 84, minHeight: 36)
		.background(Capsule().fill(ok ? Color.leaf : Color.surface2))
		.overlay(Capsule().strokeBorder(ok ? Color.leaf : (button ? Color.sea : Color.line), lineWidth: 2))
	}

	private func setPaid(_ userId: String, _ paid: Bool) async {
		do {
			let _: OK = try await API.shared.post("/api/splits/\(split.id)/paid", PaidBody(userId: userId, paid: paid))
			await reload()
		} catch { app.handle(error); say(error.localizedDescription) }
	}

	private func remind() async {
		do {
			let _: OK = try await API.shared.post("/api/splits/\(split.id)/remind", Empty())
			say("Lembrete enviado para quem ainda não pagou.")
			await reload()
		} catch { app.handle(error); say(error.localizedDescription) }
	}
}

private struct NewSplitView: View {
	let myPix: String
	let created: () -> Void
	@Environment(AppState.self) private var app
	@Environment(\.dismiss) private var dismiss
	@State private var title = ""
	@State private var amount = ""
	@State private var pix = ""
	@State private var note = ""
	@State private var who: [String] = []
	@State private var busy = false
	@State private var error: String?
	@State private var filled = false

	private var cents: Int? { Money.cents(amount) }
	private var parts: [Int] { cents.map { Money.parts($0, who.count) } ?? [] }

	var body: some View {
		NavigationStack {
			Form {
				Section("O que foi") { TextField("Ex.: Mercado, Uber do aeroporto", text: $title) }.listRowBackground(Color.surface)
				Section("Valor total (R$)") { TextField("0,00", text: $amount).keyboardType(.decimalPad) }.listRowBackground(Color.surface)
				Section {
					TextField("CPF, e-mail, celular ou chave aleatória", text: $pix).textInputAutocapitalization(.never).autocorrectionDisabled()
				} header: { Text("Sua chave Pix") } footer: { Text("Fica salva para as próximas cotinhas.") }
				.listRowBackground(Color.surface)
				Section("Quem divide (\(who.count))") {
					ForEach(app.people) { p in
						Button { if let i = who.firstIndex(of: p.id) { who.remove(at: i) } else { who.append(p.id) } } label: {
							HStack(spacing: 10) {
								AvatarView(name: p.name, color: p.tint, photo: p.photo, size: 30)
								Text(p.id == app.me?.id ? "Você" : p.name).font(.text(16, .bold)).foregroundStyle(Color.ink)
								Spacer()
								if let i = who.firstIndex(of: p.id) {
									if i < parts.count { Text(Money.brl(parts[i])).font(.text(14, .extraBold)).foregroundStyle(Color.leaf) }
									Icon(.check, size: 18).foregroundStyle(Color.leaf)
								}
							}
						}
						.accessibilityAddTraits(who.contains(p.id) ? .isSelected : [])
					}
				}.listRowBackground(Color.surface)
				Section("Observação") { TextField("Opcional", text: $note, axis: .vertical).lineLimit(1...4) }.listRowBackground(Color.surface)
				if let error { Section { Text(error).foregroundStyle(Color.danger).font(.text(14, .bold)) }.listRowBackground(Color.surface) }
			}
			.scrollContentBackground(.hidden)
			.background(Color.bg)
			.navigationTitle("Nova cotinha")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
				ToolbarItem(placement: .confirmationAction) { Button(busy ? "Criando…" : "Criar") { Task { await save() } }.disabled(busy) }
			}
			.onAppear {
				guard !filled else { return }
				filled = true
				pix = myPix
				who = app.people.map(\.id)
			}
		}
		.tint(.sea)
	}

	private func save() async {
		guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { error = "Diga o que foi comprado."; return }
		guard let cents, cents > 0 else { error = "Valor inválido."; return }
		guard !who.isEmpty else { error = "Escolha quem divide."; return }
		busy = true
		defer { busy = false }
		do {
			let _: CreatedId = try await API.shared.post("/api/splits", NewSplit(title: title, totalCents: cents, pixKey: pix, note: note, participants: who))
			created()
			dismiss()
		} catch {
			app.handle(error)
			self.error = error.localizedDescription
		}
	}
}

/// What I owe one person, adding up their cotinhas.
struct Debt: Identifiable {
	struct Item: Identifiable { let id: String; let title: String; let amountCents: Int; let createdAt: String }
	let payerId: String
	var totalCents = 0
	var pixKey = ""
	var items: [Item] = []
	var id: String { payerId }
}

struct PayAllBody: Encodable, Sendable { let payerId: String }
struct PayAllResult: Decodable, Sendable { let parts: Int; let totalCents: Int }

/// Cotinhas or Por pessoa.
private struct ViewSwitch: View {
	@Binding var byPerson: Bool

	var body: some View {
		HStack(spacing: 6) {
			item(false, .wallet, "Cotinhas")
			item(true, .people, "Por pessoa")
		}
		.padding(4)
		.background(Capsule().fill(Color.surface))
		.overlay(Capsule().strokeBorder(Color.line, lineWidth: 2.5))
		.animation(.bounce, value: byPerson)
	}

	private func item(_ value: Bool, _ icon: IconName, _ label: String) -> some View {
		Button { byPerson = value } label: {
			HStack(spacing: 6) { Icon(icon, size: 18); Text(label).font(.display(16)) }
				.foregroundStyle(byPerson == value ? Color.onSea : Color.muted)
				.frame(maxWidth: .infinity, minHeight: 40)
				.background(Capsule().fill(byPerson == value ? Color.sea : .clear))
		}
		.buttonStyle(.plain)
		.accessibilityAddTraits(byPerson == value ? .isSelected : [])
	}
}

private struct DebtCard: View {
	let debt: Debt
	let copy: (String) -> Void
	let payAll: () -> Void
	@Environment(AppState.self) private var app

	var body: some View {
		let p = app.person(debt.payerId)
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 10) {
				AvatarView(name: p?.name ?? "?", color: p?.tint ?? .muted, photo: p?.photo, size: 44)
				VStack(alignment: .leading, spacing: 0) {
					Text(p?.name ?? "Alguém").font(.display(18)).foregroundStyle(Color.ink)
					Text("\(debt.items.count) \(debt.items.count == 1 ? "cotinha" : "cotinhas")").font(.text(13)).foregroundStyle(Color.muted)
				}
				Spacer()
				Text(Money.brl(debt.totalCents)).font(.display(20)).foregroundStyle(Color.coral)
			}
			if !debt.pixKey.isEmpty {
				Button { copy(debt.pixKey) } label: {
					HStack {
						VStack(alignment: .leading, spacing: 0) {
							Text("Pix de \(p?.name ?? "alguém") · toque para copiar").font(.text(13)).foregroundStyle(Color.muted)
							Text(debt.pixKey).font(.text(16, .extraBold)).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
						}
						Spacer()
						Icon(.copy, size: 18).foregroundStyle(Color.sea)
					}
					.padding(.horizontal, 12).padding(.vertical, 8)
					.overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.sea, style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])))
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Copiar a chave Pix \(debt.pixKey)")
			}
			ForEach(debt.items) { it in
				HStack(alignment: .firstTextBaseline) {
					Text(it.title).font(.text(15)).foregroundStyle(Color.ink)
					Spacer()
					Text(TripTime.ago(it.createdAt)).font(.text(12)).foregroundStyle(Color.muted)
					Text(Money.brl(it.amountCents)).font(.text(15, .extraBold)).monospacedDigit().foregroundStyle(Color.ink)
				}
			}
			Button(action: payAll) { Label { Text("Paguei tudo · \(Money.brl(debt.totalCents))") } icon: { Icon(.check, size: 18) } }
				.buttonStyle(.chunky(.sun, fullWidth: true))
		}
		.card()
	}
}
