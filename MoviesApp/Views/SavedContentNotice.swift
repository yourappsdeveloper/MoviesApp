//
//  SavedContentNotice.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import SwiftUI

struct SavedContentNotice: View {
    let isVisible: Bool

    var body: some View {
        if isVisible {
            Label("Showing saved content. It may be out of date.", systemImage: "wifi.slash")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(.regularMaterial)
                .accessibilityIdentifier("saved-content-notice")
        }
    }
}
