//
//  SportSelectionStepView.swift
//  Process
//
//  Created by Assistant on 25/01/2025.
//

import SwiftUI

struct SportSelectionStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var profileService: UnifiedProfileService
    @ObservedObject private var onboardingData = OnboardingDataModel.shared
    @State private var selectedSports: Set<String> = []
    @State private var userFirstName = "Utilisateur"
    @State private var selectedSport: String? // Pour sélection unique

    // Callback pour passer à l'étape suivante
    let onComplete: () -> Void

    // Callback pour notifier la validation
    var onValidationChanged: ((Bool) -> Void)?

    // Callback pour notifier l'état de la recherche (pour cacher le bouton retour)
    var onSearchStateChanged: ((Bool) -> Void)?

    // ✨ Les 4 sports les plus pratiqués
    private let topSports = [
        "🏃‍♂️ Course à pied",
        "🏋️‍♂️ Musculation",
        "⚽ Football",
        "🥊 Boxe"
    ]

    // ✨ 10 sports les plus courants (à afficher sous la boxe)
    private let commonSports = [
        "🏊‍♂️ Natation",
        "🚴‍♂️ Cyclisme",
        "🎾 Tennis",
        "🧘 Yoga",
        "💃 Danse",
        "🏀 Basketball",
        "🏐 Volleyball",
        "🏉 Rugby",
        "🥋 Judo",
        "🚶‍♂️ Randonnée"
    ]

    // ✨ Liste COMPLÈTE et EXHAUSTIVE de tous les sports disponibles
    private let allAvailableSports: [String] = {
        var sports: [String] = []

        // Sports de course et athlétisme
        sports.append(contentsOf: [
        "🏃‍♂️ Course à pied",
            "🏃‍♀️ Running",
            "🏃‍♂️ Trail",
            "🏃‍♂️ Marathon",
            "🏃‍♂️ Semi-marathon",
            "🏃‍♂️ 10 km",
            "🏃‍♂️ 5 km",
            "🏃‍♂️ Course d'orientation",
        "🥇 Athlétisme",
        "🥈 Sprint",
        "🥉 Lancer",
            "🏃‍♂️ Saut en hauteur",
            "🏃‍♂️ Saut en longueur",
            "🏃‍♂️ Saut à la perche",
            "🏃‍♂️ Triple saut",
            "🏃‍♂️ Lancer de poids",
            "🏃‍♂️ Lancer de disque",
            "🏃‍♂️ Lancer de javelot",
            "🏃‍♂️ Lancer de marteau"
        ])

        // Sports cyclistes
        sports.append(contentsOf: [
            "🚴‍♂️ Cyclisme",
            "🚴‍♀️ Cyclisme sur route",
            "🚴‍♂️ VTT",
            "🚴‍♂️ BMX",
            "🚴‍♂️ Vélo de route",
            "🚴‍♂️ Cyclocross",
            "🚴‍♂️ Vélo tout terrain"
        ])

        // Sports aquatiques
        sports.append(contentsOf: [
            "🏊‍♂️ Natation",
            "🏊‍♀️ Natation synchronisée",
            "🤽 Water-polo",
            "🏄‍♂️ Surf",
        "🏄‍♀️ Surf",
            "🏄‍♂️ Bodyboard",
            "🏄‍♂️ Stand up paddle",
            "🏄‍♂️ Kitesurf",
            "🏄‍♂️ Windsurf",
            "🚣‍♂️ Aviron",
            "🚣‍♂️ Canoë-kayak",
            "🏊‍♂️ Plongée",
            "🏊‍♂️ Aquagym",
            "🏊‍♂️ Aquabike",
            "🏊‍♂️ Triathlon",
            "🏊‍♂️ Duathlon",
            "🏊‍♂️ Aquathlon"
        ])

        // Musculation et force
        sports.append(contentsOf: [
            "🏋️‍♂️ Musculation",
            "🏋️‍♀️ Musculation",
            "🏋️‍♀️ CrossFit",
            "🏋️‍♂️ Powerlifting",
            "🏋️‍♂️ Bodybuilding",
            "💪 Fitness",
            "💪 Force athlétique"
        ])

        // Sports de combat
        sports.append(contentsOf: [
            "🥊 Boxe",
            "🥊 Boxe anglaise",
            "🥊 Boxe française",
            "🥋 Arts martiaux",
        "🥋 Karaté",
        "🥋 Judo",
        "🥋 Taekwondo",
        "🥋 Jiu-jitsu",
            "🥋 Aïkido",
            "🥋 Kung-fu",
            "🥋 Muay-thaï",
            "🥋 MMA",
            "🤺 Escrime"
        ])

        // Sports collectifs
        sports.append(contentsOf: [
            "⚽ Football",
            "⚽ Futsal",
            "🏀 Basketball",
            "🏀 Streetball",
            "🏐 Volleyball",
            "🏐 Beach-volley",
            "🏒 Hockey",
            "🏒 Hockey sur glace",
            "🏑 Hockey sur gazon",
            "⚾ Baseball",
            "⚾ Softball",
            "🤾 Handball",
            "🏉 Rugby",
            "🏉 Rugby à XV",
            "🏉 Rugby à XIII"
        ])

        // Sports de raquette
        sports.append(contentsOf: [
            "🎾 Tennis",
            "🎾 Tennis de table",
            "🏓 Ping-pong",
        "🏸 Badminton",
        "🏑 Squash",
        "🎾 Padel",
            "🎾 Beach-tennis"
        ])

        // Sports de précision
        sports.append(contentsOf: [
            "🏹 Tir à l'arc",
            "🎯 Tir sportif",
            "⛳ Golf",
            "🏌️ Golf",
            "🎯 Billard",
            "🎯 Pétanque",
            "🎯 Bowling"
        ])

        // Sports de glisse et neige
        sports.append(contentsOf: [
            "⛷️ Ski",
            "⛷️ Ski alpin",
            "⛷️ Ski de fond",
            "🏂 Snowboard",
            "⛸️ Patinage",
            "⛸️ Patinage artistique",
            "⛸️ Patinage de vitesse",
            "🏔️ Escalade",
            "🧗 Escalade",
            "🧗 Escalade en bloc",
            "🧗 Escalade en salle",
            "🏔️ Randonnée",
            "🏔️ Alpinisme"
        ])

        // Sports gymniques
        sports.append(contentsOf: [
            "🤸‍♂️ Gymnastique",
            "🤸‍♀️ Gymnastique",
            "🤸‍♂️ Gymnastique artistique",
            "🤸‍♂️ Gymnastique rythmique",
            "🤸‍♂️ Gymnastique acrobatique",
            "🧘‍♂️ Yoga",
            "🧘‍♀️ Yoga",
            "🧘‍♂️ Pilates",
            "🤸‍♂️ Acrobatie",
            "🧘‍♂️ Méditation"
        ])

        // Fitness et bien-être
        sports.append(contentsOf: [
            "🏃‍♀️ Fitness",
            "🏃‍♀️ Cardio",
            "💃 Danse",
            "💃 Danse classique",
            "💃 Danse moderne",
            "💃 Zumba",
            "🏃‍♀️ Aérobic",
            "💃 Hip-hop",
            "💃 Salsa"
        ])

        // Sports équestres
        sports.append(contentsOf: [
            "🏇 Equitation",
            "🏇 Dressage",
            "🏇 Saut d'obstacles",
            "🏇 Concours complet"
        ])

        return sports
    }()

    @State private var searchText: String = ""
    @State private var showSearchField = false
    @State private var searchResults: [String] = []
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            // Fond noir pour la page (comme les autres pages d'onboarding)
            OnboardingTheme.screenBackground
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Espace pour le titre en overlay + espacement uniforme
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                    // Espacement uniforme entre titre et réponses
                    Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing)

                ScrollView(showsIndicators: false) {
                    // Espace pour la barre de recherche quand elle est active
                    if showSearchField {
                        Spacer()
                            .frame(height: 20)
                    }

                    // Afficher les résultats de recherche OU les sports de base
                    if showSearchField && !searchText.isEmpty {
                        // Résultats de recherche en temps réel (en colonne)
                        if !searchResults.isEmpty {
                            VStack(spacing: 16) {
                                ForEach(searchResults, id: \.self) { sport in
                                    SportRowButton(
                                sport: sport,
                                isSelected: selectedSports.contains(sport),
                                    onTap: {
                                        toggleSport(sport)
                                        // Ne pas fermer la recherche immédiatement pour voir la sélection
                                        // Mais fermer après un court délai pour une meilleure UX
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                                showSearchField = false
                                                searchText = ""
                                                searchResults = []
                                                isSearchFocused = false
                                                onSearchStateChanged?(false)
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 40)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            // Aucun résultat - possibilité d'ajouter manuellement
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(OnboardingTheme.mutedText)

                        Text("Aucun résultat")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(OnboardingTheme.footnoteText)

                        Text("Tu peux quand même ajouter ce sport manuellement")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(OnboardingTheme.mutedText)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            let customSport = searchText.trimmingCharacters(in: .whitespaces)
                            if !customSport.isEmpty {
                                toggleSport(customSport)
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    showSearchField = false
                                    searchText = ""
                                    searchResults = []
                                    isSearchFocused = false
                                            onSearchStateChanged?(false)
                                }
                            }
                        }) {
                            Text("Ajouter \"\(searchText)\"")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(OnboardingTheme.primaryText)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                        .glassStyle()

                    }
                    .padding(.vertical, 40)
                    .padding(.horizontal, 40)
                    .transition(.opacity)
                }
                    } else {
                        // ✅ Afficher le sport sélectionné en premier s'il n'est pas dans les listes principales
                        if let selectedSport = selectedSport,
                           !topSports.contains(selectedSport) &&
                           !commonSports.contains(selectedSport) {
                            VStack(spacing: 16) {
                                SportRowButton(
                                    sport: selectedSport,
                                    isSelected: true,
                                    onTap: { toggleSport(selectedSport) }
                                )
                            }
                            .padding(.horizontal, 40)
                            .padding(.bottom, 8)
                        }

                        // Liste des 4 sports les plus populaires (en colonne)
                        VStack(spacing: 16) {
                            ForEach(topSports, id: \.self) { sport in
                                SportRowButton(
                                    sport: sport,
                                    isSelected: selectedSports.contains(sport),
                                    onTap: { toggleSport(sport) }
                                )
                            }
                        }
                        .padding(.horizontal, 40)

                        // 10 sports les plus courants (sous la boxe)
                        VStack(spacing: 16) {
                            ForEach(commonSports, id: \.self) { sport in
                                SportRowButton(
                                    sport: sport,
                                    isSelected: selectedSports.contains(sport),
                                    onTap: { toggleSport(sport) }
                                )
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 8)

                        // Bouton de recherche
                        Button(action: {
                            HapticManager.shared.selection()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                showSearchField.toggle()
                                onSearchStateChanged?(showSearchField)
                                if showSearchField {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        isSearchFocused = true
                                    }
                                } else {
                                    searchText = ""
                                    searchResults = []
                                    isSearchFocused = false
                                }
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(OnboardingTheme.bodyText)

                                Text("Chercher un sport")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(OnboardingTheme.primaryText)

                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .glassStyle()

                        .controlSize(.large)
                        .opacity(showSearchField ? 0 : 0.6)
                        .scaleEffect(showSearchField ? 0.8 : 1.0)
                        .padding(.horizontal, 40)
                    }

                    // Espace pour le bouton global CONTINUER
                    Spacer()
                        .frame(height: 120)
                }
            }

            // Barre de recherche en haut (quand active) - Style Glass iOS 18+ NATIF
            if showSearchField {
                VStack(spacing: 0) {
                    ZStack {
                        // Button invisible pour le style glass natif en arrière-plan
                        Button(action: {}) {
                            Text("")
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .glassStyle()

                        .controlSize(.large)
                        .allowsHitTesting(false)

                        // Contenu interactif par-dessus
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(OnboardingTheme.bodyText)
                            .font(.system(size: 18, weight: .medium))

                        TextField("Rechercher un sport...", text: $searchText)
                            .textFieldStyle(.plain)
                            .foregroundStyle(OnboardingTheme.primaryText)
                            .focused($isSearchFocused)
                                .tint(OnboardingTheme.primaryText)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            .onChange(of: searchText) { _, newValue in
                                performSearch(query: newValue)
                            }
                                .onSubmit {
                                    performSearch(query: searchText)
                                }

                        if !searchText.isEmpty {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    searchText = ""
                                    searchResults = []
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(OnboardingTheme.footnoteText)
                                    .font(.system(size: 18))
                            }
                                .buttonStyle(.plain)
                        }

                        Button(action: {
                            HapticManager.shared.selection()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                showSearchField = false
                                searchText = ""
                                searchResults = []
                                isSearchFocused = false
                                    onSearchStateChanged?(false)
                            }
                        }) {
                            Text("Annuler")
                                .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(OnboardingTheme.primaryText)
                            }
                            .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }

            // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
            VStack {
                OnboardingTitleView("Quel sport", "pratiques-tu ?")
                    .padding(.top, OnboardingConstants.titleTopPadding)
                Spacer()
            }

            // ✅ Fond noir progressif en bas pour belle UX (dégradé fluide)
            VStack {
                Spacer()

                // Gradient progressif pour effet de transition fluide
                LinearGradient(
                    colors: [Color.clear] + OnboardingTheme.imageScrimGradient(for: colorScheme),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            loadUserFirstName()
            loadSelectedSports()
            // Notifier l'état initial de la recherche
            onSearchStateChanged?(showSearchField)
        }
        .onChange(of: showSearchField) { _, newValue in
            // Notifier quand la recherche s'ouvre ou se ferme
            onSearchStateChanged?(newValue)
        }
        .onChange(of: profileService.currentProfile?.firstName) { _, newValue in
            if let newFirstName = newValue, !newFirstName.isEmpty {
                userFirstName = newFirstName
            }
        }
    }

    private func toggleSport(_ sport: String) {
        // Sélection unique : si le sport est déjà sélectionné, on le désélectionne
        // Sinon, on désélectionne l'ancien et on sélectionne le nouveau
        if selectedSport == sport {
            selectedSport = nil
            selectedSports = []
        } else {
            selectedSport = sport
            selectedSports = [sport]
        }

        // ✨ Mettre à jour onboardingData immédiatement et persister pour syncProfileWithViewModel / redémarrage
        onboardingData.selectedSports = selectedSports
        onboardingData.persistSelectedSports()

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        // Notifier la validation
        onValidationChanged?(!selectedSports.isEmpty)

        if !selectedSports.isEmpty {
            saveSelectedSports()
        }
    }

    private func saveSelectedSports() {
        // ✨ Mettre à jour onboardingData immédiatement et persister
        onboardingData.selectedSports = selectedSports
        onboardingData.persistSelectedSports()


        // Sauvegarder les sports sélectionnés dans le profil utilisateur
        Task {
            do {
                if var currentProfile = profileService.currentProfile {
                    // Convertir Set<String> en [Sport]
                    let sportsArray = selectedSports.map { sportName in
                        Sport(
                            name: sportName,
                            category: .cardio,
                            frequency: .weekly,
                            intensity: .moderate
                        )
                    }
                    currentProfile.sports = sportsArray


                    try await profileService.saveProfile(currentProfile)

                    // ✅ CRITIQUE: Recharger pour vérifier
                    await profileService.loadProfile()

                    if let reloaded = profileService.currentProfile {

                        if reloaded.sports.count != sportsArray.count {
                        }
                    }
                } else {
                }
            } catch {
            DebugLogger.error("\(error.localizedDescription)")
        }
        }
    }

    private func loadUserFirstName() {
        if let profile = profileService.currentProfile,
           !profile.firstName.isEmpty {
            userFirstName = profile.firstName
        }
    }

    private func loadSelectedSports() {
        // Charger le sport déjà sélectionné (premier sport du profil)
        if let profile = profileService.currentProfile, let firstSport = profile.sports.first {
            selectedSport = firstSport.name
            selectedSports = [firstSport.name]
            onboardingData.selectedSports = selectedSports
            onboardingData.persistSelectedSports()
            onValidationChanged?(!selectedSports.isEmpty)
        } else if !onboardingData.selectedSports.isEmpty {
            // ✅ Reprendre la sélection depuis la persistance (ex: retour sur l'étape ou après redémarrage)
            selectedSports = onboardingData.selectedSports
            selectedSport = selectedSports.first
            onValidationChanged?(!selectedSports.isEmpty)
        } else {
            onValidationChanged?(false)
        }
    }

    /// ✨ Effectue une recherche dans tous les sports disponibles
    private func performSearch(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else {
            searchResults = []
            return
        }

        let queryLower = trimmedQuery.lowercased().folding(options: .diacriticInsensitive, locale: .current)

        // Rechercher dans TOUS les sports disponibles
        searchResults = allAvailableSports.filter { sport in
            let sportLower = sport.lowercased().folding(options: .diacriticInsensitive, locale: .current)

            // Extraire le nom du sport (sans l'emoji) pour une recherche plus précise
            var sportNameOnly = sport
            if let firstSpaceIndex = sport.firstIndex(of: " ") {
                sportNameOnly = String(sport[sport.index(after: firstSpaceIndex)...]).trimmingCharacters(in: .whitespaces)
            }
            let sportNameLower = sportNameOnly.lowercased().folding(options: .diacriticInsensitive, locale: .current)

            // Chercher dans le nom complet (avec emoji) ET dans le nom seul (sans emoji)
            // Recherche insensible aux accents et à la casse
            return sportLower.contains(queryLower) || sportNameLower.contains(queryLower)
        }

        // Trier par pertinence (ceux qui commencent par la query en premier)
        searchResults.sort { sport1, sport2 in
            let name1 = extractSportName(sport1).lowercased().folding(options: .diacriticInsensitive, locale: .current)
            let name2 = extractSportName(sport2).lowercased().folding(options: .diacriticInsensitive, locale: .current)

            let startsWith1 = name1.hasPrefix(queryLower)
            let startsWith2 = name2.hasPrefix(queryLower)

            if startsWith1 && !startsWith2 {
                return true
            } else if !startsWith1 && startsWith2 {
                return false
            }

            return name1 < name2
        }
    }

    /// Extrait le nom du sport sans l'emoji
    private func extractSportName(_ sport: String) -> String {
        if let firstSpaceIndex = sport.firstIndex(of: " ") {
            return String(sport[sport.index(after: firstSpaceIndex)...]).trimmingCharacters(in: .whitespaces)
        }
        return sport
    }
}

// Composant pour afficher un sport en ligne (style objectifs/expérience)
struct SportRowButton: View {
    let sport: String
    let isSelected: Bool
    let onTap: () -> Void

    private var sportEmoji: String {
        // Extrait l'emoji du sport (premiers caractères jusqu'au premier espace)
        if let spaceIndex = sport.firstIndex(of: " ") {
            return String(sport[..<spaceIndex])
        }
        return ""
    }

    private var sportName: String {
        // Extrait le nom du sport (après le premier espace)
        if let spaceIndex = sport.firstIndex(of: " ") {
            return String(sport[sport.index(after: spaceIndex)...]).trimmingCharacters(in: .whitespaces)
        }
        return sport
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(sportEmoji)
                    .font(.system(size: 20))

                Text(sportName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(OnboardingTheme.mutedText)
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .glassStyle()

        .opacity(isSelected ? 1.0 : 0.6)
    }
}

// Ancien composant SportCard (gardé pour compatibilité avec les résultats de recherche)
struct SportCard: View {
    let sport: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(sport)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
        }
        .glassStyle()

        .controlSize(.large)
        .opacity(isSelected ? 1.0 : 0.7)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
