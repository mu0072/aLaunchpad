import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: LauncherViewModel
    var onClose: () -> Void

    @FocusState private var searchFocused: Bool

    /// Same radius macOS uses on regular app windows — fits the "zoomed app
    /// window" look (visibleFrame size) better than the larger panel radius.
    private let panelCornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            // Visual layer — purely decorative, doesn't intercept clicks so
            // background taps fall through to the click-eater below.
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .overlay(Color.black.opacity(0.25))
                .allowsHitTesting(false)

            // Click-eater layer — fills the entire rounded panel and consumes
            // any tap that doesn't land on a real control. Same logic as Esc
            // and successful app launch: just hide the launcher.
            Color.white.opacity(0.0001)
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            // Content layer — search row + paged grid + error banner.
            VStack(spacing: 28) {
                searchRow
                    .padding(.top, 36)
                    .padding(.horizontal, 80)

                AppGridView(viewModel: viewModel, onLaunch: handleLaunch)
                    .padding(.horizontal, 96)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let err = viewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(err)
                    }
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.red.opacity(0.75))
                    )
                    .padding(.bottom, 18)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .ignoresSafeArea()
        .onAppear {
            searchFocused = true
            viewModel.resetSelectionToFirst()
        }
        .onChange(of: viewModel.search) { _ in
            if viewModel.errorMessage != nil { viewModel.errorMessage = nil }
            viewModel.resetSelectionToFirst()
        }
    }

    private var searchRow: some View {
        ZStack {
            SearchBar(text: $viewModel.search,
                      isFocused: $searchFocused,
                      onSubmit: handleSubmit)
                .frame(maxWidth: 560)

            if viewModel.isShowingArchive {
                HStack {
                    archiveBackCluster
                    Spacer()
                }
            }

            HStack(spacing: 10) {
                Spacer()
                ArchiveToggleButton(viewModel: viewModel)
                SortMenuButton(viewModel: viewModel)
            }
        }
    }

    /// Left-aligned cluster shown in archive view: "← 归档 (N)". Tapping
    /// anywhere on it returns to the main grid.
    private var archiveBackCluster: some View {
        Button {
            viewModel.setShowingArchive(false)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.backward")
                    .font(.system(size: 13, weight: .semibold))
                Text("归档")
                    .font(.system(size: 14, weight: .semibold))
                Text("(\(viewModel.archived.count))")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("返回主视图")
    }

    private func handleSubmit() {
        viewModel.launchSelected(onSuccess: onClose)
    }

    private func handleLaunch(_ app: AppItem) {
        viewModel.launch(app, onSuccess: onClose)
    }
}
