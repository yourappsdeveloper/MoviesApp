//
//  TMDBImageURL.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//


import Foundation

/// Builds poster URLs using the displayed width and display scale.
public enum TMDBImageURL {
    private static let posterWidths = [92, 154, 185, 342, 500, 780]

    public static func poster(
        path: String?,
        width: Double,
        scale: Double
    ) -> URL? {
        
        guard let path, !path.isEmpty,
              width > 0, scale > 0 else {
            return nil
        }

        let pixelWidth = (width * scale).rounded(.up)

        guard pixelWidth.isFinite else {
            return nil
        }

        let size: String

        if let width = posterWidths.first(where: {
            Double($0) >= pixelWidth
        }) {
            size = "w\(width)"
        } else {
            size = "original"
        }

        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }
}
