import SwiftUI

/// Same flow as the web /login: passport card → "Quem é você?" → 6-digit code from the email.
struct LoginView: View {
	@Environment(AppState.self) private var app
	@State private var people: [Person] = []
	@State private var picked: Person?
	@State private var maskedEmail = ""
	@State private var code = ""
	@State private var busy: String?
	@State private var error: String?
	@FocusState private var codeFocused: Bool

	var body: some View {
		ScrollViewReader { scroller in
		ScrollView {
			VStack(spacing: 18) {
				// on the code step the passport shrinks so the field and button stay above the keyboard
				PassportCard(compact: picked != nil)
				if picked == nil {
					Text("Fotos, vídeos e lugares de todo mundo, num diário só.")
						.font(.text(15, .bold)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
						.padding(.horizontal, 8)
				}
				if let picked { codeStep(picked).id("code") } else { pickStep }
			}
			.padding(.horizontal, 16)
			.padding(.top, 24)
			.padding(.bottom, 32)
			.frame(maxWidth: 440)
			.frame(maxWidth: .infinity)
		}
		.scrollDismissesKeyboard(.interactively)
		.onChange(of: codeFocused) { _, focused in
			if focused { withAnimation { scroller.scrollTo("code", anchor: .bottom) } }
		}
		}
		.task { await loadPeople() }
	}

	private var pickStep: some View {
		VStack(spacing: 14) {
			Text("Quem é você?").font(.display(24)).foregroundStyle(Color.ink)
			if let error { Text(error).font(.text(15, .bold)).foregroundStyle(Color.danger).multilineTextAlignment(.center) }
			if people.isEmpty && error == nil { ProgressView().tint(.sea).padding() }
			LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
				ForEach(Array(people.enumerated()), id: \.element.id) { i, p in
					Button { Task { await sendCode(to: p) } } label: {
						VStack(spacing: 6) {
							AvatarView(name: p.name, color: p.tint, photo: p.photo, size: 64)
							Text(p.name).font(.display(17)).foregroundStyle(Color.ink).lineLimit(1)
							if busy == p.id { Text("Enviando…").font(.text(12, .extraBold)).foregroundStyle(Color.muted) }
						}
						.frame(maxWidth: .infinity)
						.padding(.vertical, 14)
						.card(padding: 0, radius: 20)
					}
					.buttonStyle(PressScale())
					.disabled(busy != nil)
					.popIn(delay: Double(i) * 0.06)
				}
			}
			Text("Vamos mandar um código para o seu e-mail.").font(.text(13)).foregroundStyle(Color.muted)
		}
	}

	private func codeStep(_ p: Person) -> some View {
		VStack(alignment: .leading, spacing: 14) {
			HStack(spacing: 12) {
				AvatarView(name: p.name, color: p.tint, photo: p.photo, size: 56)
				Text("Oi, \(p.name)! Enviamos um código de 6 números para **\(maskedEmail)**.")
					.font(.text(16)).foregroundStyle(Color.ink)
			}
			Text("Código").font(.display(16)).foregroundStyle(Color.ink)
			TextField("", text: $code)
				.textContentType(.oneTimeCode)
				.keyboardType(.numberPad)
				.focused($codeFocused)
				.font(.display(30))
				.kerning(10)
				.multilineTextAlignment(.center)
				.foregroundStyle(Color.ink)
				.padding(.vertical, 10)
				.background(RoundedRectangle(cornerRadius: 16).fill(Color.surface))
				.overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(codeFocused ? Color.sea : Color.line, lineWidth: 2.5))
				.onChange(of: code) { _, v in
					let digits = String(v.filter(\.isNumber).prefix(6))
					if digits != v { code = digits }
					if digits.count == 6 { Task { await verify(p) } }
				}
				.accessibilityLabel("Código de 6 números")
			if let error { Text(error).font(.text(15, .bold)).foregroundStyle(Color.danger) }
			Button { Task { await verify(p) } } label: { Text(busy == "code" ? "Embarcando…" : "Embarcar") }
				.buttonStyle(.chunky(.sun, fullWidth: true))
				.disabled(code.count != 6 || busy != nil)
			VStack(spacing: 4) {
				Button("Não chegou? Enviar de novo") { Task { await sendCode(to: p) } }
				Text("Olhe também a caixa de spam.").font(.text(13)).foregroundStyle(Color.muted)
				Button("Não é você? Trocar") { withAnimation { picked = nil; code = ""; error = nil } }
			}
			.font(.text(15, .extraBold))
			.tint(.leaf)
			.frame(maxWidth: .infinity)
		}
		.card(padding: 18)
		.popIn()
		.onAppear { codeFocused = true }
	}

	private func loadPeople() async {
		do { people = try await API.shared.get("/api/auth/people") } catch { self.error = error.localizedDescription }
	}

	private func sendCode(to p: Person) async {
		busy = p.id
		error = nil
		defer { busy = nil }
		do {
			let r: CodeResponse = try await API.shared.post("/api/auth/code", ["userId": p.id])
			maskedEmail = r.maskedEmail
			withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { picked = p }
		} catch {
			self.error = error.localizedDescription
		}
	}

	private func verify(_ p: Person) async {
		guard busy == nil, code.count == 6 else { return }
		busy = "code"
		error = nil
		defer { busy = nil }
		do {
			let device = UIDevice.current.name
			let r: VerifyResponse = try await API.shared.post("/api/auth/verify", ["userId": p.id, "code": code, "deviceName": device])
			await app.signedIn(r)
		} catch {
			self.error = error.localizedDescription
			code = ""
		}
	}
}

