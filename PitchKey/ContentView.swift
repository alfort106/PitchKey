//
//  ContentView.swift
//  PitchKey
//
//  Created by arakawa hinata on 2026/06/11.
//

import AVFoundation
import Combine
import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var audioEngine = PianoAudioEngine()
    @State private var isKeyboardLocked = UserDefaults.standard.bool(forKey: SettingsKey.isKeyboardLocked)
    @State private var transpose = UserDefaults.standard.object(forKey: SettingsKey.transpose) as? Int ?? 0
    @State private var a4Frequency = UserDefaults.standard.object(forKey: SettingsKey.a4Frequency) as? Int ?? 440
    @State private var keyWidthScale = UserDefaults.standard.object(forKey: SettingsKey.keyWidthScale) as? Double ?? 1.0
    @State private var outputVolume = UserDefaults.standard.object(forKey: SettingsKey.outputVolume) as? Double ?? 1.0
    @State private var selectedTone = PianoTone(rawValue: UserDefaults.standard.string(forKey: SettingsKey.selectedTone) ?? "") ?? .synth
    @State private var isAdjustingKeyWidth = false
    @State private var keyWidthAdjustmentID = 0
    @State private var showsAdjustmentPanel = false

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let portraitKeyboardHeight = min(geometry.size.height * 0.48, max(260, geometry.size.height - 330))
            let topPadding: CGFloat = isLandscape ? 12 : 70
            let bottomBreathingRoom: CGFloat = isLandscape ? 12 : 28

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    AdjustmentPanelToggle(isPresented: $showsAdjustmentPanel)
                        .padding(.horizontal, isLandscape ? 18 : 14)
                        .padding(.top, topPadding)
                        .padding(.bottom, 8)

                    ControlBar(
                        isKeyboardLocked: $isKeyboardLocked,
                        transpose: $transpose,
                        a4Frequency: $a4Frequency,
                        selectedTone: $selectedTone,
                        showsMusicButton: isLandscape,
                        usesIconOnlyPrimaryControls: !isLandscape
                    )
                    .padding(.horizontal, isLandscape ? 18 : 14)
                    .padding(.bottom, isLandscape ? 10 : 8)

                    PianoKeyboardView(
                        isLocked: isKeyboardLocked,
                        transpose: transpose,
                        a4Frequency: a4Frequency,
                        selectedTone: selectedTone,
                        keyWidthScale: keyWidthScale,
                        isAdjustingKeyWidth: isAdjustingKeyWidth,
                        keyWidthAdjustmentID: keyWidthAdjustmentID,
                        audioEngine: audioEngine
                    )
                        .frame(maxWidth: .infinity)
                        .frame(height: isLandscape ? nil : portraitKeyboardHeight)
                        .padding(.horizontal, isLandscape ? 18 : 0)

                    if !isLandscape {
                        AppleMusicLaunchButton()
                            .frame(width: 120, height: 100)
                            .padding(.top, 27)
                    }

                    Spacer(minLength: bottomBreathingRoom)
                }

                if showsAdjustmentPanel {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showsAdjustmentPanel = false
                        }

                    AdjustmentPanel(
                        keyWidthScale: $keyWidthScale,
                        outputVolume: $outputVolume,
                        onKeyWidthEditingChanged: { isEditing in
                            if isEditing {
                                keyWidthAdjustmentID += 1
                            }

                            isAdjustingKeyWidth = isEditing
                        }
                    )
                    .padding(.horizontal, isLandscape ? 18 : 14)
                    .padding(.top, topPadding + 46)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
                }
            }
            .background(AppColors.background)
            .preferredColorScheme(.dark)
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: showsAdjustmentPanel)
            .onAppear {
                UIScrollView.appearance().showsHorizontalScrollIndicator = false
                audioEngine.setOutputVolume(outputVolume)
                audioEngine.prepareSession(transpose: transpose, a4Frequency: a4Frequency)
            }
            .onChange(of: isKeyboardLocked) { _, newValue in
                persist(newValue, forKey: SettingsKey.isKeyboardLocked)
            }
            .onChange(of: transpose) { _, newValue in
                persist(newValue, forKey: SettingsKey.transpose)
                audioEngine.prepareSynthBuffers(transpose: newValue, a4Frequency: a4Frequency)
            }
            .onChange(of: a4Frequency) { _, newValue in
                persist(newValue, forKey: SettingsKey.a4Frequency)
                audioEngine.prepareSynthBuffers(transpose: transpose, a4Frequency: newValue)
            }
            .onChange(of: keyWidthScale) { _, newValue in
                persist(newValue, forKey: SettingsKey.keyWidthScale)
            }
            .onChange(of: outputVolume) { _, newValue in
                persist(newValue, forKey: SettingsKey.outputVolume)
                audioEngine.setOutputVolume(newValue)
            }
            .onChange(of: selectedTone) { _, newValue in
                persist(newValue.rawValue, forKey: SettingsKey.selectedTone)
                if newValue == .synth {
                    audioEngine.prepareSynthBuffers(transpose: transpose, a4Frequency: a4Frequency)
                }
            }
        }
    }

    private func persist(_ value: Bool, forKey key: String) {
        DispatchQueue.global(qos: .utility).async {
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    private func persist(_ value: Int, forKey key: String) {
        DispatchQueue.global(qos: .utility).async {
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    private func persist(_ value: Double, forKey key: String) {
        DispatchQueue.global(qos: .utility).async {
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    private func persist(_ value: String, forKey key: String) {
        DispatchQueue.global(qos: .utility).async {
            UserDefaults.standard.set(value, forKey: key)
        }
    }
}

private enum SettingsKey {
    static let isKeyboardLocked = "pitchKey.isKeyboardLocked"
    static let transpose = "pitchKey.transpose"
    static let a4Frequency = "pitchKey.a4Frequency"
    static let keyWidthScale = "pitchKey.keyWidthScale"
    static let outputVolume = "pitchKey.outputVolume"
    static let selectedTone = "pitchKey.selectedTone"
}

private enum PianoTone: String, CaseIterable, Identifiable {
    case synth
    case samplePiano

    var id: String { rawValue }

    var title: String {
        switch self {
        case .synth:
            "Synth"
        case .samplePiano:
            "Sample Piano"
        }
    }

    var systemImage: String {
        switch self {
        case .synth:
            "waveform"
        case .samplePiano:
            "pianokeys"
        }
    }
}

private struct AdjustmentPanelToggle: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .bold))

                Text("Adjust")
                    .font(.system(size: 13, weight: .bold, design: .rounded))

                Spacer(minLength: 0)

                Image(systemName: isPresented ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.secondaryText)
            }
            .foregroundStyle(AppColors.primaryText)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(AppColors.controlSurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.whiteKeyBorder.opacity(0.45), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Adjust keyboard and volume")
    }
}

private struct AdjustmentPanel: View {
    @Binding var keyWidthScale: Double
    @Binding var outputVolume: Double
    let onKeyWidthEditingChanged: (Bool) -> Void

    var body: some View {
        VStack(spacing: 10) {
            KeyWidthSlider(value: $keyWidthScale, onEditingChanged: onKeyWidthEditingChanged)
            VolumeSlider(value: $outputVolume)
        }
        .padding(10)
        .background(AppColors.panelSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.whiteKeyBorder.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
    }
}

private struct KeyWidthSlider: View {
    @Binding var value: Double
    let onEditingChanged: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "minus")
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)

            Slider(value: $value, in: 0.7...1.6, onEditingChanged: onEditingChanged)
                .tint(AppColors.controlAccent)

            Image(systemName: "plus")
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
        }
        .foregroundStyle(AppColors.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.controlSurface, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Key width")
    }
}

