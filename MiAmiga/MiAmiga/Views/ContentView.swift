import SwiftUI
import Translation

struct ContentView: View {
    @State private var model = TranslatorViewModel()
    @State private var showHistory = false

    /// Driving `.translationTask` requires a configuration; recreating it is
    /// what triggers the framework to (re)prepare a session.
    @State private var configuration = TranslationSession.Configuration(
        source: TranslationService.source,
        target: TranslationService.target
    )

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if let fatal = model.fatalMessage {
                    unsupportedView(fatal)
                } else {
                    mainView
                }
            }
            .navigationTitle("Mi Amiga")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("History")
                    .disabled(model.history.isEmpty)
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(model: model)
            }
        }
        // Hands us a live TranslationSession, and presents the system's own
        // language-download sheet the first time es-ES is needed.
        // Hands us a live TranslationSession and presents the system's own
        // language-download sheet the first time es-ES is needed.
        //
        // `TranslationSession` isn't Sendable, so it's used only right here in
        // the closure's own isolation domain — never stored on the model. The
        // closure re-runs whenever `pendingText` changes, which is how a queued
        // phrase gets picked up.
        .translationTask(configuration) { session in
            model.translator.markReady()
            guard let text = model.translator.takePendingText() else { return }

            do {
                let response = try await session.translate(text)
                model.translator.finish(response.targetText)
            } catch {
                model.translator.fail(error.localizedDescription)
            }
        }
        // The task above re-runs when its configuration is invalidated, so a
        // newly queued phrase needs to poke it. Without this the first
        // translation would work and every later one would sit in the queue.
        .onChange(of: model.translator.pendingText) { _, newValue in
            guard newValue != nil else { return }
            configuration.invalidate()
        }
        .task {
            await model.onAppear()
        }
    }

    // MARK: - Main

    private var mainView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    if let current = model.current {
                        PhraseCard(
                            english: current.english,
                            spanish: current.spanish,
                            isSpeaking: model.isSpeaking,
                            isTranslating: model.stage == .translating,
                            onSpeak: { model.speakCurrent() },
                            onStop: { model.stopSpeaking() },
                            onRetry: { Task { await model.retryTranslation() } }
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.96).combined(with: .opacity),
                            removal: .opacity
                        ))
                    } else if model.stage == .listening {
                        listeningCard
                    } else {
                        emptyState
                    }

                    if let error = model.errorMessage {
                        errorBanner(error)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .animation(.spring(duration: 0.35), value: model.current)
                .animation(.spring(duration: 0.3), value: model.stage)
            }
            .scrollDismissesKeyboard(.immediately)

            micArea
        }
    }

    private var listeningCard: some View {
        VStack(spacing: 14) {
            Text("Listening…")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)

            Text(model.livePartial.isEmpty ? "Say something in English" : model.livePartial)
                .font(.system(.title2, design: .rounded))
                .foregroundStyle(model.livePartial.isEmpty ? .secondary : .primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.default, value: model.livePartial)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "character.bubble")
                .font(.system(size: 52))
                .foregroundStyle(Color.miAmiga.opacity(0.55))
                .padding(.bottom, 4)

            Text("Hold the mic and speak")
                .font(.title3.weight(.semibold))

            Text("Say a phrase in English and it'll come back in Spanish, ready to read out loud.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
    }

    private var micArea: some View {
        VStack(spacing: 10) {
            MicButton(
                isListening: model.stage == .listening,
                level: model.audioLevel,
                onPress: { Task { await model.beginListening() } },
                onRelease: { Task { await model.endListeningAndTranslate() } }
            )

            Text(model.stage == .listening ? "Release to translate" : "Hold to speak")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .animation(.none, value: model.stage)
        }
        .padding(.bottom, 12)
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func unsupportedView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Translation unavailable", systemImage: "globe.badge.chevron.backward")
        } description: {
            Text(message)
        }
    }
}

#Preview {
    ContentView()
}
