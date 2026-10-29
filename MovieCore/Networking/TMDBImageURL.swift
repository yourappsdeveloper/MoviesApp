//
//  TMDBImageURL.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//


import Foundation

public enum TMDBImageURL {
    private static let posterWidths = [92, 154, 185, 342, 500, 780]
    private static let backdropWidths = [300, 780, 1280]

    // Selects a poster size for the displayed width and scale.
    public static func poster(
        path: String?,
        width: Double,
        scale: Double
    ) -> URL? {
        imageURL(
            path: path,
            width: width,
            scale: scale,
            availableWidths: posterWidths
        )
    }

    // Selects a backdrop size for the displayed width and scale.
    public static func backdrop(
        path: String?,
        width: Double,
        scale: Double
    ) -> URL? {
        imageURL(
            path: path,
            width: width,
            scale: scale,
            availableWidths: backdropWidths
        )
    }

    // Builds an image URL using the smallest sufficient size.
    private static func imageURL(
        path: String?,
        width: Double,
        scale: Double,
        availableWidths: [Int]
    ) -> URL? {
        guard let path,
              !path.isEmpty,
              width.isFinite,
              scale.isFinite,
              width > 0,
              scale > 0 else {
            return nil
        }

        let pixelWidth = (width * scale).rounded(.up)

        guard pixelWidth.isFinite else {
            return nil
        }

        let selectedWidth = availableWidths.first {
            Double($0) >= pixelWidth
        }

        let size = selectedWidth.map { "w\($0)" } ?? "original"

        return URL(
            string: "https://image.tmdb.org/t/p/\(size)\(path)"
        )
    }
}