private struct VolumeSlider: View {
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.wave.1")
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)

            Slider(value: $value, in: 0...1)
                .tint(AppColors.controlAccent)

            Text("\(Int((value * 100).rounded()))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
        }
        .foregroundStyle(AppColors.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.controlSurface, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Volume")
    }
}

private struct ControlBar: View {
    @Environment(\.openURL) private var openURL

    @Binding var isKeyboardLocked: Bool
    @Binding var transpose: Int
    @Binding var a4Frequency: Int
    @Binding var selectedTone: PianoTone
    let showsMusicButton: Bool
    let usesIconOnlyPrimaryControls: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            controls

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    modeToggle
                    toneMenu

                    if showsMusicButton {
                        musicButton
                    }
                }

                HStack(spacing: 10) {
                    keyStepper
                    a4Stepper
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: usesIconOnlyPrimaryControls ? 8 : 12) {
            modeToggle
            toneMenu

            if showsMusicButton {
                musicButton
            }

            keyStepper
            a4Stepper
        }
        .controlSize(.small)
    }

    private var modeToggle: some View {
        Toggle(isOn: $isKeyboardLocked) {
            if usesIconOnlyPrimaryControls {
                Image(systemName: isKeyboardLocked ? "lock.fill" : "arrow.left.and.right")
                    .frame(width: 34, height: 34)
            } else {
                Label(isKeyboardLocked ? "Lock" : "Scroll", systemImage: isKeyboardLocked ? "lock.fill" : "arrow.left.and.right")
            }
        }
        .toggleStyle(.button)
        .buttonStyle(.borderedProminent)
        .tint(isKeyboardLocked ? AppColors.controlAccent : AppColors.controlNeutral)
        .accessibilityLabel(isKeyboardLocked ? "Lock" : "Scroll")
    }

    private var toneMenu: some View {
        Menu {
            ForEach(PianoTone.allCases) { tone in
                Button {
                    selectedTone = tone
                } label: {
                    Label(tone.title, systemImage: tone == selectedTone ? "checkmark" : tone.systemImage)
                }
            }
        } label: {
            if usesIconOnlyPrimaryControls {
                Image(systemName: selectedTone.systemImage)
                    .frame(width: 34, height: 34)
            } else {
                Label(selectedTone.title, systemImage: selectedTone.systemImage)
            }
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Tone")
    }

    private var musicButton: some View {
        Button {
            openAppleMusic()
        } label: {
            if usesIconOnlyPrimaryControls {
                Image(systemName: "music.note")
                    .frame(width: 28, height: 28)
            } else {
                Label("Music", systemImage: "music.note")
            }
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Apple Music")
    }

    private var keyStepper: some View {
        ValueStepper(
            title: "Key",
            value: signed(transpose),
            isCompact: usesIconOnlyPrimaryControls,
            decrement: { transpose = max(transpose - 1, -12) },
            increment: { transpose = min(transpose + 1, 12) }
        )
    }

    private var a4Stepper: some View {
        ValueStepper(
            title: "A4",
            value: "\(a4Frequency)Hz",
            isCompact: usesIconOnlyPrimaryControls,
            decrement: { a4Frequency = max(a4Frequency - 1, 415) },
            increment: { a4Frequency = min(a4Frequency + 1, 466) }
        )
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func openAppleMusic() {
        guard let musicURL = URL(string: "music://") else { return }

        openURL(musicURL) { accepted in
            guard !accepted, let fallbackURL = URL(string: "https://music.apple.com") else { return }
            openURL(fallbackURL)
        }
    }
}

private struct ValueStepper: View {
    let title: String
    let value: String
    let isCompact: Bool
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: isCompact ? 4 : 6) {
            StepperTapButton(systemName: "minus", size: isCompact ? 34 : 40, action: decrement)

            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)

                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: labelWidth)

            StepperTapButton(systemName: "plus", size: isCompact ? 34 : 40, action: increment)
        }
        .padding(.horizontal, isCompact ? 4 : 6)
        .padding(.vertical, isCompact ? 4 : 5)
        .background(AppColors.controlSurface, in: RoundedRectangle(cornerRadius: 7))
    }

    private var labelWidth: CGFloat {
        if title == "A4" {
            return isCompact ? 52 : 66
        }

        return isCompact ? 36 : 50
    }
}

private struct StepperTapButton: View {
    let systemName: String
    let size: CGFloat
    let action: () -> Void
    @GestureState private var isPressed = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(AppColors.primaryText)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isPressed ? AppColors.controlAccent.opacity(0.55) : AppColors.controlInset)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
                    .onEnded { _ in
                        action()
                    }
            )
            .accessibilityAddTraits(.isButton)
    }
}

private struct AppleMusicLaunchButton: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openAppleMusic()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "music.note")
                    .font(.system(size: 32, weight: .semibold))

                Text("Music")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .foregroundStyle(AppColors.primaryText)
        .background(AppColors.controlSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.whiteKeyBorder.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
        .accessibilityLabel("Apple Music")
    }

    private func openAppleMusic() {
        guard let musicURL = URL(string: "music://") else { return }

        openURL(musicURL) { accepted in
            guard !accepted, let fallbackURL = URL(string: "https://music.apple.com") else { return }
            openURL(fallbackURL)
        }
    }
}

private struct PianoKeyboardView: View {
    let isLocked: Bool
    let transpose: Int
    let a4Frequency: Int
    let selectedTone: PianoTone
    let keyWidthScale: Double
    let isAdjustingKeyWidth: Bool
    let keyWidthAdjustmentID: Int
    let audioEngine: PianoAudioEngine
    @State private var pressedKeyIDs: Set<Int> = []

