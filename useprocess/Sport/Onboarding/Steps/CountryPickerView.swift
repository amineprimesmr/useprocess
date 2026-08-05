//
//  CountryPickerView.swift
//  Process
//
//  Created by Assistant on 16/10/2025.
//

import SwiftUI

struct CountryPickerView: View {
    @Binding var selectedCountryCode: String
    @Binding var selectedCountryFlag: String
    @Binding var isPresented: Bool

    private var countries: [(String, String, String)] {
        [
            ("🇫🇷", "+33", OnboardingCopy.t("France", en: "France")),
            ("🇺🇸", "+1", OnboardingCopy.t("États-Unis", en: "United States")),
            ("🇬🇧", "+44", OnboardingCopy.t("Royaume-Uni", en: "United Kingdom")),
            ("🇩🇪", "+49", OnboardingCopy.t("Allemagne", en: "Germany")),
            ("🇪🇸", "+34", OnboardingCopy.t("Espagne", en: "Spain")),
            ("🇮🇹", "+39", OnboardingCopy.t("Italie", en: "Italy")),
            ("🇨🇦", "+1", OnboardingCopy.t("Canada", en: "Canada")),
            ("🇦🇺", "+61", OnboardingCopy.t("Australie", en: "Australia")),
            ("🇯🇵", "+81", OnboardingCopy.t("Japon", en: "Japan")),
            ("🇰🇷", "+82", OnboardingCopy.t("Corée du Sud", en: "South Korea")),
            ("🇨🇳", "+86", OnboardingCopy.t("Chine", en: "China")),
            ("🇮🇳", "+91", OnboardingCopy.t("Inde", en: "India")),
            ("🇧🇷", "+55", OnboardingCopy.t("Brésil", en: "Brazil")),
            ("🇲🇽", "+52", OnboardingCopy.t("Mexique", en: "Mexico")),
            ("🇷🇺", "+7", OnboardingCopy.t("Russie", en: "Russia")),
            ("🇿🇦", "+27", OnboardingCopy.t("Afrique du Sud", en: "South Africa")),
            ("🇳🇱", "+31", OnboardingCopy.t("Pays-Bas", en: "Netherlands")),
            ("🇧🇪", "+32", OnboardingCopy.t("Belgique", en: "Belgium")),
            ("🇨🇭", "+41", OnboardingCopy.t("Suisse", en: "Switzerland")),
            ("🇦🇹", "+43", OnboardingCopy.t("Autriche", en: "Austria"))
        ]
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(countries, id: \.1) { country in
                    Button(action: {
                        selectedCountryCode = country.1
                        selectedCountryFlag = country.0
                        isPresented = false
                    }) {
                        HStack {
                            Text(country.0)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(country.2)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text(country.1)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedCountryCode == country.1 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                            }
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.processPlain)
                }
            }
            .navigationTitle(OnboardingCopy.t("Sélectionner un pays", en: "Select a country"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(OnboardingCopy.t("Fermer", en: "Close")) {
                        isPresented = false
                    }
}
}
}
}
}
