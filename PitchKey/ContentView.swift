//
//  ContentView.swift
//  PitchKey
//
//  Created by arakawa hinata on 2026/06/11.
//

import AVFoundation
import Combine
import SwiftUI

struct ContentView: View {
    @StateObject private var audioEngine = PianoAudioEngine()
    @State private var isKeyboardLocked = false
    @State private var transpose = 0
    @State private var a4Frequency = 440

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            VStack(spacing: 0) {
                ControlBar(
                    isKeyboardLocked: $isKeyboardLocked,
                    transpose: $transpose,
                    a4Frequency: $a4Frequency
                )
                .padding(.horizontal, isLandscape ? 18 : 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

                PianoKeyboardView(
                    isLocked: isKeyboardLocked,
                    transpose: transpose,
                    a4Frequency: a4Frequency,
                    audioEngine: audioEngine
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, isLandscape ? 18 : 10)
                    .padding(.bottom, 12)
            }
            .background(AppColors.background)
            .onAppear {
                audioEngine.prepareSession()
            }
        }
    }
}

private struct ControlBar: View {
    @Environment(\.openURL) private var openURL

    @Binding var isKeyboardLocked: Bool
    @Binding var transpose: Int
    @Binding var a4Frequency: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                title
                Spacer(minLength: 8)
                controls
            }

            VStack(alignment: .leading, spacing: 10) {
                title
                controls
            }
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("PitchKey")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(AppColors.primaryText)

            Text("A0-C8 / 88 Keys")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.secondaryText)
        }
        .fixedSize()
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Toggle(isOn: $isKeyboardLocked) {
                Label(isKeyboardLocked ? "Locked" : "Scroll", systemImage: isKeyboardLocked ? "lock.fill" : "arrow.left.and.right")
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)

            Button {
                openAppleMusic()
            } label: {
                Label("Music", systemImage: "music.note.list")
            }
            .buttonStyle(.bordered)

            Stepper(value: $transpose, in: -12...12) {
                Label("Key \(signed(transpose))", systemImage: "music.note")
            }
            .labelsHidden()
            .overlay(alignment: .center) {
                Text("Key \(signed(transpose))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.primaryText)
                    .allowsHitTesting(false)
            }
            .frame(width: 96)

            Stepper(value: $a4Frequency, in: 415...466, step: 1) {
                Label("A4 \(a4Frequency)Hz", systemImage: "waveform")
            }
            .labelsHidden()
            .overlay(alignment: .center) {
                Text("A4 \(a4Frequency)Hz")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.primaryText)
                    .allowsHitTesting(false)
            }
            .frame(width: 112)
        }
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

private struct PianoKeyboardView: View {
    let isLocked: Bool
    let transpose: Int
    let a4Frequency: Int
    let audioEngine: PianoAudioEngine

    private let keys = PianoKey.fullKeyboard

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let whiteKeyWidth = max(isLandscape ? 34 : 42, geometry.size.width / (isLandscape ? 18 : 9))
            let blackKeyWidth = whiteKeyWidth * 0.62
            let keyboardWidth = whiteKeyWidth * CGFloat(keys.filter { !$0.isBlack }.count)

            ScrollView(.horizontal, showsIndicators: !isLocked) {
                ZStack(alignment: .topLeading) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(keys.filter { !$0.isBlack }) { key in
                            WhitePianoKey(
                                key: key,
                                isLocked: isLocked,
                                transpose: transpose,
                                a4Frequency: a4Frequency,
                                audioEngine: audioEngine
                            )
                                .frame(width: whiteKeyWidth)
                        }
                    }

                    ForEach(keys.filter { $0.isBlack }) { key in
                        BlackPianoKey(
                            key: key,
                            isLocked: isLocked,
                            transpose: transpose,
                            a4Frequency: a4Frequency,
                            audioEngine: audioEngine
                        )
                            .frame(width: blackKeyWidth, height: geometry.size.height * 0.62)
                            .offset(x: blackKeyXOffset(for: key, whiteKeyWidth: whiteKeyWidth, blackKeyWidth: blackKeyWidth))
                    }
                }
                .frame(width: keyboardWidth, height: geometry.size.height, alignment: .topLeading)
                .padding(.vertical, 2)
            }
            .scrollDisabled(isLocked)
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
    let transpose: Int
    let a4Frequency: Int
    let audioEngine: PianoAudioEngine
    @State private var isPressed = false

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
                .gesture(pressGesture)
        } else {
            Button {
                audioEngine.playMomentary(key: key, transpose: transpose, a4Frequency: a4Frequency)
            } label: {
                whiteKeyLabel
            }
            .buttonStyle(WhitePianoKeyButtonStyle())
        }
    }

    private var whiteKeyLabel: some View {
        ZStack(alignment: .bottom) {
            if let label = key.displayLabel {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText)
                    .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPressed else { return }
                isPressed = true
                audioEngine.start(key: key, transpose: transpose, a4Frequency: a4Frequency)
            }
            .onEnded { _ in
                isPressed = false
                audioEngine.stop(key: key)
            }
    }
}