    private let initialCenterKeyID = 62
    private let keys = PianoKey.fullKeyboard

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let baseWhiteKeyWidth = max(isLandscape ? 34 : 42, geometry.size.width / (isLandscape ? 18 : 9))
            let whiteKeyWidth = baseWhiteKeyWidth * keyWidthScale
            let blackKeyWidth = whiteKeyWidth * 0.62
            let keyboardWidth = whiteKeyWidth * CGFloat(keys.filter { !$0.isBlack }.count)

            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(keys.filter { !$0.isBlack }) { key in
                                WhitePianoKey(
                                    key: key,
                                    isLocked: isLocked,
                                    isPressed: pressedKeyIDs.contains(key.id),
                                    transpose: transpose,
                                    a4Frequency: a4Frequency,
                                    selectedTone: selectedTone,
                                    audioEngine: audioEngine
                                )
                                .frame(width: whiteKeyWidth, height: geometry.size.height)
                                .id(key.id)
                            }
                        }

                        ForEach(keys.filter { $0.isBlack }) { key in
                            BlackPianoKey(
                                key: key,
                                isLocked: isLocked,
                                isPressed: pressedKeyIDs.contains(key.id),
                                transpose: transpose,
                                a4Frequency: a4Frequency,
                                selectedTone: selectedTone,
                                audioEngine: audioEngine
                            )
                            .frame(width: blackKeyWidth, height: geometry.size.height * 0.62)
                            .offset(x: blackKeyXOffset(for: key, whiteKeyWidth: whiteKeyWidth, blackKeyWidth: blackKeyWidth))
                        }

                        if isLocked {
                            MultiTouchKeyboardOverlay(
                                keys: keys,
                                whiteKeyWidth: whiteKeyWidth,
                                blackKeyWidth: blackKeyWidth,
                                blackKeyHeight: geometry.size.height * 0.62,
                                transpose: transpose,
                                a4Frequency: a4Frequency,
                                selectedTone: selectedTone,
                                audioEngine: audioEngine,
                                pressedKeyIDs: $pressedKeyIDs
                            )
                            .frame(width: keyboardWidth, height: geometry.size.height)
                        }

                        if !isLocked {
                            ScrollTouchKeyboardObserver(
                                keys: keys,
                                whiteKeyWidth: whiteKeyWidth,
                                blackKeyWidth: blackKeyWidth,
                                blackKeyHeight: geometry.size.height * 0.62,
                                transpose: transpose,
                                a4Frequency: a4Frequency,
                                selectedTone: selectedTone,
                                audioEngine: audioEngine,
                                pressedKeyIDs: $pressedKeyIDs
                            )
                            .frame(width: keyboardWidth, height: geometry.size.height)
                        }

                        KeyboardWidthScrollPositionKeeper(
                            whiteKeyWidth: whiteKeyWidth,
                            keyboardWidth: keyboardWidth,
                            isAdjusting: isAdjustingKeyWidth,
                            adjustmentID: keyWidthAdjustmentID
                        )
                        .frame(width: 0, height: 0)
                    }
                    .frame(width: keyboardWidth, height: geometry.size.height, alignment: .topLeading)
                    .padding(.vertical, 2)
                }
                .scrollDisabled(isLocked)
                .scrollIndicators(.hidden)
                .onAppear {
                    scrollToInitialCenter(using: scrollProxy)
                }
                .overlay {
                    if !isLocked {
                        ScrollAffordance()
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.keyboardDeck)
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                )
                .onChange(of: isLocked) { _, newValue in
                    guard !newValue else { return }
                    pressedKeyIDs.removeAll()
                }
            }
        }
    }

    private func scrollToInitialCenter(using scrollProxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            scrollProxy.scrollTo(initialCenterKeyID, anchor: .center)
        }
    }

    private func blackKeyXOffset(for key: PianoKey, whiteKeyWidth: CGFloat, blackKeyWidth: CGFloat) -> CGFloat {
        let whiteBefore = PianoKey.fullKeyboard.filter { !$0.isBlack && $0.midi < key.midi }.count
        return CGFloat(whiteBefore) * whiteKeyWidth - (blackKeyWidth / 2)
    }
}

private struct WhitePianoKey: View {
    let key: PianoKey
    let isLocked: Bool
    let isPressed: Bool
    let transpose: Int
    let a4Frequency: Int
    let selectedTone: PianoTone
    let audioEngine: PianoAudioEngine

    var body: some View {
        if isLocked {
            whiteKeyLabel
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isPressed ? AppColors.whiteKeyPressed : AppColors.whiteKey)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(AppColors.whiteKeyBorder, lineWidth: 1)
                )
                .contentShape(Rectangle())
        } else {
            whiteKeyLabel
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isPressed ? AppColors.whiteKeyPressed : AppColors.whiteKey)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(AppColors.whiteKeyBorder, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
    }

    private var whiteKeyLabel: some View {
        ZStack(alignment: .bottom) {
            if let label = key.displayLabel {
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.keyLabel)
                    .padding(.bottom, 18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

private struct BlackPianoKey: View {
    let key: PianoKey
    let isLocked: Bool
    let isPressed: Bool
    let transpose: Int
    let a4Frequency: Int
    let selectedTone: PianoTone
    let audioEngine: PianoAudioEngine

    var body: some View {
        if isLocked {
            blackKeyLabel
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 3,
                        bottomLeadingRadius: 5,
                        bottomTrailingRadius: 5,
                        topTrailingRadius: 3
                    )
                    .fill(isPressed ? AppColors.blackKeyPressed : AppColors.blackKey)
                    .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 3)
                )
                .contentShape(Rectangle())
        } else {
            blackKeyLabel
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 3,
                        bottomLeadingRadius: 5,
                        bottomTrailingRadius: 5,
                        topTrailingRadius: 3
                    )
                    .fill(isPressed ? AppColors.blackKeyPressed : AppColors.blackKey)
                    .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 3)
                )
                .contentShape(Rectangle())
        }
    }

    private var blackKeyLabel: some View {
        ZStack(alignment: .bottom) {
            EmptyView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct KeyboardWidthScrollPositionKeeper: UIViewRepresentable {
    let whiteKeyWidth: CGFloat
    let keyboardWidth: CGFloat
    let isAdjusting: Bool
    let adjustmentID: Int

    func makeUIView(context: Context) -> KeyboardWidthScrollPositionKeeperUIView {
        let view = KeyboardWidthScrollPositionKeeperUIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: KeyboardWidthScrollPositionKeeperUIView, context: Context) {
        uiView.configure(
            whiteKeyWidth: whiteKeyWidth,
            keyboardWidth: keyboardWidth,
            isAdjusting: isAdjusting,
            adjustmentID: adjustmentID
        )
    }
}

private final class KeyboardWidthScrollPositionKeeperUIView: UIView {
    private var previousWhiteKeyWidth: CGFloat?
    private var activeAnchorWhiteKeyPosition: CGFloat?
    private var activeAdjustmentID: Int?
    private weak var observedScrollView: UIScrollView?

    func configure(
        whiteKeyWidth: CGFloat,
        keyboardWidth: CGFloat,
        isAdjusting: Bool,
        adjustmentID: Int
    ) {
        attachScrollViewIfNeeded()

        guard let scrollView = observedScrollView else {
            previousWhiteKeyWidth = whiteKeyWidth
            return
        }

        if isAdjusting {
            if activeAdjustmentID != adjustmentID {
                activeAdjustmentID = adjustmentID
                activeAnchorWhiteKeyPosition = nearestWhiteKeyCenterPosition(in: scrollView, whiteKeyWidth: whiteKeyWidth)
            }

            preserveAnchor(
                whiteKeyWidth: whiteKeyWidth,
                keyboardWidth: keyboardWidth,
                scrollView: scrollView
            )
        } else {
            activeAdjustmentID = nil
            activeAnchorWhiteKeyPosition = nil
        }

        previousWhiteKeyWidth = whiteKeyWidth
    }

    private func preserveAnchor(
        whiteKeyWidth: CGFloat,
        keyboardWidth: CGFloat,
        scrollView: UIScrollView
    ) {
        guard
            let previousWhiteKeyWidth,
            previousWhiteKeyWidth > 0,
            let anchorPosition = activeAnchorWhiteKeyPosition
        else { return }

        let viewportCenterX = scrollView.contentOffset.x + (scrollView.bounds.width / 2)
        let anchorIndex = anchorPosition / previousWhiteKeyWidth
        let newAnchorPosition = anchorIndex * whiteKeyWidth
        let delta = newAnchorPosition - viewportCenterX
        let maxOffset = max(0, keyboardWidth - scrollView.bounds.width)
        let targetOffset = min(max(scrollView.contentOffset.x + delta, 0), maxOffset)

        scrollView.setContentOffset(CGPoint(x: targetOffset, y: scrollView.contentOffset.y), animated: false)
    }

    private func nearestWhiteKeyCenterPosition(in scrollView: UIScrollView, whiteKeyWidth: CGFloat) -> CGFloat {
        let viewportCenterX = scrollView.contentOffset.x + (scrollView.bounds.width / 2)
        let keyIndex = max(0, (viewportCenterX / whiteKeyWidth).rounded())
        return (keyIndex * whiteKeyWidth) + (whiteKeyWidth / 2)
    }

    private func attachScrollViewIfNeeded() {
        guard observedScrollView == nil else { return }

        var view = superview
        while let currentView = view {
            if let scrollView = currentView as? UIScrollView {
                observedScrollView = scrollView
                return
            }

            view = currentView.superview
        }
    }
}

private struct WhitePianoKeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(configuration.isPressed ? AppColors.whiteKeyPressed : AppColors.whiteKey)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(AppColors.whiteKeyBorder, lineWidth: 1)
            )
    }
}