/// The teal passport cover with drifting clouds and a plane crossing the top edge.
struct PassportCard: View {
	var compact = false
	@State private var fly = false
	@State private var drift = false

	var body: some View {
		VStack(spacing: 4) {
			Text("PASSAPORTE DA VIAGEM").font(.text(12, .extraBold)).kerning(2.4).opacity(0.9)
			Text("Curitiba").font(.display(compact ? 32 : 48, relativeTo: .largeTitle)).shadow(color: .black.opacity(0.15), radius: 0, y: 3)
			Text("11 – 18 de novembro · 2026").font(.text(compact ? 14 : 16, .bold))
			if !compact { Icon(.leaf, size: 30)
				.foregroundStyle(Color.onSun)
				.frame(width: 58, height: 58)
				.background(Circle().fill(Color.sun))
				.background(Circle().fill(Color.sunDark).offset(y: 4))
				.rotationEffect(.degrees(drift ? 4 : -4))
				.padding(.top, 14) }
		}
		.foregroundStyle(Color.onPassport)
		.frame(maxWidth: .infinity)
		.padding(.vertical, compact ? 22 : 34)
		.animation(.bounce, value: compact)
		.background {
			GeometryReader { geo in
				ZStack(alignment: .topLeading) {
					RadialGradient(colors: [.passportLight, .passport], center: UnitPoint(x: 0.3, y: 0.2), startRadius: 0, endRadius: geo.size.width)
					// clouds stay in the corners, behind the text (same as the web fix)
					Capsule().fill(.white.opacity(0.14)).frame(width: 60, height: 18).offset(x: geo.size.width * 0.75 + (drift ? 14 : 0), y: 22)
					if !compact { // the compact banner has no empty bottom corners
						Capsule().fill(.white.opacity(0.14)).frame(width: 74, height: 18).offset(x: geo.size.width * 0.09 + (drift ? 10 : 0), y: geo.size.height - 48)
						Capsule().fill(.white.opacity(0.14)).frame(width: 46, height: 18).offset(x: geo.size.width * 0.80 - (drift ? 8 : 0), y: geo.size.height - 70)
					}
					Icon(.plane, size: 24)
						.rotationEffect(.degrees(90))
						.foregroundStyle(.white.opacity(0.9))
						.offset(x: fly ? geo.size.width + 40 : -40, y: 6)
				}
			}
		}
		.clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
		.overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.onPassport.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [7, 5])).padding(10))
		.overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.passportEdge, lineWidth: 3))
		.background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color.passportEdge).offset(y: 6))
		.popIn()
		.onAppear {
			withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) { fly = true }
			withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) { drift = true }
		}
		.accessibilityElement(children: .combine)
		.accessibilityLabel("Passaporte da viagem: Curitiba, 11 a 18 de novembro de 2026")
	}
}