private struct BlackPianoKey: View {
    let key: PianoKey
    let isLocked: Bool
    let transpose: Int
    let a4Frequency: Int
    let audioEngine: PianoAudioEngine
    @State private var isPressed = false

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
                .gesture(pressGesture)
        } else {
            Button {
                audioEngine.playMomentary(key: key, transpose: transpose, a4Frequency: a4Frequency)
            } label: {
                blackKeyLabel
            }
            .buttonStyle(BlackPianoKeyButtonStyle())
        }
    }

    private var blackKeyLabel: some View {
        ZStack(alignment: .bottom) {
            if let label = key.displayLabel {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPressed else { return }
                isPressed = true
                audioEngine.start(key: key, transpose: transpose, a4Frequency: a4Frequency)
            }
            .onEnded { _ in
                isPressed = false
                audioEngine.stop(key: key)
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

private struct ScrollAffordance: View {
    var body: some View {
        ZStack {
            HStack {
                edgeFade(rotation: 0)
                Spacer()
                edgeFade(rotation: 180)
            }
            .allowsHitTesting(false)

            VStack {
                Spacer()

                HStack(spacing: 14) {
                    Image(systemName: "chevron.left")
                    Capsule()
                        .fill(.white.opacity(0.72))
                        .frame(width: 76, height: 4)
                    Image(systemName: "chevron.right")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.black.opacity(0.28), in: Capsule())
                .padding(.bottom, 12)
                .allowsHitTesting(false)
            }
        }
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
    private var momentaryPlayers: [AVAudioPlayerNode] = []
    private var sustainedPlayers: [Int: AVAudioPlayerNode] = [:]
    private var isSessionPrepared = false

    func prepareSession() {
        guard !isSessionPrepared else { return }

        configureAudioSession()
        isSessionPrepared = true
    }

    func playMomentary(key: PianoKey, transpose: Int, a4Frequency: Int) {
        prepareSession()

        let player = AVAudioPlayerNode()
        let frequency = key.frequency(transpose: transpose, a4Frequency: a4Frequency)
        let buffer = makeToneBuffer(frequency: frequency, duration: 0.85)

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
        momentaryPlayers.append(player)

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("Audio engine failed to start: \(error.localizedDescription)")
                engine.detach(player)
                momentaryPlayers.removeAll { $0 === player }
                return
            }
        }

        player.scheduleBuffer(buffer, at: nil, options: []) { [weak self, weak player] in
            DispatchQueue.main.async {
                guard let self, let player else { return }
                player.stop()
                self.engine.detach(player)
                self.momentaryPlayers.removeAll { $0 === player }
            }
        }

        player.play()
    }

    func start(key: PianoKey, transpose: Int, a4Frequency: Int) {
        prepareSession()
        stop(key: key)

        let player = AVAudioPlayerNode()
        let frequency = key.frequency(transpose: transpose, a4Frequency: a4Frequency)
        let buffer = makeToneBuffer(frequency: frequency, duration: 2.4)

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
        sustainedPlayers[key.id] = player

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("Audio engine failed to start: \(error.localizedDescription)")
                engine.detach(player)
                sustainedPlayers[key.id] = nil
                return
            }
        }

        player.scheduleBuffer(buffer, at: nil, options: []) { [weak self, weak player] in
            DispatchQueue.main.async {
                guard let self, let player else { return }
                self.detachSustainedPlayer(player, for: key.id)
            }
        }

        player.play()
    }

    func stop(key: PianoKey) {
        guard let player = sustainedPlayers[key.id] else { return }

        player.stop()
        detachSustainedPlayer(player, for: key.id)
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

    private func detachSustainedPlayer(_ player: AVAudioPlayerNode, for keyID: Int) {
        if sustainedPlayers[keyID] === player {
            sustainedPlayers[keyID] = nil
        }

        if player.engine != nil {
            engine.detach(player)
        }
    }

    private func makeToneBuffer(frequency: Double, duration: Double) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!

        buffer.frameLength = frameCount

        guard let left = buffer.floatChannelData?[0], let right = buffer.floatChannelData?[1] else {
            return buffer
        }

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let envelope = pianoEnvelope(time: time, duration: duration)
            let tone = sample(frequency: frequency, time: time) * envelope * 0.28
            let value = Float(tone)

            left[frame] = value
            right[frame] = value
        }

        return buffer
    }

    private func sample(frequency: Double, time: Double) -> Double {
        let fundamental = sin(2.0 * .pi * frequency * time)
        let second = sin(2.0 * .pi * frequency * 2.0 * time) * 0.34
        let third = sin(2.0 * .pi * frequency * 3.0 * time) * 0.16
        let softNoise = sin(2.0 * .pi * frequency * 7.0 * time) * 0.04

        return tanh(fundamental + second + third + softNoise)
    }

    private func pianoEnvelope(time: Double, duration: Double) -> Double {
        let attack = min(time / 0.012, 1.0)
        let decay = exp(-4.4 * time)
        let releaseStart = duration * 0.74

        if time > releaseStart {
            let releaseProgress = min((time - releaseStart) / (duration - releaseStart), 1.0)
            return attack * decay * (1.0 - releaseProgress)
        }

        return attack * decay
    }
}

private struct PianoKey: Identifiable {
    let midi: Int
    let note: Note
    let octave: Int

    var id: Int { midi }
    var isBlack: Bool { note.isBlack }

    var displayLabel: String? {
        if midi == 21 || midi == 108 || midi == 69 {
            return name
        }

        if note == .c && octave >= 1 && octave <= 7 {
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
    static let background = Color(red: 0.93, green: 0.95, blue: 0.93)
    static let keyboardDeck = Color(red: 0.18, green: 0.20, blue: 0.21)
    static let primaryText = Color(red: 0.13, green: 0.15, blue: 0.16)
    static let secondaryText = Color(red: 0.44, green: 0.49, blue: 0.49)
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