private struct BlackPianoKeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 3,
                    bottomLeadingRadius: 5,
                    bottomTrailingRadius: 5,
                    topTrailingRadius: 3
                )
                .fill(configuration.isPressed ? AppColors.blackKeyPressed : AppColors.blackKey)
                .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 3)
            )
    }
}

private struct MultiTouchKeyboardOverlay: UIViewRepresentable {
    let keys: [PianoKey]
    let whiteKeyWidth: CGFloat
    let blackKeyWidth: CGFloat
    let blackKeyHeight: CGFloat
    let transpose: Int
    let a4Frequency: Int
    let selectedTone: PianoTone
    let audioEngine: PianoAudioEngine
    @Binding var pressedKeyIDs: Set<Int>

    func makeUIView(context: Context) -> MultiTouchKeyboardUIView {
        let view = MultiTouchKeyboardUIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        return view
    }

    func updateUIView(_ uiView: MultiTouchKeyboardUIView, context: Context) {
        uiView.configure(
            keys: keys,
            whiteKeyWidth: whiteKeyWidth,
            blackKeyWidth: blackKeyWidth,
            blackKeyHeight: blackKeyHeight,
            transpose: transpose,
            a4Frequency: a4Frequency,
            selectedTone: selectedTone,
            audioEngine: audioEngine,
            onPressedKeysChanged: { pressedKeyIDs = $0 }
        )
    }
}

private final class MultiTouchKeyboardUIView: UIView {
    private var keys: [PianoKey] = []
    private var whiteKeys: [PianoKey] = []
    private var blackKeys: [PianoKey] = []
    private var whiteKeyWidth: CGFloat = 1
    private var blackKeyWidth: CGFloat = 1
    private var blackKeyHeight: CGFloat = 1
    private var transpose = 0
    private var a4Frequency = 440
    private var selectedTone = PianoTone.synth
    private weak var audioEngine: PianoAudioEngine?
    private var activeTouches: [ObjectIdentifier: PianoKey] = [:]
    private var onPressedKeysChanged: (Set<Int>) -> Void = { _ in }

