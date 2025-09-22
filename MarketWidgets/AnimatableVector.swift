//
//  AnimatableVector.swift
//  MarketsWidgetKit
//
//  Created by Edwin Bosire on 21/09/2025.
//

import Foundation
import SwiftUI

// MARK: - Animatable Vector (array of CGFloat)

public struct AnimatableVector: VectorArithmetic {
	public init(_ values: [CGFloat]) {
		self.values = values
	}

	public init(_ values: [Double]) {
		self.values = values.map { CGFloat($0) }
	}

	init(values: [CGFloat]) {
		self.values = values
	}

	public var values: [CGFloat]

	public var count: Int { values.count }

	public subscript(index: Int) -> CGFloat {
		get { values[index] }
		set { values[index] = newValue }
	}

	public var average: CGFloat {
		guard !values.isEmpty else { return 0 }
		return values.reduce(0, +) / CGFloat(values.count)
	}

	public func shuffled() -> AnimatableVector {
		AnimatableVector(values: values.shuffled())
	}

	public static var zero: AnimatableVector { AnimatableVector(values: []) }

	public static func + (lhs: AnimatableVector, rhs: AnimatableVector) -> AnimatableVector {
		precondition(lhs.values.count == rhs.values.count, "Mismatched vector sizes")
		return AnimatableVector(values: zip(lhs.values, rhs.values).map(+))
	}

	public static func - (lhs: AnimatableVector, rhs: AnimatableVector) -> AnimatableVector {
		precondition(lhs.values.count == rhs.values.count, "Mismatched vector sizes")
		return AnimatableVector(values: zip(lhs.values, rhs.values).map(-))
	}

	public mutating func scale(by rhs: Double) {
		for i in values.indices { values[i] *= CGFloat(rhs) }
	}

	public var magnitudeSquared: Double {
		Double(values.reduce(0) { $0 + $1*$1 })
	}

	public static func == (lhs: AnimatableVector, rhs: AnimatableVector) -> Bool {
		lhs.values == rhs.values
	}
}
extension AnimatableVector: ExpressibleByArrayLiteral {
	public init(arrayLiteral elements: CGFloat...) {
		self.values = elements
	}
}
