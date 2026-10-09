import AVFoundation

/// Stemmen under en session. Tiden tælles i åndedrag på 10 sekunder.
final class VoiceGuide {
	private var plan: [Int: String] = [:]
	private var nextFreeBreath = 0
	private var awakeningStart = 0
	private var used: Set<String> = []
	private var breath = -1
	private var silentFrom = 0
	private var player: VoicePlayer?
	private var relaxationHistory: [Double] = []

	func start(for duration: Duration) {
		#if os(iOS)
		try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
		#endif

		let seconds = duration / .seconds(1)
		let totalBreaths = Int((seconds - 4) / 10)
		let minutes: [Double]
		if seconds >= 3600 {
			minutes = [4, 7, 3, 14, 27, 5]
		} else if seconds >= 1800 {
			minutes = [3, 5, 2, 8, 9, 3]
		} else {
			minutes = [2, 3, 1, 4, 3, 2]
		}
		var allMinutes = 0.0
		for time in minutes {
			allMinutes += time
		}

		// opvågningen skal slutte sammen med sessionen, så den lægges først
		let awakeningBreaths = Int((Double(totalBreaths) * minutes[5] / allMinutes).rounded())
		planAwakening(breaths: awakeningBreaths, endingAt: totalBreaths)
		var ends: [Int] = []
		var minutesSoFar = 0.0
		for phase in 0..<5 {
			minutesSoFar += minutes[phase]
			let end = Int(Double(awakeningStart) * minutesSoFar / (allMinutes - minutes[5]))
			ends.append(end)
		}

		nextFreeBreath = 0
		let establishing = VoiceCase.establishing(.theDot).files + VoiceCase.establishing(.settling).files
		planOpening(VoiceCase.establishing(.opening).files, later: establishing,
			until: ends[0], openingEnd: awakeningStart)
		let fixation = VoiceCase.eyeFixation(.blurring).files + VoiceCase.eyeFixation(.heavyEyelids).files
			+ VoiceCase.eyeFixation(.readyToClose).files
		planOpening(VoiceCase.eyeFixation(.opening).files, later: fixation, until: ends[1], openingEnd: ends[1])
		planEyeClosing(until: ends[2])
		planDeepening(until: ends[3], withImagery: seconds >= 1200)
		planRest(until: ends[4])

		// uden en opfordring til at lukke øjnene slutter sessionen med, at energien vender tilbage
		if used.isDisjoint(with: VoiceCase.eyeClosing(.invitation).files) {
			for breath in awakeningStart..<totalBreaths {
				plan[breath] = nil
			}
			nextFreeBreath = totalBreaths - 1
			add(VoiceCase.awakening(.arriving).files[0], silence: 0, before: totalBreaths)
		}
	}

	func exhaleBegan() {
		breath += 1
		let score = copySessionScores().afslapningsscore
		if score.available {
			relaxationHistory.append(score.value)
			relaxationHistory = Array(relaxationHistory.suffix(18))
		} else {
			relaxationHistory = []
		}

		var file = plan[breath]
		if file == nil && breath > silentFrom && plan[breath + 1] == nil && breath < awakeningStart {
			file = relaxationFile()
		}
		if let file {
			player = VoicePlayer(file)
			player?.play()
			silentFrom = breath + breathsNeeded(for: file)
		}
	}

	private func add(_ file: String, silence: Int = 1, before end: Int) {
		let needed = breathsNeeded(for: file)
		guard nextFreeBreath + needed <= end else { return }
		plan[nextFreeBreath] = file
		used.insert(file)
		nextFreeBreath += needed + silence
	}

	private func addFiles(_ files: [String], silence: Int = 1, before end: Int) {
		for file in files {
			add(file, silence: silence, before: end)
		}
	}

	private func breathsNeeded(for file: String) -> Int {
		let seconds = VoicePlayer(file).duration / .seconds(1)
		return max(1, Int((seconds / 10).rounded(.up)))
	}

	private func speakingBreaths(_ files: [String]) -> Int {
		var total = 0
		for file in files {
			total += breathsNeeded(for: file)
		}
		return total
	}

	/// Vælger tilfældige optagelser, men beholder deres rækkefølge.
	private func pick(_ count: Int, from files: [String]) -> [String] {
		let chosen = files.shuffled().prefix(max(0, count))
		var result: [String] = []
		for file in files where chosen.contains(file) {
			result.append(file)
		}
		return result
	}

	private func planOpening(_ opening: [String], later: [String], until end: Int, openingEnd: Int) {
		for file in opening {
			add(file, silence: Int.random(in: 1...2), before: openingEnd)
		}
		let room = (end - nextFreeBreath) * 2 / 5
		let selected = pick(room, from: later)
		for file in selected {
			add(file, silence: Int.random(in: 1...2), before: end)
		}
	}

