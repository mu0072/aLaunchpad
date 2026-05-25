import SwiftUI
import AppKit

/// Icon-style menu button for choosing the grid sort order. The button face
/// shows the currently active mode's bespoke PNG (cropped from the user's
/// sprite sheet); the dropdown shows each mode's icon + localized label.
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
            ZStack {
                sortIconImage(for: viewModel.sortOption)
            }
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
        .help(viewModel.sortOption.label)
        .animation(.easeOut(duration: 0.18), value: viewModel.sortOption)
    }

    /// Bundle-loaded PNG → SwiftUI Image at the precise display size we want
    /// (24×22pt). We set `NSImage.size` explicitly so SwiftUI uses that as
    /// the intrinsic size — `.resizable()` chained with the Menu's label
    /// area was unreliable, letting the PNG's native 266×189 pixel size leak
    /// through and produce a giant button.
    private func sortIconImage(for option: LauncherViewModel.SortOption) -> Image {
        if let ns = NSImage(named: option.iconAssetName) {
            ns.size = NSSize(width: 24, height: 22)
            return Image(nsImage: ns)
        }
        return Image(systemName: "arrow.up.arrow.down")
    }
}
