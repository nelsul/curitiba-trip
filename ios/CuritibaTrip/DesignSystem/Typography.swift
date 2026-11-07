import SwiftUI

/// Fredoka for titles and buttons, Nunito for text, the same as the web app.
/// Sizes follow the iPhone's text-size setting (Dynamic Type) through `relativeTo`.
extension Font {
	enum DisplayWeight { case medium, semibold }
	enum BodyWeight { case regular, bold, extraBold }

	static func display(_ size: CGFloat, _ weight: DisplayWeight = .semibold, relativeTo style: TextStyle = .title3) -> Font {
		.custom(weight == .medium ? "Fredoka-Medium" : "Fredoka-SemiBold", size: size, relativeTo: style)
	}

	static func text(_ size: CGFloat = 16, _ weight: BodyWeight = .regular, relativeTo style: TextStyle = .body) -> Font {
		let name = switch weight {
		case .regular: "Nunito-Regular"
		case .bold: "Nunito-Bold"
		case .extraBold: "Nunito-ExtraBold"
		}
		return .custom(name, size: size, relativeTo: style)
	}
}
