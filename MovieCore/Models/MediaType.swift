//
//  MediaType.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

/// Identifies the content type used for search and details.
public enum MediaType: String, CaseIterable, Hashable, Sendable {
    case movie
    case series = "tv"
}