    func configure(
        keys: [PianoKey],
        whiteKeyWidth: CGFloat,
        blackKeyWidth: CGFloat,
        blackKeyHeight: CGFloat,
        transpose: Int,
        a4Frequency: Int,
        selectedTone: PianoTone,
        audioEngine: PianoAudioEngine,
        onPressedKeysChanged: @escaping (Set<Int>) -> Void
    ) {
        self.keys = keys
        self.whiteKeys = keys.filter { !$0.isBlack }
        self.blackKeys = keys.filter { $0.isBlack }
        self.whiteKeyWidth = whiteKeyWidth
        self.blackKeyWidth = blackKeyWidth
        self.blackKeyHeight = blackKeyHeight
        self.transpose = transpose
        self.a4Frequency = a4Frequency
        self.selectedTone = selectedTone
        self.audioEngine = audioEngine
        self.onPressedKeysChanged = onPressedKeysChanged
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        update(touches: touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        update(touches: touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        stop(touches: touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        stop(touches: touches)
    }

    private func update(touches: Set<UITouch>) {
        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            let location = touch.location(in: self)
            let newKey = key(at: location)
            let oldKey = activeTouches[identifier]

            guard newKey?.id != oldKey?.id else { continue }

            if let oldKey {
                audioEngine?.stop(key: oldKey, immediately: false)
                activeTouches[identifier] = nil
            }

            if let newKey {
                audioEngine?.start(key: newKey, transpose: transpose, a4Frequency: a4Frequency, tone: selectedTone)
                activeTouches[identifier] = newKey
            }
        }

        publishPressedKeys()
    }

    private func stop(touches: Set<UITouch>) {
        for touch in touches {
            let identifier = ObjectIdentifier(touch)

            if let key = activeTouches[identifier] {
                audioEngine?.stop(key: key, immediately: false)
                activeTouches[identifier] = nil
            }
        }

        publishPressedKeys()
    }

    private func key(at point: CGPoint) -> PianoKey? {
        guard bounds.contains(point) else { return nil }

        if point.y <= blackKeyHeight, let blackKey = blackKey(at: point) {
            return blackKey
        }

        let whiteIndex = Int(point.x / whiteKeyWidth)
        guard whiteKeys.indices.contains(whiteIndex) else { return nil }

        return whiteKeys[whiteIndex]
    }

    private func blackKey(at point: CGPoint) -> PianoKey? {
        for key in blackKeys.reversed() {
            let whiteBefore = keys.filter { !$0.isBlack && $0.midi < key.midi }.count
            let x = CGFloat(whiteBefore) * whiteKeyWidth - (blackKeyWidth / 2)
            let rect = CGRect(x: x, y: 0, width: blackKeyWidth, height: blackKeyHeight)

            if rect.contains(point) {
                return key
            }
        }

        return nil
    }

    private func publishPressedKeys() {
        onPressedKeysChanged(Set(activeTouches.values.map(\.id)))
    }
}

private struct ScrollTouchKeyboardObserver: UIViewRepresentable {
    let keys: [PianoKey]
    let whiteKeyWidth: CGFloat
    let blackKeyWidth: CGFloat
    let blackKeyHeight: CGFloat
    let transpose: Int
    let a4Frequency: Int
    let selectedTone: PianoTone
    let audioEngine: PianoAudioEngine
    @Binding var pressedKeyIDs: Set<Int>

    func makeUIView(context: Context) -> ScrollTouchKeyboardUIView {
        let view = ScrollTouchKeyboardUIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: ScrollTouchKeyboardUIView, context: Context) {
        uiView.configure(
            keys: keys,
            whiteKeyWidth: whiteKeyWidth,
            blackKeyWidth: blackKeyWidth,
            blackKeyHeight: blackKeyHeight,
            transpose: transpose,
            a4Frequency: a4Frequency,
            selectedTone: selectedTone,
            audioEngine: audioEngine,
            onPressedKeysChanged: { pressedKeyIDs = $0 }
        )
    }
}

private final class ScrollTouchKeyboardUIView: UIView, UIGestureRecognizerDelegate {
    private var keys: [PianoKey] = []
    private var whiteKeys: [PianoKey] = []
    private var blackKeys: [PianoKey] = []
    private var whiteKeyWidth: CGFloat = 1
    private var blackKeyWidth: CGFloat = 1
    private var blackKeyHeight: CGFloat = 1
    private var transpose = 0
    private var a4Frequency = 440
    private var selectedTone = PianoTone.synth
    private weak var audioEngine: PianoAudioEngine?
    private weak var observedScrollView: UIScrollView?
    private weak var touchRecognizer: ScrollKeyboardTouchGestureRecognizer?
    private var activeTouches: [ObjectIdentifier: PianoKey] = [:]
    private var gestureStartPoints: [ObjectIdentifier: CGPoint] = [:]
    private var horizontalScrollTouchIDs: Set<ObjectIdentifier> = []
    private var onPressedKeysChanged: (Set<Int>) -> Void = { _ in }

    func configure(
        keys: [PianoKey],
        whiteKeyWidth: CGFloat,
        blackKeyWidth: CGFloat,
        blackKeyHeight: CGFloat,
        transpose: Int,
        a4Frequency: Int,
        selectedTone: PianoTone,
        audioEngine: PianoAudioEngine,
        onPressedKeysChanged: @escaping (Set<Int>) -> Void
    ) {
        self.keys = keys
        self.whiteKeys = keys.filter { !$0.isBlack }
        self.blackKeys = keys.filter { $0.isBlack }
        self.whiteKeyWidth = whiteKeyWidth
        self.blackKeyWidth = blackKeyWidth
        self.blackKeyHeight = blackKeyHeight
        self.transpose = transpose
        self.a4Frequency = a4Frequency
        self.selectedTone = selectedTone
        self.audioEngine = audioEngine
        self.onPressedKeysChanged = onPressedKeysChanged
        attachTouchRecognizerIfNeeded()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attachTouchRecognizerIfNeeded()
    }

    deinit {
        if let touchRecognizer, let observedScrollView {
            observedScrollView.removeGestureRecognizer(touchRecognizer)
        }
    }

    fileprivate func handleScrollTouchesBegan(_ touches: Set<UITouch>) {
        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            let location = touch.location(in: self)
            gestureStartPoints[identifier] = location
            horizontalScrollTouchIDs.remove(identifier)
            updateActiveKey(for: touch)
        }
    }

    fileprivate func handleScrollTouchesMoved(_ touches: Set<UITouch>) {
        for touch in touches {
            updateScrollGestureState(for: touch)
            updateActiveKey(for: touch)
        }
    }

    fileprivate func handleScrollTouchesEnded(_ touches: Set<UITouch>, shouldCancelScroll: Bool) {
        if shouldCancelScroll {
            cancelScrollDeceleration()
        }

        for touch in touches {
            stopTouch(ObjectIdentifier(touch))
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    private func attachTouchRecognizerIfNeeded() {
        guard window != nil, touchRecognizer == nil, let scrollView = enclosingScrollView() else { return }

        let recognizer = ScrollKeyboardTouchGestureRecognizer(keyboardView: self)
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.requiresExclusiveTouchType = false
        recognizer.delegate = self
        scrollView.decelerationRate = UIScrollView.DecelerationRate(rawValue: 0)
        scrollView.addGestureRecognizer(recognizer)
        observedScrollView = scrollView
        touchRecognizer = recognizer
    }

    private func cancelScrollDeceleration() {
        guard let scrollView = observedScrollView else { return }

        freeze(scrollView)

        let wasScrollEnabled = scrollView.isScrollEnabled
        scrollView.isScrollEnabled = false

        DispatchQueue.main.async { [weak scrollView] in
            guard let scrollView else { return }
            scrollView.isScrollEnabled = wasScrollEnabled
            self.freeze(scrollView)
        }
    }

    private func freeze(_ scrollView: UIScrollView) {
        let currentOffset = scrollView.contentOffset
        scrollView.layer.removeAllAnimations()
        scrollView.setContentOffset(currentOffset, animated: false)
    }

    private func updateActiveKey(for touch: UITouch) {
        let identifier = ObjectIdentifier(touch)
        let point = touch.location(in: self)

        guard bounds.contains(point), let key = key(at: point) else {
            stopTouch(identifier)
            return
        }

        if horizontalScrollTouchIDs.contains(identifier), activeTouches[identifier] != nil {
            return
        }

        guard key.id != activeTouches[identifier]?.id else { return }

        if let oldKey = activeTouches[identifier] {
            activeTouches[identifier] = nil
            stopKeyIfUnused(oldKey)
        }

        activeTouches[identifier] = key

        if !isKeyAlreadyPlaying(key, excluding: identifier) {
            audioEngine?.start(key: key, transpose: transpose, a4Frequency: a4Frequency, tone: selectedTone)
        }

        publishPressedKeys()
    }

    private func stopTouch(_ identifier: ObjectIdentifier) {
        if let key = activeTouches[identifier] {
            activeTouches[identifier] = nil
            stopKeyIfUnused(key)
        }

        gestureStartPoints[identifier] = nil
        horizontalScrollTouchIDs.remove(identifier)
        publishPressedKeys()
    }

    private func updateScrollGestureState(for touch: UITouch) {
        let identifier = ObjectIdentifier(touch)
        guard let gestureStartPoint = gestureStartPoints[identifier] else { return }

        let currentLocation = touch.location(in: self)
        let horizontalDistance = abs(currentLocation.x - gestureStartPoint.x)
        let verticalDistance = abs(currentLocation.y - gestureStartPoint.y)
        let scrollTranslationX = abs(observedScrollView?.panGestureRecognizer.translation(in: observedScrollView).x ?? 0)

        if horizontalDistance > 10, horizontalDistance > verticalDistance * 1.4 {
            horizontalScrollTouchIDs.insert(identifier)
        }

        if scrollTranslationX > 8 {
            horizontalScrollTouchIDs.insert(identifier)
        }
    }

    private func stopKeyIfUnused(_ key: PianoKey) {
        guard !activeTouches.values.contains(where: { $0.id == key.id }) else { return }
        audioEngine?.stop(key: key, immediately: false)
    }

    private func isKeyAlreadyPlaying(_ key: PianoKey, excluding identifier: ObjectIdentifier) -> Bool {
        activeTouches.contains { activeIdentifier, activeKey in
            activeIdentifier != identifier && activeKey.id == key.id
        }
    }

    private func publishPressedKeys() {
        onPressedKeysChanged(Set(activeTouches.values.map(\.id)))
    }

    private func key(at point: CGPoint) -> PianoKey? {
        if point.y <= blackKeyHeight, let blackKey = blackKey(at: point) {
            return blackKey
        }

        let whiteIndex = Int(point.x / whiteKeyWidth)
        guard whiteKeys.indices.contains(whiteIndex) else { return nil }

        return whiteKeys[whiteIndex]
    }

    private func blackKey(at point: CGPoint) -> PianoKey? {
        for key in blackKeys.reversed() {
            let whiteBefore = keys.filter { !$0.isBlack && $0.midi < key.midi }.count
            let x = CGFloat(whiteBefore) * whiteKeyWidth - (blackKeyWidth / 2)
            let rect = CGRect(x: x, y: 0, width: blackKeyWidth, height: blackKeyHeight)

            if rect.contains(point) {
                return key
            }
        }

        return nil
    }

    private func enclosingScrollView() -> UIScrollView? {
        var view = superview

        while let currentView = view {
            if let scrollView = currentView as? UIScrollView {
                return scrollView
            }

            view = currentView.superview
        }

        return nil
    }
}

private final class ScrollKeyboardTouchGestureRecognizer: UIGestureRecognizer {
    private weak var keyboardView: ScrollTouchKeyboardUIView?
    private var activeTouchCount = 0

    init(keyboardView: ScrollTouchKeyboardUIView) {
        self.keyboardView = keyboardView
        super.init(target: nil, action: nil)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        activeTouchCount += touches.count
        keyboardView?.handleScrollTouchesBegan(touches)
        state = state == .possible ? .began : .changed
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        keyboardView?.handleScrollTouchesMoved(touches)
        state = state == .possible ? .began : .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        activeTouchCount = max(0, activeTouchCount - touches.count)
        keyboardView?.handleScrollTouchesEnded(touches, shouldCancelScroll: activeTouchCount == 0)
        state = activeTouchCount == 0 ? .ended : .changed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        activeTouchCount = max(0, activeTouchCount - touches.count)
        keyboardView?.handleScrollTouchesEnded(touches, shouldCancelScroll: activeTouchCount == 0)
        state = activeTouchCount == 0 ? .cancelled : .changed
    }

    override func reset() {
        activeTouchCount = 0
        super.reset()
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }
}

private struct ScrollAffordance: View {
    var body: some View {
        HStack {
            edgeFade(rotation: 0)
            Spacer()
            edgeFade(rotation: 180)
        }
        .allowsHitTesting(false)
    }

    private func edgeFade(rotation: Double) -> some View {
        LinearGradient(
            colors: [.black.opacity(0.22), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 42)
        .rotationEffect(.degrees(rotation))
    }
}

private final class PianoAudioEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private let sampleRate = 44_100.0
    private let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100.0, channels: 2)!
    private var voicePlayers: [AVAudioPlayerNode] = []
    private var nextVoiceIndex = 0
    private var activeSustainedNotes: [Int: ActiveSustainedNote] = [:]
    private var bufferCache: [ToneBufferKey: AVAudioPCMBuffer] = [:]
    private var playerGenerations: [ObjectIdentifier: Int] = [:]
    private let bufferCacheLock = NSLock()
    private let samplePianoLibrary = PianoSampleLibrary()
    private let synthReleaseDuration = 0.1
    private var outputVolume: Float = 1
    private var isSessionPrepared = false

    func setOutputVolume(_ volume: Double) {
        outputVolume = Float(min(max(volume, 0), 1))
        engine.mainMixerNode.outputVolume = outputVolume
    }

    func prepareSession(transpose: Int? = nil, a4Frequency: Int? = nil) {
        guard !isSessionPrepared else {
            if let transpose, let a4Frequency {
                prebuildSynthBuffers(transpose: transpose, a4Frequency: a4Frequency)
            }

            return
        }

        configureAudioSession()
        prepareVoicePool()
        engine.mainMixerNode.outputVolume = outputVolume
        engine.prepare()
        ensureEngineIsRunning()
        primeOutputRoute()

        if let transpose, let a4Frequency {
            prebuildSynthBuffers(transpose: transpose, a4Frequency: a4Frequency)
        }

        isSessionPrepared = true
    }

    func prepareSynthBuffers(transpose: Int, a4Frequency: Int) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.prebuildSynthBuffers(transpose: transpose, a4Frequency: a4Frequency)
        }
    }

