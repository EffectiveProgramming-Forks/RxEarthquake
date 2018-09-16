//
//  EarthquakeListViewModel.swift
//  RxEarthquake
//
//  Created by Daniel Tartaglia on 9/4/18.
//  Copyright © 2018 Daniel Tartaglia. MIT License.
//

import Foundation
import RxSwift
import RxCocoa
import RxSwiftExt

class EarthquakeListViewModel {
	struct UIInputs {
		let selectEarthquake: Observable<Earthquake>
		let refreshTrigger: Observable<Void>
		let viewAppearTrigger: Observable<Void>
	}

	// UI outputs
	let earthquakes: Driver<[Earthquake]>
	let endRefreshing: Driver<Void>
	let errorMessage: Driver<String>

	// coordinator outputs
	let displayEarthquake: Driver<Earthquake>

	init(_ inputs: UIInputs, dataTask: @escaping DataTask) {

		let networkResponse = Observable.merge(inputs.refreshTrigger, inputs.viewAppearTrigger)
			.map { URLRequest.earthquakeSummary }
			.flatMapLatest { dataTask($0) }
			.share()

		let earthquakeSummaryServerResponse = networkResponse
			.map { $0.successResponse }
			.unwrap()

		let error = networkResponse
			.map { $0.failureResponse }
			.unwrap()
			.map { $0.localizedDescription }

		let failure = earthquakeSummaryServerResponse
			.filter { $0.1.statusCode / 100 != 2 }
			.map { "There was a server error (\($0))" }

		earthquakes = earthquakeSummaryServerResponse
			.filter { $0.1.statusCode / 100 == 2 }
			.map { Earthquake.earthquakes(from: $0.0) }
			.asDriverLogError()

		endRefreshing = networkResponse
			.map { _ in }
			.throttle(0.5, scheduler: MainScheduler.instance)
			.asDriverLogError()

		errorMessage = Observable.merge(error, failure)
			.asDriverLogError()

		displayEarthquake = inputs.selectEarthquake
			.asDriverLogError()
	}
}

typealias DataTask = (URLRequest) -> Observable<NetworkResponse>
