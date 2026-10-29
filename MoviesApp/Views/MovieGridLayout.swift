//
//  MovieGridLayout.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import UIKit

@MainActor
enum MovieGridLayout {
    private static let inset: CGFloat = 16
    private static let spacing: CGFloat = 12
    private static let minimumCardWidth: CGFloat = 160

    static func cardWidth(containerWidth: CGFloat, usesLargeText: Bool) -> CGFloat {
        let availableWidth = max(1, containerWidth - inset * 2)
        let count = columns(availableWidth: availableWidth, usesLargeText: usesLargeText)
        return (availableWidth - spacing * CGFloat(count - 1)) / CGFloat(count)
    }

    private static func columns(availableWidth: CGFloat, usesLargeText: Bool) -> Int {
        usesLargeText ? 1 : max(1, Int((availableWidth + spacing) / (minimumCardWidth + spacing)))
    }

    /// Adapts the column count to the available width and text size.
    static func make() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, environment in
            let inset = Self.inset
            let spacing = Self.spacing

            let availableWidth = max(
                1,
                environment.container.effectiveContentSize.width - inset * 2
            )

            let usesLargeText = environment.traitCollection
                .preferredContentSizeCategory.isAccessibilityCategory

            let columns = Self.columns(availableWidth: availableWidth, usesLargeText: usesLargeText)
            let cardWidth = Self.cardWidth(containerWidth: availableWidth + inset * 2, usesLargeText: usesLargeText)

            let textHeight = UIFontMetrics(forTextStyle: .subheadline)
                .scaledValue(
                    for: 150,
                    compatibleWith: environment.traitCollection
                )

            let cardHeight = cardWidth * 1.5 + textHeight

            let item = NSCollectionLayoutItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .absolute(cardWidth),
                    heightDimension: .estimated(cardHeight)
                )
            )

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(cardHeight)
                ),
                repeatingSubitem: item,
                count: columns
            )
            group.interItemSpacing = .fixed(spacing)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            section.contentInsets = NSDirectionalEdgeInsets(
                top: inset,
                leading: inset,
                bottom: inset,
                trailing: inset
            )

            return section
        }
    }
}
