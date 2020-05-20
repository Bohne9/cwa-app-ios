//
//  HomeViewController.swift
//  ENA
//
//  Created by Tikhonov, Aleksandr on 03.05.20.
//  Copyright © 2020 SAP SE. All rights reserved.
//

import UIKit

final class HomeViewController: UIViewController {

    // MARK: Creating a Home View Controller
    
    init?(
        coder: NSCoder,
        exposureManager: ExposureManager,
        client: Client,
        store: Store,
        signedPayloadStore: SignedPayloadStore
    ) {
        self.client = client
        self.store = store
        self.signedPayloadStore = signedPayloadStore
        super.init(coder: coder)
        homeInteractor = HomeInteractor(
            homeViewController: self,
            exposureManager: exposureManager,
            client: client,
            store: store
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has intentionally not been implemented")
    }

    // MARK: Properties
    private let signedPayloadStore: SignedPayloadStore

    private var dataSource: UICollectionViewDiffableDataSource<Section, Int>!
    private var collectionView: UICollectionView!
    private var homeLayout: HomeLayout!
    private var homeInteractor: HomeInteractor!
    private var cellConfigurators: [CollectionViewCellConfiguratorAny] = []
    private let store: Store
    private let client: Client

    enum Section: Int {
        case actions
        case infos
        case settings
    }

    // MARK: UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareData()
        configureHierarchy()
        configureDataSource()
        configureUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        homeInteractor.developerMenuEnableIfAllowed()
    }

    // MARK: Actions
    @objc
    private func infoButtonTapped(_ sender: UIButton) {
        let vc = RiskLegendTableViewController.initiate(for: .riskLegend)
        let naviController = UINavigationController(rootViewController: vc)
        self.present(naviController, animated: true, completion: nil)
    }

    // MARK: Misc
    func showSubmitResult() {
        let vc = ExposureSubmissionViewController.initiate(for: .exposureSubmission) { [unowned self] coder in
            let service = ENAExposureSubmissionService(manager: ENAExposureManager(), client: self.client)
            return ExposureSubmissionViewController(coder: coder, exposureSubmissionService: service)
        }
        let naviController = UINavigationController(rootViewController: vc)
        present(naviController, animated: true, completion: nil)
    }