    func playMomentary(key: PianoKey, transpose: Int, a4Frequency: Int, tone: PianoTone) {
        play(key: key, transpose: transpose, a4Frequency: a4Frequency, tone: tone, duration: 1.25)
    }

    func start(key: PianoKey, transpose: Int, a4Frequency: Int, tone: PianoTone) {
        playSustained(key: key, transpose: transpose, a4Frequency: a4Frequency, tone: tone)
    }

    func stop(key: PianoKey, immediately: Bool = false) {
        guard let note = activeSustainedNotes[key.id] else { return }

        activeSustainedNotes[key.id] = nil
        fadeOutAndStop(note, immediately: immediately)
    }

    func stopAllSustained() {
        for player in voicePlayers {
            player.stop()
        }

        activeSustainedNotes.removeAll(keepingCapacity: true)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session failed: \(error.localizedDescription)")
        }
    }

    private func prepareVoicePool() {
        guard voicePlayers.isEmpty else { return }

        for _ in 0..<32 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: audioFormat)
            voicePlayers.append(player)
        }
    }

    private func play(key: PianoKey, transpose: Int, a4Frequency: Int, tone: PianoTone, duration: Double) {
        prepareSession()

        guard let player = nextVoicePlayer() else { return }
        let buffer = toneBuffer(for: key, transpose: transpose, a4Frequency: a4Frequency, tone: tone, duration: duration)

        preparePlayerForPlayback(player)
        removeActiveMapping(for: player)

        guard ensureEngineIsRunning() else { return }

        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    private func playSustained(key: PianoKey, transpose: Int, a4Frequency: Int, tone: PianoTone) {
        prepareSession()

        if tone == .samplePiano {
            play(key: key, transpose: transpose, a4Frequency: a4Frequency, tone: tone, duration: 2.4)
            return
        }

        stop(key: key, immediately: true)

        guard let player = nextVoicePlayer(preferInactive: true) else { return }
        let buffer = synthLoopBuffer(for: key, transpose: transpose, a4Frequency: a4Frequency)

        preparePlayerForPlayback(player)
        removeActiveMapping(for: player)

        guard ensureEngineIsRunning() else { return }

        activeSustainedNotes[key.id] = ActiveSustainedNote(
            key: key,
            transpose: transpose,
            a4Frequency: a4Frequency,
            tone: tone,
            player: player,
            startedAt: CACurrentMediaTime()
        )
        player.scheduleBuffer(buffer, at: nil, options: [.loops])
        player.play()
    }

    private func fadeOutAndStop(_ note: ActiveSustainedNote, immediately: Bool) {
        let player = note.player

        guard !immediately else {
            advanceGeneration(for: player)
            player.stop()
            player.volume = 1
            return
        }

        let steps = 16
        let startVolume = player.volume
        let fadeGeneration = generation(for: player)

        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (synthReleaseDuration * Double(step) / Double(steps))) { [weak self, weak player] in
                guard let self, let player, self.generation(for: player) == fadeGeneration else { return }

                let progress = Double(step) / Double(steps)
                let fade = 0.5 + (0.5 * cos(.pi * progress))
                player.volume = Float(Double(startVolume) * fade)

                if step == steps {
                    self.advanceGeneration(for: player)
                    player.stop()
                    player.volume = 1
                }
            }
        }
    }

    private func primeOutputRoute() {
        guard let player = voicePlayers.last else { return }

        player.stop()
        player.volume = 0

        let buffer = silenceBuffer(duration: 0.08)
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak player] in
            player?.stop()
            player?.volume = 1
        }
    }

    private func nextVoicePlayer(preferInactive: Bool = false) -> AVAudioPlayerNode? {
        prepareVoicePool()
        guard !voicePlayers.isEmpty else { return nil }

        if preferInactive {
            for offset in 0..<voicePlayers.count {
                let index = (nextVoiceIndex + offset) % voicePlayers.count
                let candidate = voicePlayers[index]

                if !isSustainedPlayerActive(candidate), !candidate.isPlaying {
                    nextVoiceIndex = (index + 1) % voicePlayers.count
                    return candidate
                }
            }
        }

        let player = voicePlayers[nextVoiceIndex]
        nextVoiceIndex = (nextVoiceIndex + 1) % voicePlayers.count
        removeActiveMapping(for: player)
        return player
    }

    private func isSustainedPlayerActive(_ player: AVAudioPlayerNode) -> Bool {
        activeSustainedNotes.values.contains { $0.player === player }
    }

    private func removeActiveMapping(for player: AVAudioPlayerNode) {
        activeSustainedNotes = activeSustainedNotes.filter { _, note in
            note.player !== player
        }
    }

    private func preparePlayerForPlayback(_ player: AVAudioPlayerNode) {
        advanceGeneration(for: player)
        player.stop()
        player.volume = 1
    }

    @discardableResult
    private func advanceGeneration(for player: AVAudioPlayerNode) -> Int {
        let identifier = ObjectIdentifier(player)
        let nextGeneration = (playerGenerations[identifier] ?? 0) + 1
        playerGenerations[identifier] = nextGeneration
        return nextGeneration
    }

    private func generation(for player: AVAudioPlayerNode) -> Int {
        playerGenerations[ObjectIdentifier(player)] ?? 0
    }

    @discardableResult
    private func ensureEngineIsRunning() -> Bool {
        guard !engine.isRunning else { return true }

        do {
            try engine.start()
            return true
        } catch {
            print("Audio engine failed to start: \(error.localizedDescription)")
            return false
        }
    }

    private func toneBuffer(
        for key: PianoKey,
        transpose: Int,
        a4Frequency: Int,
        tone: PianoTone,
        duration: Double
    ) -> AVAudioPCMBuffer {
        let cacheKey = ToneBufferKey(midi: key.midi, transpose: transpose, a4Frequency: a4Frequency, tone: tone, duration: duration)

        if let buffer = cachedBuffer(for: cacheKey) {
            return buffer
        }

        let frequency = key.frequency(transpose: transpose, a4Frequency: a4Frequency)
        let buffer: AVAudioPCMBuffer

        if tone == .samplePiano,
           let sampleBuffer = samplePianoLibrary.toneBuffer(
            for: key,
            transpose: transpose,
            a4Frequency: a4Frequency,
            outputFormat: audioFormat,
            outputSampleRate: sampleRate,
            duration: duration
           ) {
            buffer = sampleBuffer
        } else {
            buffer = makeToneBuffer(frequency: frequency, tone: tone, duration: duration)
        }

        storeBuffer(buffer, for: cacheKey)
        return buffer
    }

    private func synthLoopBuffer(for key: PianoKey, transpose: Int, a4Frequency: Int) -> AVAudioPCMBuffer {
        let cacheKey = ToneBufferKey(midi: key.midi, transpose: transpose, a4Frequency: a4Frequency, tone: .synth, duration: 0)

        if let buffer = cachedBuffer(for: cacheKey) {
            return buffer
        }

        let buffer = makeSynthLoopBuffer(frequency: key.frequency(transpose: transpose, a4Frequency: a4Frequency))
        storeBuffer(buffer, for: cacheKey)
        return buffer
    }

    private func prebuildSynthBuffers(transpose: Int, a4Frequency: Int) {
        for key in PianoKey.fullKeyboard {
            _ = synthLoopBuffer(for: key, transpose: transpose, a4Frequency: a4Frequency)
        }
    }

    private func cachedBuffer(for key: ToneBufferKey) -> AVAudioPCMBuffer? {
        bufferCacheLock.lock()
        defer { bufferCacheLock.unlock() }

        return bufferCache[key]
    }

    private func storeBuffer(_ buffer: AVAudioPCMBuffer, for key: ToneBufferKey) {
        bufferCacheLock.lock()
        defer { bufferCacheLock.unlock() }

        bufferCache[key] = buffer

        if bufferCache.count > 640 {
            bufferCache.removeAll(keepingCapacity: true)
            bufferCache[key] = buffer
        }
    }

    private func makeSynthLoopBuffer(frequency: Double) -> AVAudioPCMBuffer {
        let cycleCount = synthLoopCycleCount(for: frequency)
        let frameCount = max(1024, AVAudioFrameCount((sampleRate * Double(cycleCount) / frequency).rounded()))
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!

        buffer.frameLength = frameCount

        guard let left = buffer.floatChannelData?[0], let right = buffer.floatChannelData?[1] else {
            return buffer
        }

        let totalFrames = Double(frameCount)

        for frame in 0..<Int(frameCount) {
            let phase = 2.0 * .pi * Double(cycleCount) * Double(frame) / totalFrames
            let value = Float(synthSample(phase: phase) * 0.5)

            left[frame] = value
            right[frame] = value
        }

        return buffer
    }

    private func synthLoopCycleCount(for frequency: Double) -> Int {
        if frequency < 80 { return 16 }
        if frequency < 180 { return 32 }
        if frequency < 400 { return 64 }
        return 128
    }

    private func makeToneBuffer(frequency: Double, tone: PianoTone, duration: Double) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!

        buffer.frameLength = frameCount

        guard let left = buffer.floatChannelData?[0], let right = buffer.floatChannelData?[1] else {
            return buffer
        }

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let envelope = envelope(for: tone, time: time, duration: duration)
            let sample = sample(frequency: frequency, time: time, tone: tone) * envelope * 0.5
            let value = Float(sample)

            left[frame] = value
            right[frame] = value
        }

        return buffer
    }

    private func silenceBuffer(duration: Double) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        return buffer
    }

    private func sample(frequency: Double, time: Double, tone: PianoTone) -> Double {
        switch tone {
        case .synth:
            synthSample(frequency: frequency, time: time)
        case .samplePiano:
            sampledPianoStyleSample(frequency: frequency, time: time)
        }
    }

    private func synthSample(frequency: Double, time: Double) -> Double {
        synthSample(phase: 2.0 * .pi * frequency * time)
    }

    private func synthSample(phase: Double) -> Double {
        let squareLike = tanh(sin(phase) * 3.2)
        let octave = tanh(sin(phase * 2.0) * 2.0) * 0.32
        let metallicFifth = sin(phase * 3.0) * 0.18
        let upperBuzz = sin(phase * 8.0) * 0.055

        return tanh(squareLike + octave + metallicFifth + upperBuzz)
    }

    private func sampledPianoStyleSample(frequency: Double, time: Double) -> Double {
        let hammer = sin(2.0 * .pi * frequency * 0.5 * time) * exp(-70.0 * time) * 0.22
        let body = sin(2.0 * .pi * frequency * time)
        let octave = sin(2.0 * .pi * frequency * 2.0 * time) * 0.28
        let fifth = sin(2.0 * .pi * frequency * 3.01 * time) * 0.11
        let upper = sin(2.0 * .pi * frequency * 5.02 * time) * 0.045
        let detuned = sin(2.0 * .pi * frequency * 1.003 * time) * 0.18

        return tanh(hammer + body + octave + fifth + upper + detuned)
    }

    private func envelope(for tone: PianoTone, time: Double, duration: Double) -> Double {
        switch tone {
        case .synth:
            synthEnvelope(time: time, duration: duration)
        case .samplePiano:
            sampledPianoStyleEnvelope(time: time, duration: duration)
        }
    }

    private func synthEnvelope(time: Double, duration: Double) -> Double {
        let attack = min(time / 0.006, 1.0)
        let releaseStart = duration * 0.96

        if time > releaseStart {
            let releaseProgress = min((time - releaseStart) / (duration - releaseStart), 1.0)
            return attack * (1.0 - releaseProgress)
        }

        return attack
    }

    private func sampledPianoStyleEnvelope(time: Double, duration: Double) -> Double {
        let attack = min(time / 0.004, 1.0)
        let earlyDrop = 0.72 + (0.28 * exp(-28.0 * time))
        let bodyDecay = exp(-2.9 * time)
        let releaseStart = duration * 0.78
        let release: Double

        if time > releaseStart {
            release = max(0, 1.0 - ((time - releaseStart) / (duration - releaseStart)))
        } else {
            release = 1.0
        }

        return attack * earlyDrop * bodyDecay * release
    }
}

