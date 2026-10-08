//
//  VoiceGuide.swift
//  Trance
//

import AVFoundation

/// Stemmen under en session.
///
/// Sådan virker den:
/// 1. `start` lægger en plan for hele sessionen: hvilket åndedrag hver optagelse skal begynde på.
/// 2. SessionView kalder `exhaleBegan`, hver gang punktet begynder at blive mindre. Så tæller stemmen
///    ét åndedrag frem og afspiller den optagelse, planen har til det åndedrag.
/// 3. På de åndedrag, hvor planen er tom, kan stemmen sige noget om afslapningen, hvis den har ændret sig.
///
/// Tiden tælles altså i åndedrag og ikke i sekunder. Et åndedrag er én gang ind og ud med punktet.
final class VoiceGuide {
    // punktet vokser i 4 sekunder og krymper i 6, så et åndedrag varer 10 sekunder
    private let secondsBeforeFirstExhale = 4.0
    private let secondsPerBreath = 10.0

    // planen: nummeret på et åndedrag og den optagelse, der begynder på det. det første åndedrag er nummer 0
    private var plan: [Int: String] = [:]
    // det næste åndedrag, der er ledigt, mens planen bliver lagt
    private var nextFreeBreath = 0
    // det åndedrag, opvågningen begynder på
    private var awakeningStart = 0
    // optagelser, der allerede er brugt, så ingen bliver sagt to gange
    private var used: Set<String> = []

    // det åndedrag, sessionen er nået til. -1 betyder, at den første udånding ikke er begyndt endnu
    private var breath = -1
    // det første åndedrag, hvor den optagelse, der afspilles nu, er færdig
    private var silentFrom = 0
    private var player: VoicePlayer?
    // afslapningsscoren ved de seneste åndedrag, med den nyeste til sidst
    private var relaxationHistory: [Double] = []

    /// Lægger planen. Kaldes, når sessionen begynder.
    func start(for duration: Duration) {
        #if os(iOS)
        // stemmen skal kunne høres, selvom telefonen er på lydløs, og den stopper ikke musik fra andre apps
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        #endif

        let seconds = duration / .seconds(1)
        let totalBreaths = Int((seconds - secondsBeforeFirstExhale) / secondsPerBreath)

        // hvor mange minutter hver af de seks faser fylder i sætningskatalogets tidsplan
        let minutes = phaseMinutes(sessionMinutes: seconds / 60)
        let allMinutes = minutes.reduce(0, +)

        // opvågningen skal slutte sammen med sessionen, så den lægges først
        let awakeningBreaths = Int((Double(totalBreaths) * minutes[5] / allMinutes).rounded())
        planAwakening(breaths: awakeningBreaths, endingAt: totalBreaths)

        // de fem andre faser deler åndedragene før opvågningen i samme forhold som i tidsplanen.
        // ends[0] er det åndedrag, fase 1 slutter på, ends[1] er fase 2 og så videre
        var ends: [Int] = []
        var minutesSoFar = 0.0
        for phase in 0..<5 {
            minutesSoFar += minutes[phase]
            ends.append(Int(Double(awakeningStart) * minutesSoFar / (allMinutes - minutes[5])))
        }

        nextFreeBreath = 0
        planEstablishing(until: ends[0])
        planEyeFixation(until: ends[1])
        planEyeClosing(until: ends[2])
        // i sessioner under 20 minutter springes billederne over
        planDeepening(until: ends[3], withImagery: seconds >= 20 * 60)
        planRest(until: ends[4])

        // blev der slet ikke plads til at bede om at lukke øjnene, må opvågningen heller ikke bede om at åbne dem.
        // så slutter sessionen i stedet med, at energien vender tilbage
        if used.isDisjoint(with: VoiceCase.eyeClosing(.invitation).files) {
            for breath in awakeningStart..<totalBreaths {
                plan[breath] = nil
            }
            nextFreeBreath = totalBreaths - 1
            add(VoiceCase.awakening(.arriving).files[0], silence: 0, before: totalBreaths)
        }
    }

