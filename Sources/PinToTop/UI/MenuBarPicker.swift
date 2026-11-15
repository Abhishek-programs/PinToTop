import AppKit
import SwiftUI

struct MenuBarPicker: View {
    @ObservedObject var model: MirrorModel
    @Environment(\.openWindow) private var openWindow

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Pin To Top", systemImage: "pin")
                    .font(.headline)
                Spacer()
                Button { Task { await model.refreshWindows() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh windows")
            }

            windowPreviews
            if model.isMirroring {
                Button(role: .destructive) { Task { await model.stop() } } label: {
                    Label("Unpin", systemImage: "pin.slash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button { Task { await model.start() } } label: {
                    Label("Pin", systemImage: "pin")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.selectedWindow == nil)
            }

            Text(model.status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button {
                    model.presentHelperWindow { openWindow(id: "main") }
                } label: {
                    Label("Open Window", systemImage: "macwindow")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(role: .destructive) {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(12)
        .frame(width: 460)
        .background {
            Color(nsColor: .windowBackgroundColor)
            MenuPanelAppearance()
        }
        .onAppear {
            Task { await model.refreshWindows() }
        }
    }

    private var windowPreviews: some View {
        let row = MenuPreviewMetrics.rowHeight
        let spacing = MenuPreviewMetrics.rowSpacing
        return Group {
            if model.windows.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "macwindow")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("No windows open")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: row)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: spacing) {
                        ForEach(model.windows) { choice in
                            WindowPreviewCard(
                                model: model,
                                choice: choice,
                                selected: model.selectedID == choice.id,
                                style: .compact
                            ) {
                                model.select(choice)
                            }
                        }
                    }
                }
                .frame(height: row * 2 + spacing)
            }
        }
    }
}

private enum MenuPreviewMetrics {
    static let rowHeight: CGFloat = 128
    static let rowSpacing: CGFloat = 8
}

private struct MenuPanelAppearance: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { PanelAppearanceView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? PanelAppearanceView)?.apply()
    }
}

private final class PanelAppearanceView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        apply()
    }

    func apply() {
        guard let window else { return }
        let fill = NSColor.windowBackgroundColor
        window.backgroundColor = fill
        window.isOpaque = true
        guard let content = window.contentView else { return }
        func walk(_ view: NSView) {
            if let effect = view as? NSVisualEffectView {
                effect.material = .windowBackground
                effect.blendingMode = .withinWindow
                effect.state = .active
            }
            view.subviews.forEach(walk)
        }
        walk(content)
    }
}