private struct ToneBufferKey: Hashable {
    let midi: Int
    let transpose: Int
    let a4Frequency: Int
    let tone: PianoTone
    let duration: Double
}

private struct ActiveSustainedNote {
    let key: PianoKey
    let transpose: Int
    let a4Frequency: Int
    let tone: PianoTone
    let player: AVAudioPlayerNode
    let startedAt: CFTimeInterval
}

private final class PianoSampleLibrary {
    private var sourceCache: [Int: SampleSource] = [:]
    private lazy var availableMIDINotes: [Int] = {
        (21...108).filter { midi in
            Bundle.main.url(forResource: "PianoSample_\(midi)", withExtension: "wav") != nil
        }
    }()

    func toneBuffer(
        for key: PianoKey,
        transpose: Int,
        a4Frequency: Int,
        outputFormat: AVAudioFormat,
        outputSampleRate: Double,
        duration: Double
    ) -> AVAudioPCMBuffer? {
        guard let source = nearestSource(for: key.midi) else { return nil }

        let targetFrequency = key.frequency(transpose: transpose, a4Frequency: a4Frequency)
        let sourceFrequency = sourceFrequency(forMIDI: source.midi)
        let playbackRate = targetFrequency / sourceFrequency
        let frameCount = AVAudioFrameCount(outputSampleRate * duration)
        let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount)!