    /// Kaldes af SessionView, hver gang punktet begynder at blive mindre.
    func exhaleBegan() {
        breath += 1
        rememberRelaxation()

        if let file = plan[breath] {
            play(file)
        } else if canSayExtra, let file = relaxationFile() {
            play(file)
        }
    }

    private func play(_ file: String) {
        player = VoicePlayer(file)
        player?.play()
        silentFrom = breath + breathsNeeded(for: file)
    }

    // MARK: - Planen

    /// Tidsplanen fra sætningskataloget: minutter til fase 1 til 6 i en session på 15, 30 og 60 minutter.
    /// Andre længder bruger den nærmeste kortere plan og samme forhold mellem faserne.
    private func phaseMinutes(sessionMinutes: Double) -> [Double] {
        if sessionMinutes >= 60 { return [4, 7, 3, 14, 27, 5] }
        if sessionMinutes >= 30 { return [3, 5, 2, 8, 9, 3] }
        return [2, 3, 1, 4, 3, 2]
    }

    /// Lægger en optagelse på det næste ledige åndedrag, hvis den kan blive færdig før åndedraget `end`.
    /// Bagefter er der `silence` åndedrags stilhed, før den næste optagelse kan komme.
    private func add(_ file: String, silence: Int, before end: Int) {
        let needed = breathsNeeded(for: file)
        guard nextFreeBreath + needed <= end else { return }

        plan[nextFreeBreath] = file
        used.insert(file)
        nextFreeBreath += needed + silence
    }

    /// Hvor mange åndedrag en optagelse varer. De fleste varer ét, og de lange nedtællinger varer op til tre.
    private func breathsNeeded(for file: String) -> Int {
        let seconds = VoicePlayer(file).duration / .seconds(1)
        return max(1, Int((seconds / secondsPerBreath).rounded(.up)))
    }

    /// Vælger et antal tilfældige optagelser, men beholder den rækkefølge, de står i.
    private func pick(_ count: Int, from files: [String]) -> [String] {
        let chosen = Set(files.shuffled().prefix(max(0, count)))
        return files.filter { chosen.contains($0) }
    }

    /// De optagelser, der ikke er brugt endnu.
    private func unused(_ files: [String]) -> [String] {
        files.filter { !used.contains($0) }
    }

    // MARK: - Faser

    // fase 1: punktet og åndedrættet
    private func planEstablishing(until end: Int) {
        // åbningen forklarer punktet, så den skal med, selv når fasen er for kort til den i en helt kort session
        for file in VoiceCase.establishing(.opening).files {
            add(file, silence: Int.random(in: 1...2), before: awakeningStart)
        }

        // resten er et udvalg, der passer til fasens længde.
        // en optagelse og dens stilhed fylder 2-3 åndedrag, så der er plads til cirka så mange
        let room = (end - nextFreeBreath) * 2 / 5
        let later = VoiceCase.establishing(.theDot).files + VoiceCase.establishing(.settling).files

        for file in pick(room, from: later) {
            add(file, silence: Int.random(in: 1...2), before: end)
        }
    }

    // fase 2: tunge øjne, fra synet der fortoner sig til øjne, der gerne vil lukke
    private func planEyeFixation(until end: Int) {
        for file in VoiceCase.eyeFixation(.opening).files {
            add(file, silence: Int.random(in: 1...2), before: end)
        }

        // resten er et udvalg, der passer til fasens længde, ligesom i fase 1
        let room = (end - nextFreeBreath) * 2 / 5
        let later = VoiceCase.eyeFixation(.blurring).files
            + VoiceCase.eyeFixation(.heavyEyelids).files
            + VoiceCase.eyeFixation(.readyToClose).files

        for file in pick(room, from: later) {
            add(file, silence: Int.random(in: 1...2), before: end)
        }
    }

