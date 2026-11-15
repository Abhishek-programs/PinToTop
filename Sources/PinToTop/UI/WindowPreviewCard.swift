import SwiftUI

struct WindowPreviewCard: View {
    enum Style {
        case regular
        case compact

        var imageHeight: CGFloat { self == .compact ? 72 : 96 }
        var padding: CGFloat { self == .compact ? 6 : 8 }
        var corner: CGFloat { self == .compact ? 10 : 12 }
        var icon: CGFloat { self == .compact ? 18 : 22 }
    }

    @ObservedObject var model: MirrorModel
    let choice: WindowChoice
    let selected: Bool
    var style: Style = .regular
    let action: () -> Void
    @StateObject private var previewModel = WindowPreviewModel()

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: style == .compact ? 5 : 7) {
                ZStack(alignment: .bottomTrailing) {
                    previewImage
                        .frame(maxWidth: .infinity)
                        .frame(height: style.imageHeight)
                        .clipped()

                    Image(nsImage: choice.appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: style.icon, height: style.icon)
                        .padding(3)
                        .background(.background, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.primary.opacity(0.08), lineWidth: 1))
                        .padding(5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 1) {
                    Text(choice.title)
                        .font(style == .compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(choice.app)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(style.padding)
            .background(selected ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: style.corner))
            .overlay {
                RoundedRectangle(cornerRadius: style.corner)
                    .stroke(selected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .task(id: choice.id) {
            while !Task.isCancelled {
                if let nextImage = await model.capturePreview(for: choice) {
                    previewModel.image = nextImage
                    previewModel.hasAttemptedCapture = true
                } else {
                    previewModel.hasAttemptedCapture = true
                }
                do { try await Task.sleep(nanoseconds: 1_250_000_000) } catch { return }
            }
        }
    }

    @ViewBuilder
    private var previewImage: some View {
        if let previewImage = previewModel.image {
            Image(nsImage: previewImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if previewModel.hasAttemptedCapture {
            ZStack {
                Rectangle().fill(.quaternary)
                Image(systemName: "rectangle.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            ZStack {
                Rectangle().fill(.quaternary)
                ProgressView().controlSize(.small)
            }
        }
    }
}

@MainActor
private final class WindowPreviewModel: ObservableObject {
    @Published var image: NSImage?
    @Published var hasAttemptedCapture = false
}
