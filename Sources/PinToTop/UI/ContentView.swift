import SwiftUI

struct ContentView: View {
    @ObservedObject var model: MirrorModel

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            windowList
            controls
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            while !Task.isCancelled {
                await model.refreshWindows()
                do { try await Task.sleep(nanoseconds: 1_500_000_000) } catch { return }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pin To Top")
                    .font(.title2.bold())
                Text("Keep one window pinned above your work.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { Task { await model.refreshWindows() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh the list of open app windows")
        }
    }

    private var windowList: some View {
        Group {
            if model.windows.isEmpty {
                ContentUnavailableView("No app windows found", systemImage: "macwindow", description: Text("Open a window, then refresh this list."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(model.windows) { choice in
                            WindowPreviewCard(model: model, choice: choice, selected: model.selectedID == choice.id) {
                                model.select(choice)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.isMirroring {
                Button(role: .destructive) { Task { await model.stop() } } label: {
                    Label("Unpin", systemImage: "pin.slash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            } else {
                Button { Task { await model.start() } } label: {
                    Label("Pin", systemImage: "pin")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(model.selectedWindow == nil)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(model.isMirroring ? .green : .secondary)
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if let source = model.sourceDescription {
                        Text(source)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Text("Video only. Keep the pinned window open.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }
}
