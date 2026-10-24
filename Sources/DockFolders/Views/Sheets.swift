import SwiftUI

/// Live log while applying / removing, then a summary.
struct ProgressSheet: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                if model.progress.isRunning {
                    ProgressView().controlSize(.small)
                } else if model.progress.error != nil {
                    Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                } else {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
                Text(model.progress.title).font(.headline)
                Spacer()
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(model.progress.log.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.callout, design: .monospaced))
                                .foregroundStyle(style(for: line))
                                .textSelection(.enabled)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor)))
                .frame(height: 300)
                .onChange(of: model.progress.log.count) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }

            if let error = model.progress.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            if let report = model.progress.report {
                summary(report)
            }

            HStack {
                if let url = model.progress.report?.backup {
                    Text("\(L("Backup")): \(Paths.abbreviate(url.path))")
                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Spacer()
                Button(L("Done")) { model.showProgressSheet = false }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(model.progress.isRunning)
            }
        }
        .padding(20)
        .frame(width: 600)
    }

    @ViewBuilder
    private func summary(_ report: Organizer.Report) -> some View {
        let missing = report.missingApps
        if !missing.isEmpty || !report.missingFavorites.isEmpty || !report.iconFailures.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label(L("Some apps are not installed and were skipped:"), systemImage: "info.circle")
                    .font(.callout)
                ForEach(missing, id: \.folder) { m in
                    Text("• \(m.folder): \(m.apps.joined(separator: ", "))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !report.missingFavorites.isEmpty {
                    Text("• \(L("Favorites")): \(report.missingFavorites.joined(separator: ", "))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !report.iconFailures.isEmpty {
                    Text("• \(L("Icon could not be set")): \(report.iconFailures.joined(separator: ", "))")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        } else if let b = report.build {
            Label("\(b.totalLinked) \(L("apps in")) \(b.folders.count) \(L("folders")) — \(L("all apps found"))", systemImage: "checkmark.seal")
                .font(.callout)
        }
    }

    private func style(for line: String) -> AnyShapeStyle {
        if line.hasPrefix("▸") { return AnyShapeStyle(.primary) }
        if line.hasPrefix("✓") { return AnyShapeStyle(.green) }
        if line.contains("  !") { return AnyShapeStyle(.orange) }
        if line.contains("  −") || line.contains("  ·") { return AnyShapeStyle(.secondary) }
        return AnyShapeStyle(.primary)
    }
}

/// First-run: pick a preset, start empty, or import a v1 config.
struct OnboardingSheet: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                IconPreview(spec: IconRenderer.appIconSpec, size: 72)
                Text(L("Welcome to DockFolders")).font(.largeTitle.weight(.bold))
                Text(L("Tidy your Dock into category folders with custom icons. Start from a preset — you can change everything afterwards."))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 460)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Presets.all) { p in
                    Button {
                        model.loadPreset(p, replace: true)
                        model.showOnboarding = false
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Text(p.emoji).font(.system(size: 30))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(p.name).font(.headline)
                                Text(L(p.description)).font(.caption).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                Text("\(p.folders.count) \(L("folders"))").font(.caption2).foregroundStyle(.tertiary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor)))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 12) {
                Button(L("Import config.sh (v1)…")) {
                    if let url = Panels.chooseFile(title: L("Choose a DockFolders v1 config.sh"), types: ["sh"]) {
                        model.importLegacy(url: url)
                        model.showOnboarding = false
                    }
                }
                Spacer()
                Button(L("Start Empty")) {
                    model.startEmpty()
                    model.showOnboarding = false
                }
            }
        }
        .padding(28)
        .frame(width: 640)
    }
}
