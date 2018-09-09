//
//  Coordinator.swift
//  RxEarthquake
//
//  Created by Daniel Tartaglia on 9/6/18.
//  Copyright © 2018 Daniel Tartaglia. MIT License.
//

import UIKit
import RxSwift
import RxCocoa
import RxSwiftExt
import CoreLocation
import SafariServices

class Coordinator {

	init(splitViewController: UISplitViewController) {
		let mainNav = splitViewController.childViewControllers[0] as! UINavigationController
		let main = mainNav.childViewControllers[0] as! EarthquakeListViewController
		let detailNav = splitViewController.childViewControllers[1] as! UINavigationController
		let detail = detailNav.childViewControllers[0] as! EarthquakeDetailViewController
		let selectedEarthquake = self.selectedEarthquake
		let userLocation = self.locationManager.userLocation
		let http = self.http
		let bag = self.bag

		selectedEarthquake
			.filter { $0 != nil }
			.map { _ in }
			.subscribe(onNext: {
				splitViewController.showDetailViewController(detailNav, sender: self)
			})
			.disposed(by: bag)

		detail.viewModelFactory = { inputs -> EarthquakeDetailViewModel in
			let vm = EarthquakeDetailViewModel(inputs, earthquake: selectedEarthquake.unwrap(), userLocation: userLocation)

			vm.moreInformation
				.map { $0.url }
				.unwrap()
				.drive(onNext: (presentSafariViewController(url:)))
				.disposed(by: bag)

			vm.moreInformation
				.map { $0.alert }
				.unwrap()
				.drive(onNext: (presentAlertViewController(title:message:)))
				.disposed(by: bag)

			vm.share
				.drive(onNext: (presentActivityViewController(shareInfo:)))
				.disposed(by: bag)

			return vm
		}

		main.viewModelFactory = { inputs -> EarthquakeListViewModel in
			let vm = EarthquakeListViewModel(inputs, http: http.output)
			vm.displayEarthquake
				.drive(selectedEarthquake)
				.disposed(by: bag)

			vm.networkRequest
				.drive(http)
				.disposed(by: bag)
			return vm
		}

		splitViewController.delegate = self
		splitViewController.preferredDisplayMode = .allVisible
	}

	private let locationManager = LocationManager()
	private let selectedEarthquake = BehaviorRelay<Earthquake?>(value: nil)
	private let http: RxCycle<URLRequest, NetworkResponse> = RxCycle(data(request:))
	private let bag = DisposeBag()

}

extension Coordinator: UISplitViewControllerDelegate {
	func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
		return selectedEarthquake.value == nil
	}
}

private
func presentSafariViewController(url: URL) {
	let safari = SFSafariViewController(url: url)
	UIViewController.top().present(safari, animated: true)
}

private
func presentAlertViewController(title: String, message: String) {
	let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
	alert.addAction(UIAlertAction(title: "OK", style: .default))
	UIViewController.top().present(alert, animated: true)
}

private
func presentActivityViewController(shareInfo: ShareInfo) {
	let shareSheet = UIActivityViewController(activityItems: shareInfo.items, applicationActivities: nil)
	shareSheet.popoverPresentationController?.barButtonItem = shareInfo.barButtonItem
	UIViewController.top().present(shareSheet, animated: true)
}