    // fase 3: øjnene lukker. om de faktisk lukker, måles ikke endnu
    private func planEyeClosing(until end: Int) {
        let countdown = VoiceCase.eyeClosing(.countdown).files
        // fasen slutter med nedtællingen, så opmuntringerne skal være færdige, inden den begynder
        let countdownStart = end - breathsNeeded(for: countdown[0])

        // opfordringen til at lukke øjnene skal med, selv når fasen er for kort til den i en helt kort session,
        // ligesom åbningen i fase 1. ellers beder opvågningen om at åbne øjne, der aldrig blev bedt om at lukke
        for file in VoiceCase.eyeClosing(.invitation).files {
            add(file, silence: 1, before: awakeningStart)
        }
        for file in VoiceCase.eyeClosing(.encouragement).files.shuffled() {
            add(file, silence: 1, before: countdownStart)
        }
        for file in countdown {
            add(file, silence: 2, before: end)
        }
    }

    // fase 4: åndedræt, én nedtælling, kropsscanning og ét billede, med korte fordybere indimellem
    private func planDeepening(until end: Int, withImagery: Bool) {
        let phaseBreaths = end - nextFreeBreath
        var breathing = VoiceCase.deepening(.breath).files.shuffled()
        var deepeners = VoiceCase.deepening(.deepener).files.shuffled()

        // åndedræt: tre optagelser i lange sessioner, ellers én
        for _ in 0..<(withImagery ? 3 : 1) {
            add(breathing.removeFirst(), silence: 2, before: end)
        }

        // én af de tre nedtællinger
        if let countdown = VoiceCase.deepening(.countdown).files.randomElement() {
            add(countdown, silence: 2, before: end)
        }
        add(deepeners.removeFirst(), silence: 2, before: end)

        // kropsscanningen går oppefra og ned og slutter altid med hele kroppen, som er den sidste optagelse.
        // den må fylde to femtedele af fasen, og hver optagelse fylder to åndedrag med sin stilhed.
        // er der ikke plads til alle, springes nogle over
        let body = VoiceCase.deepening(.bodyScan).files
        let wholeBody = body[body.count - 1]
        let scan = pick(phaseBreaths / 5 - 1, from: body.filter { $0 != wholeBody }) + [wholeBody]
        for file in scan {
            add(file, silence: 1, before: end)
        }
        add(deepeners.removeFirst(), silence: 2, before: end)

        if withImagery {
            // enten ét af billederne eller det trygge sted, som er tre optagelser i træk
            var image = VoiceCase.deepening(.safePlace).files
            if Bool.random(), let single = VoiceCase.deepening(.imagery).files.randomElement() {
                image = [single]
            }
            for file in image {
                add(file, silence: 2, before: end)
            }
        }

        // er der tid tilbage, fyldes den med det, der ikke er brugt
        for file in (breathing + deepeners).shuffled() {
            add(file, silence: 3, before: end)
        }
    }

    // fase 5: hvile. stilheden er det vigtigste, så der går et til to minutter mellem optagelserne
    private func planRest(until phaseEnd: Int) {
        // hvilen begynder med stilhed, og der skal også være stille lige før opvågningen
        nextFreeBreath += 5
        let end = phaseEnd - 2

        let start = nextFreeBreath
        let length = end - start
        var pool = unused(VoiceCase.rest(.resting).files + VoiceCase.rest(.thoughts).files
            + VoiceCase.deepening(.deepener).files).shuffled()
        var keepsakes = VoiceCase.rest(.keepsake).files.shuffled()
        var lastRefresh = start

        while nextFreeBreath < end {
            let inMiddle = nextFreeBreath >= start + length / 4 && nextFreeBreath < end - length / 4
            let inLastThird = nextFreeBreath >= start + length * 2 / 3
            // stilheden er længst midt i fasen
            let silence = inMiddle ? 10 : 6

            if nextFreeBreath - lastRefresh >= 60, end - nextFreeBreath >= 12 {
                // mini-genopfriskning for hvert 60. åndedrag (10 minutter): fire optagelser i træk.
                // det er de eneste optagelser, der bruges flere gange
                for file in VoiceCase.rest(.refresh).files {
                    add(file, silence: 1, before: end)
                }
                nextFreeBreath += silence
                lastRefresh = nextFreeBreath
            } else if inLastThird, !keepsakes.isEmpty {
                // optagelserne til at tage med hører til sidst i fasen
                add(keepsakes.removeFirst(), silence: silence, before: end)
            } else if !pool.isEmpty {
                add(pool.removeFirst(), silence: silence, before: end)
            } else {
                // der er ikke mere at sige, så resten af fasen er stille
                return
            }
        }
    }