	private func planEyeClosing(until end: Int) {
		let countdown = VoiceCase.eyeClosing(.countdown).files
		let countdownStart = end - breathsNeeded(for: countdown[0])
		addFiles(VoiceCase.eyeClosing(.invitation).files, before: awakeningStart)
		addFiles(VoiceCase.eyeClosing(.encouragement).files.shuffled(), before: countdownStart)
		addFiles(countdown, silence: 2, before: end)
	}

	private func planDeepening(until end: Int, withImagery: Bool) {
		let phaseBreaths = end - nextFreeBreath
		var breathing = VoiceCase.deepening(.breath).files.shuffled()
		var deepeners = VoiceCase.deepening(.deepener).files.shuffled()
		let breathingCount = withImagery ? 3 : 1
		for _ in 0..<breathingCount {
			add(breathing.removeFirst(), silence: 2, before: end)
		}
		if let countdown = VoiceCase.deepening(.countdown).files.randomElement() {
			add(countdown, silence: 2, before: end)
		}
		add(deepeners.removeFirst(), silence: 2, before: end)

		// kropsscanningen går oppefra og ned og slutter altid med hele kroppen
		let body = VoiceCase.deepening(.bodyScan).files
		let wholeBody = body[body.count - 1]
		let bodyParts = Array(body.dropLast())
		var scan = pick(phaseBreaths / 5 - 1, from: bodyParts)
		scan.append(wholeBody)
		addFiles(scan, before: end)
		add(deepeners.removeFirst(), silence: 2, before: end)
		if withImagery {
			var image = VoiceCase.deepening(.safePlace).files
			if Bool.random(), let single = VoiceCase.deepening(.imagery).files.randomElement() {
				image = [single]
			}
			addFiles(image, silence: 2, before: end)
		}
		let remaining = (breathing + deepeners).shuffled()
		addFiles(remaining, silence: 3, before: end)
	}

	private func planRest(until phaseEnd: Int) {
		nextFreeBreath += 5
		let end = phaseEnd - 2
		let start = nextFreeBreath
		let length = end - start
		let restFiles = VoiceCase.rest(.resting).files + VoiceCase.rest(.thoughts).files
			+ VoiceCase.deepening(.deepener).files
		var pool: [String] = []
		for file in restFiles where !used.contains(file) {
			pool.append(file)
		}
		pool = pool.shuffled()
		var keepsakes = VoiceCase.rest(.keepsake).files.shuffled()
		var lastRefresh = start

		while nextFreeBreath < end {
			let inMiddle = nextFreeBreath >= start + length / 4 && nextFreeBreath < end - length / 4
			let silence = inMiddle ? 10 : 6
			if nextFreeBreath - lastRefresh >= 60, end - nextFreeBreath >= 12 {
				addFiles(VoiceCase.rest(.refresh).files, before: end)
				nextFreeBreath += silence
				lastRefresh = nextFreeBreath
				continue
			}
			if nextFreeBreath >= start + length * 2 / 3 {
				pool = keepsakes + pool
				keepsakes = []
			}
			guard !pool.isEmpty else { return }
			add(pool.removeFirst(), silence: silence, before: end)
		}
	}

	private func planAwakening(breaths: Int, endingAt end: Int) {
		let countUp = VoiceCase.awakening(.countUp).files
		var files = VoiceCase.awakening(.gathering).files + countUp + VoiceCase.awakening(.arriving).files
		var silence = 1
		let speaking = speakingBreaths(files)
		if breaths >= speaking + files.count - 1 {
			silence = (breaths - speaking) / (files.count - 1)
		} else {
			files = countUp
		}
		if speakingBreaths(files) + files.count - 1 > end / 2 {
			files = [countUp[countUp.count - 1]]
		}
		awakeningStart = max(0, end - speakingBreaths(files) - silence * (files.count - 1))
		nextFreeBreath = awakeningStart
		addFiles(files, silence: silence, before: end)
	}

	private func relaxationFile() -> String? {
		guard relaxationHistory.count >= 10 else { return nil }
		let now = relaxationHistory[relaxationHistory.count - 1]
		let before = relaxationHistory[relaxationHistory.count - 10]
		let highest = relaxationHistory.max() ?? now
		let lowest = relaxationHistory.min() ?? now
		let difference = now - before
		let change: VoiceCase.Relaxation
		if abs(difference) >= 0.1 {
			change = difference > 0 ? .rising : .falling
		} else if relaxationHistory.count == 18, now < 0.6, highest - lowest < 0.05 {
			change = .stalled
		} else {
			return nil
		}
		var options: [String] = []
		for file in VoiceCase.relaxation(change).files where !used.contains(file) {
			options.append(file)
		}
		guard let file = options.randomElement() else { return nil }
		used.insert(file)
		relaxationHistory = []
		return file
	}
}
