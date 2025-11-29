//
//  CustomNavigationTitle.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/26/25.
//

import SwiftUI

// Custom Navigation Title Modifier
struct CustomNavigationTitle: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .navigationBarBackButtonHidden(true)
                .background(NavTitleViewSetter(title: title))
        } else {
            content
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Text(title)
                            .font(.luckiestGuyLarge)
                            .fixedSize()
                    }
                }
        }
    }
}

extension View {
    func customNavigationTitle(_ title: String) -> some View {
        modifier(CustomNavigationTitle(title: title))
    }
}

// UIKit NavTitleView
private final class NavTitleView: UIView {
    let titleLabel: UILabel

    init(title: String) {
        self.titleLabel = UILabel()
        super.init(frame: .zero)

        titleLabel.text = title
        titleLabel.font = UIFont(name: "LuckiestGuy-Regular", size: 28)
        titleLabel.textColor = .label
        titleLabel.sizeToFit()

        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// SwiftUI에서 navigationItem.titleView 설정
private struct NavTitleViewSetter: UIViewControllerRepresentable {
    let title: String

    func makeUIViewController(context: Context) -> TitleSetterViewController {
        TitleSetterViewController(title: title)
    }

    func updateUIViewController(_ uiViewController: TitleSetterViewController, context: Context) {
        uiViewController.updateTitle(title)
    }

    class TitleSetterViewController: UIViewController {
        private var titleText: String

        init(title: String) {
            self.titleText = title
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            setupTitle()
        }

        func updateTitle(_ title: String) {
            titleText = title
            setupTitle()
        }

        private func setupTitle() {
            guard let parent = parent,
                  let navigationController = parent.navigationController else {
                return
            }

            let titleView = NavTitleView(title: titleText)
            let width = navigationController.navigationBar.bounds.width
            titleView.frame = CGRect(x: 0, y: 0, width: width, height: 44)
            parent.navigationItem.titleView = titleView
        }
    }
}