    // fase 6: opvågning. den lægges baglæns fra slutningen, så den sidste optagelse slutter sammen med sessionen
    private func planAwakening(breaths: Int, endingAt end: Int) {
        let countUp = VoiceCase.awakening(.countUp).files
        var files = VoiceCase.awakening(.gathering).files + countUp + VoiceCase.awakening(.arriving).files
        var silence = 1

        if breaths >= speakingBreaths(files) + files.count - 1 {
            // der er plads til det hele. i lange sessioner bliver stilheden mellem optagelserne længere
            silence = (breaths - speakingBreaths(files)) / (files.count - 1)
        } else {
            // ellers er optællingen det vigtigste
            files = countUp
        }

        // i helt korte sessioner må opvågningen højst fylde halvdelen, og så er der kun plads til selve optællingen
        if speakingBreaths(files) + files.count - 1 > end / 2 {
            files = [countUp[countUp.count - 1]]
        }

        awakeningStart = max(0, end - speakingBreaths(files) - silence * (files.count - 1))
        nextFreeBreath = awakeningStart
        for file in files {
            add(file, silence: silence, before: end)
        }
    }

    /// Hvor mange åndedrag optagelserne varer tilsammen, uden stilhed imellem.
    private func speakingBreaths(_ files: [String]) -> Int {
        var total = 0
        for file in files {
            total += breathsNeeded(for: file)
        }
        return total
    }

    // MARK: - Afslapning

    /// Om der er plads til en ekstra optagelse nu: der skal være et stille åndedrag før og efter,
    /// og under opvågningen siges der ikke andet end planen.
    private var canSayExtra: Bool {
        breath > silentFrom && plan[breath + 1] == nil && breath < awakeningStart
    }

    /// Gemmer afslapningsscoren for dette åndedrag. Kun de seneste 18 åndedrag (tre minutter) gemmes.
    private func rememberRelaxation() {
        let score = copySessionScores().afslapningsscore
        guard score.available else {
            // uden en måling er der ikke noget at sammenligne med
            relaxationHistory = []
            return
        }

        relaxationHistory.append(score.value)
        if relaxationHistory.count > 18 {
            relaxationHistory.removeFirst()
        }
    }

    /// En optagelse om afslapningen, hvis den har ændret sig. Ellers nil.
    private func relaxationFile() -> String? {
        // der skal være målinger fra halvandet minut (9 åndedrag) tilbage at sammenligne med
        guard relaxationHistory.count >= 10 else { return nil }

        let now = relaxationHistory[relaxationHistory.count - 1]
        let before = relaxationHistory[relaxationHistory.count - 10]
        let highest = relaxationHistory.max() ?? now
        let lowest = relaxationHistory.min() ?? now

        let change: VoiceCase.Relaxation
        if now - before >= 0.1 {
            change = .rising
        } else if now - before <= -0.1 {
            change = .falling
        } else if relaxationHistory.count == 18, now < 0.6, highest - lowest < 0.05 {
            // den har stået stille i tre minutter uden at være høj
            change = .stalled
        } else {
            return nil
        }

        guard let file = unused(VoiceCase.relaxation(change).files).randomElement() else { return nil }

        used.insert(file)
        // målingerne glemmes, så den næste sammenligning begynder forfra
        relaxationHistory = []
        return file
    }
}