        output.frameLength = frameCount

        guard
            let outputLeft = output.floatChannelData?[0],
            let outputRight = output.floatChannelData?[1],
            !source.samples.isEmpty
        else {
            return output
        }

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / outputSampleRate
            let sourcePosition = time * source.sampleRate * playbackRate
            let sample = interpolatedSample(from: source.samples, at: sourcePosition)
            let envelope = sampleEnvelope(time: time, duration: duration)
            let value = Float(Double(sample) * envelope * 0.82)

            outputLeft[frame] = value
            outputRight[frame] = value
        }

        return output
    }

    private func nearestSource(for midi: Int) -> SampleSource? {
        guard let nearestMIDI = availableMIDINotes.min(by: { abs($0 - midi) < abs($1 - midi) }) else {
            return nil
        }

        if let cached = sourceCache[nearestMIDI] {
            return cached
        }

        guard let source = loadSource(midi: nearestMIDI) else { return nil }
        sourceCache[nearestMIDI] = source
        return source
    }

    private func loadSource(midi: Int) -> SampleSource? {
        guard let url = Bundle.main.url(forResource: "PianoSample_\(midi)", withExtension: "wav") else {
            return nil
        }

        do {
            let file = try AVAudioFile(forReading: url)
            let frameCount = AVAudioFrameCount(file.length)
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount)!

            try file.read(into: buffer)

            guard let channels = buffer.floatChannelData else { return nil }

            let channelCount = Int(buffer.format.channelCount)
            let sampleCount = Int(buffer.frameLength)
            var samples: [Float] = []
            samples.reserveCapacity(sampleCount)

            for index in 0..<sampleCount {
                if channelCount > 1 {
                    samples.append((channels[0][index] + channels[1][index]) * 0.5)
                } else {
                    samples.append(channels[0][index])
                }
            }

            return SampleSource(midi: midi, sampleRate: buffer.format.sampleRate, samples: samples)
        } catch {
            print("Piano sample failed to load: \(url.lastPathComponent) \(error.localizedDescription)")
            return nil
        }
    }

    private func interpolatedSample(from samples: [Float], at position: Double) -> Float {
        guard position >= 0 else { return 0 }

        let lowerIndex = Int(position)
        let upperIndex = lowerIndex + 1

        guard samples.indices.contains(lowerIndex) else { return 0 }
        guard samples.indices.contains(upperIndex) else { return samples[lowerIndex] }

        let fraction = Float(position - Double(lowerIndex))
        return samples[lowerIndex] + ((samples[upperIndex] - samples[lowerIndex]) * fraction)
    }

    private func sampleEnvelope(time: Double, duration: Double) -> Double {
        let attack = min(time / 0.003, 1.0)
        let decay = exp(-2.2 * time)
        let releaseStart = duration * 0.82

        if time > releaseStart {
            let releaseProgress = min((time - releaseStart) / (duration - releaseStart), 1.0)
            return attack * decay * (1.0 - releaseProgress)
        }

        return attack * decay
    }

    private func sourceFrequency(forMIDI midi: Int) -> Double {
        440.0 * pow(2.0, Double(midi - 69) / 12.0)
    }
}

private struct SampleSource {
    let midi: Int
    let sampleRate: Double
    let samples: [Float]
}

private struct PianoKey: Identifiable {
    let midi: Int
    let note: Note
    let octave: Int

    var id: Int { midi }
    var isBlack: Bool { note.isBlack }

    var displayLabel: String? {
        if note == .c && octave >= 1 && octave <= 8 {
            return name
        }

        return nil
    }

    var name: String {
        "\(note.rawValue)\(octave)"
    }

    func frequency(transpose: Int, a4Frequency: Int) -> Double {
        let adjustedMidi = midi + transpose
        return Double(a4Frequency) * pow(2.0, Double(adjustedMidi - 69) / 12.0)
    }

    static let fullKeyboard: [PianoKey] = (21...108).map { midi in
        let note = Note(rawValue: midi % 12)!
        return PianoKey(midi: midi, note: note, octave: (midi / 12) - 1)
    }
}

private enum Note: String {
    case c = "C"
    case cSharp = "C#"
    case d = "D"
    case dSharp = "D#"
    case e = "E"
    case f = "F"
    case fSharp = "F#"
    case g = "G"
    case gSharp = "G#"
    case a = "A"
    case aSharp = "A#"
    case b = "B"

    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .c
        case 1: self = .cSharp
        case 2: self = .d
        case 3: self = .dSharp
        case 4: self = .e
        case 5: self = .f
        case 6: self = .fSharp
        case 7: self = .g
        case 8: self = .gSharp
        case 9: self = .a
        case 10: self = .aSharp
        case 11: self = .b
        default: return nil
        }
    }

    var isBlack: Bool {
        switch self {
        case .cSharp, .dSharp, .fSharp, .gSharp, .aSharp:
            true
        default:
            false
        }
    }
}

private enum AppColors {
    static let background = Color(red: 0.055, green: 0.066, blue: 0.066)
    static let keyboardDeck = Color(red: 0.13, green: 0.15, blue: 0.15)
    static let primaryText = Color(red: 0.91, green: 0.95, blue: 0.92)
    static let secondaryText = Color(red: 0.62, green: 0.70, blue: 0.67)
    static let controlAccent = Color(red: 0.34, green: 0.72, blue: 0.63)
    static let controlNeutral = Color(red: 0.28, green: 0.34, blue: 0.33)
    static let controlSurface = Color(red: 0.11, green: 0.13, blue: 0.13).opacity(0.94)
    static let panelSurface = Color(red: 0.075, green: 0.09, blue: 0.09).opacity(0.98)
    static let controlInset = Color.white.opacity(0.07)
    static let keyLabel = Color(red: 0.27, green: 0.31, blue: 0.30)
    static let whiteKey = Color(red: 0.99, green: 0.985, blue: 0.96)
    static let whiteKeyPressed = Color(red: 0.78, green: 0.88, blue: 0.86)
    static let whiteKeyBorder = Color(red: 0.75, green: 0.77, blue: 0.73)
    static let blackKey = Color(red: 0.055, green: 0.065, blue: 0.07)
    static let blackKeyPressed = Color(red: 0.22, green: 0.42, blue: 0.40)
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
