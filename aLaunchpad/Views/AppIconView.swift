import SwiftUI
import AppKit

struct AppIconView: View {
    let app: AppItem
    let isSelected: Bool
    @ObservedObject var viewModel: LauncherViewModel
    var onLaunch: (AppItem) -> Void

    @State private var iconImage: NSImage?
    @State private var isHovering = false

    var body: some View {
        let archived = viewModel.isArchived(app)
        // Mouse-hover only — overlaying on the keyboard-selected cell looked
        // visually noisy and competed with the selection ring.
        let showArchiveButton = isHovering

        VStack(spacing: 8) {
            ZStack {
                if let icon = iconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.white.opacity(0.10))
                }
            }
            .frame(width: 88, height: 88)
            .opacity(archived ? 0.55 : 1.0)
            .overlay(alignment: .bottomTrailing) {
                // Corner badge so archived apps surfacing through main-view
                // search are visually distinct from regular results.
                if archived && !viewModel.isShowingArchive {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(.black.opacity(0.6)))
                        .offset(x: 2, y: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                if showArchiveButton {
                    Button {
                        viewModel.toggleArchive(app)
                    } label: {
                        Image(systemName: archived ? "tray.and.arrow.up.fill" : "archivebox")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(.black.opacity(0.6)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(archived ? "取消归档" : "归档")
                    .offset(x: 6, y: -6)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }

            Text(app.name)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.tail)
                // Fixed-height label so every row is the same height — required
                // for the parent's dynamic row-spacing math to land evenly.
                .frame(width: 118, height: 30, alignment: .top)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.18) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.45) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onLaunch(app) }
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .contextMenu {
            if viewModel.favorites.contains(app.id) {
                Button("Remove from Favorites") { viewModel.toggleFavorite(app) }
            } else {
                Button("Add to Favorites") { viewModel.toggleFavorite(app) }
            }
            if archived {
                Button("取消归档") { viewModel.setArchived(app, false) }
            } else {
                Button("归档") { viewModel.setArchived(app, true) }
            }
            Divider()
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([app.url])
            }
        }
        .task(id: app.id) {
            self.iconImage = IconCache.icon(for: app.url)
        }
    }
}