    func showExposureNotificationSetting() {

        let manager = ENAExposureManager()
        manager.activate { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                switch error {
                case .exposureNotificationRequired:
                    log(message: "Encourage the user to consider enabling Exposure Notifications.", level: .warning)
                case .exposureNotificationAuthorization:
                    log(message: "Encourage the user to authorize this application", level: .warning)
                }
            } else if let error = error {
                logError(message: error.localizedDescription)
            } else {

                let storyboard = AppStoryboard.exposureNotificationSetting.instance
                let vc = storyboard.instantiateViewController(identifier: "ExposureNotificationSettingViewController", creator: { coder in
                    ExposureNotificationSettingViewController(coder: coder, manager: manager)
                }
                )
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    func showSetting() {
        /*let vc = SettingsViewController.initiate(for: .settings)
        let naviController = UINavigationController(rootViewController: vc)
        present(naviController, animated: true, completion: nil)*/

        let manager = ENAExposureManager()
        manager.activate { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                switch error {
                case .exposureNotificationRequired:
                    log(message: "Encourage the user to consider enabling Exposure Notifications.", level: .warning)
                case .exposureNotificationAuthorization:
                    log(message: "Encourage the user to authorize this application", level: .warning)
                }
            } else if let error = error {
                logError(message: error.localizedDescription)
            } else {

                let storyboard = AppStoryboard.settings.instance
                let vc = storyboard.instantiateViewController(identifier: "SettingsViewController", creator: { coder in
                    SettingsViewController(coder: coder, manager: manager, store: self.store)
                }
                )
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    func showDeveloperMenu() {
        guard let developerMenuController = AppStoryboard.developerMenu.initiateInitial() else { return }
        present(developerMenuController, animated: true, completion: nil)
    }

    func showInviteFriends() {
        let vc = FriendsInviteController.initiate(for: .inviteFriends)
        navigationController?.pushViewController(vc, animated: true)
    }

    func showExposureDetection() {
		// swiftlint:disable multiline_arguments_brackets
		let exposureDetectionViewController = AppStoryboard.exposureDetection.initiateInitial(creator: { coder in
			ExposureDetectionViewController(coder: coder, store: self.store, client: self.client, signedPayloadStore: self.signedPayloadStore)
		})
		// swiftlint:enable multiline_arguments_brackets

		if let exposureDetectionViewController = exposureDetectionViewController {
			present(exposureDetectionViewController, animated: true)
		}
    }

    func showAppInformation() {
		if let appInformatioViewController = AppStoryboard.appInformation.initiateInitial() {
			navigationController?.pushViewController(appInformatioViewController, animated: true)
		}
    }

    private func showScreen(at indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section) else { return }
        let row = indexPath.row
        switch section {
        case .actions:
            if row == 0 {
                showExposureNotificationSetting()
            } else if row == 1 {
                showExposureDetection()
            } else {
                showSubmitResult()
            }
        case .infos:
            if row == 0 {
                showInviteFriends()
            } else {
            }
        case .settings:
            if row == 0 {
                showAppInformation()
            } else {
				showSetting()
            }
        }
    }

    // MARK: Configuration

    func prepareData() {
        cellConfigurators = homeInteractor.cellConfigurators()
    }

    func reloadData() {
        collectionView.reloadData()
    }

    private func createLayout() -> UICollectionViewLayout {
        homeLayout = HomeLayout()
        homeLayout.delegate = self
        return homeLayout.collectionLayout()
    }

    private func configureHierarchy() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.delegate = self
        let safeLayoutGuide = view.safeAreaLayoutGuide
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate(
            [
                collectionView.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor),
                collectionView.topAnchor.constraint(equalTo: safeLayoutGuide.topAnchor),
                collectionView.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor),
                collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ]
        )
        collectionView.register(cellTypes: cellConfigurators.map { $0.viewAnyType })
        let nib6 = UINib(nibName: HomeFooterSupplementaryView.reusableViewIdentifier, bundle: nil)
        collectionView.register(nib6, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: HomeFooterSupplementaryView.reusableViewIdentifier)
    }

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Int>(collectionView: collectionView) { [unowned self] collectionView, indexPath, identifier in
            let configurator = self.cellConfigurators[identifier]
            let cell = collectionView.dequeueReusableCell(cellType: configurator.viewAnyType, for: indexPath)
            configurator.configureAny(cell: cell)
            return cell
        }
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            let identifier = HomeFooterSupplementaryView.reusableViewIdentifier
            guard let supplementaryView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: identifier,
                for: indexPath
                ) as? HomeFooterSupplementaryView else {
                    fatalError("Cannot create new supplementary")
            }
            supplementaryView.configure()
            return supplementaryView
        }
        var snapshot = NSDiffableDataSourceSnapshot<Section, Int>()
        snapshot.appendSections([.actions])
        snapshot.appendItems(Array(0...2))
        snapshot.appendSections([.infos])
        snapshot.appendItems(Array(3...4))
		snapshot.appendSections([.settings])
		snapshot.appendItems(Array(5...6))
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func configureUI () {
        title = "Corona-Warn-App"
        collectionView.backgroundColor = .systemGroupedBackground
        let infoImage = UIImage(systemName: "info.circle")
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: infoImage, style: .plain, target: self, action: #selector(infoButtonTapped(_:)))
    }
}

extension HomeViewController: HomeLayoutDelegate {
    func homeLayout(homeLayout: HomeLayout, for sectionIndex: Int) -> Section? {
        Section(rawValue: sectionIndex)
    }
}

extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        showScreen(at: indexPath)
    }
}
