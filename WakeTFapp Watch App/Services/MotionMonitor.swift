import Foundation
import CoreMotion

struct MotionSample: Sendable {
	let timestamp: TimeInterval
	let userAcceleration: SIMD3<Double>
	let rotationRate: SIMD3<Double>?
}

struct MotionFeatures: Sendable {
	let rmsAcceleration: Double
	let accelerationVariance: Double
	let peakMagnitude: Double
	let movementBurstCount: Int
	let timeSinceLastBurst: TimeInterval?
	let orientationChangeMagnitude: Double
	let sampleCount: Int
	let windowDuration: TimeInterval

	static let empty = MotionFeatures(
		rmsAcceleration: 0,
		accelerationVariance: 0,
		peakMagnitude: 0,
		movementBurstCount: 0,
		timeSinceLastBurst: nil,
		orientationChangeMagnitude: 0,
		sampleCount: 0,
		windowDuration: 0
	)
}

protocol MotionMonitorProtocol: Sendable {
	func startMonitoring() async throws
	func stopMonitoring()
	func currentFeatures() -> MotionFeatures
	var isAvailable: Bool { get }
}

final class MotionMonitor: MotionMonitorProtocol, @unchecked Sendable {
	private let motionManager: CMMotionManager
	private let operationQueue: OperationQueue
	private let sampleRate: TimeInterval = 0.1
	private let burstThreshold: Double = 0.4
	private let windowDuration: TimeInterval = 15.0

	private var samples: [MotionSample] = []
	private var lastBurstTime: TimeInterval?
	private var burstCount: Int = 0
	private let lock = NSLock()

	var isAvailable: Bool {
		motionManager.isDeviceMotionAvailable
	}

	init() {
		self.motionManager = CMMotionManager()
		self.operationQueue = OperationQueue()
		operationQueue.name = "com.waketfapp.motion"
		operationQueue.maxConcurrentOperationCount = 1
		operationQueue.qualityOfService = .userInitiated
	}

	func startMonitoring() async throws {
		guard isAvailable else { return }

		motionManager.deviceMotionUpdateInterval = sampleRate

		motionManager.startDeviceMotionUpdates(to: operationQueue) { [weak self] motion, _ in
			guard let self, let motion else { return }
			let sample = MotionSample(
				timestamp: motion.timestamp,
				userAcceleration: SIMD3(
					motion.userAcceleration.x,
					motion.userAcceleration.y,
					motion.userAcceleration.z
				),
				rotationRate: SIMD3(
					motion.rotationRate.x,
					motion.rotationRate.y,
					motion.rotationRate.z
				)
			)
			self.addSample(sample)
		}
	}

	func stopMonitoring() {
		motionManager.stopDeviceMotionUpdates()
		lock.lock()
		samples.removeAll()
		lock.unlock()
	}

	func currentFeatures() -> MotionFeatures {
		lock.lock()
		let currentSamples = samples
		lock.unlock()

		guard currentSamples.count >= 2 else { return .empty }

		let magnitudes = currentSamples.map { sample in
			sqrt(
				sample.userAcceleration.x * sample.userAcceleration.x +
				sample.userAcceleration.y * sample.userAcceleration.y +
				sample.userAcceleration.z * sample.userAcceleration.z
			)
		}

		let rms = sqrt(magnitudes.reduce(0) { $0 + $1 * $1 } / Double(magnitudes.count))
		let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
		let variance = magnitudes.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(magnitudes.count)
		let peak = magnitudes.max() ?? 0

		var orientationChange: Double = 0
		if let firstRotation = currentSamples.first?.rotationRate,
		   let lastRotation = currentSamples.last?.rotationRate {
			let diff = lastRotation - firstRotation
			orientationChange = sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z)
		}

		let windowDur: TimeInterval
		if let first = currentSamples.first, let last = currentSamples.last {
			windowDur = last.timestamp - first.timestamp
		} else {
			windowDur = 0
		}

		lock.lock()
		let bursts = burstCount
		let lastBurst = lastBurstTime
		lock.unlock()

		let timeSinceBurst: TimeInterval?
		if let lastBurst, let lastSample = currentSamples.last {
			timeSinceBurst = lastSample.timestamp - lastBurst
		} else {
			timeSinceBurst = nil
		}

		return MotionFeatures(
			rmsAcceleration: rms,
			accelerationVariance: variance,
			peakMagnitude: peak,
			movementBurstCount: bursts,
			timeSinceLastBurst: timeSinceBurst,
			orientationChangeMagnitude: orientationChange,
			sampleCount: currentSamples.count,
			windowDuration: windowDur
		)
	}

	private func addSample(_ sample: MotionSample) {
		let magnitude = sqrt(
			sample.userAcceleration.x * sample.userAcceleration.x +
			sample.userAcceleration.y * sample.userAcceleration.y +
			sample.userAcceleration.z * sample.userAcceleration.z
		)

		lock.lock()
		samples.append(sample)

		if magnitude > burstThreshold {
			burstCount += 1
			lastBurstTime = sample.timestamp
		}

		let cutoff = sample.timestamp - windowDuration
		samples.removeAll { $0.timestamp < cutoff }
		lock.unlock()
	}
}
