import SwiftUI

/// Icon-style menu button for choosing the grid sort order.
struct SortMenuButton: View {
    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        Menu {
            ForEach(LauncherViewModel.SortOption.allCases) { option in
                Button {
                    viewModel.setSortOption(option)
                } label: {
                    if viewModel.sortOption == option {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Sort order")
    }
}
