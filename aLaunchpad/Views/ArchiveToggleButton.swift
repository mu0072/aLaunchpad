import SwiftUI

/// Top-right toolbar button that toggles between the main grid and the
/// archived-apps grid. Styled to match `SortMenuButton` so the two sit
/// flush in the search row.
struct ArchiveToggleButton: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        let active = viewModel.isShowingArchive
        Button {
            viewModel.setShowingArchive(!active)
        } label: {
            Image(systemName: active ? "archivebox.fill" : "archivebox")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(active ? 0.95 : 0.75))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(active ? 0.20 : 0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(active ? "返回主视图" : "查看归档")
    }
}
