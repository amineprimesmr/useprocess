//
//  UnifiedUserProfile.swift
//  Process
//
//  Created by Assistant on 25/01/2025.
//

import Foundation

// MARK: - Modèle Utilisateur Unifié et Optimisé
/// Modèle unique qui remplace ProfilData et UserProfile
/// Structure optimisée pour Firebase avec gestion intelligente des données
struct UnifiedUserProfile: Codable, Identifiable, Equatable {

    // MARK: - Identifiants
    let id: String
    let userId: String

    // MARK: - Informations personnelles
    var firstName: String
    var lastName: String?
    var username: String?
    var email: String?
    var phoneNumber: String?
    var birthPlace: String?
    var address: String?
    var accountObjective: String?
    var taxResidence: String?
    var professionalSituation: String?
    var otherServices: String?

    // MARK: - Dates importantes
    var downloadDate: Date // Date de téléchargement de l'app
    var birthDate: Date
    var createdAt: Date
    var lastUpdated: Date

    // MARK: - Données physiques
    var age: Int
    var gender: Gender
    var height: Double // en cm
    var weight: Double // en kg
    var idealWeight: Double? // en kg

    // MARK: - Images et médias
    var profilePictureURL: String?
    var backgroundImageURL: String?

    // MARK: - Sports et activités
    var sports: [Sport]
    var activityLevel: ActivityLevel

    // MARK: - Plan personnalisé (données onboarding)
    var mainGoal: MainGoal?  // ⚠️ LEGACY pour onboarding - Le plan utilise UserGoals
    var weightGoal: WeightGoal?  // ✨ NOUVEAU : Objectif de poids
    var goalDeadline: GoalDeadline?  // ✨ NOUVEAU : Deadline d'objectif
    var goalPace: GoalPace?  // ✨ NOUVEAU : Vitesse d'atteinte d'objectif (psychologique)
    var nutritionProfile: NutritionProfile?  // ✨ NOUVEAU : Profil nutrition complet
    var sleepProfile: SleepProfile?  // ✨ NOUVEAU : Profil sommeil complet
    var experienceLevel: ExperienceLevel?
    var yearsOfExperience: Int?
    var sessionsPerWeek: Int?
    var sessionDuration: Int?
    var trainingLocation: TrainingLocation?
    var availableEquipment: [PlanEquipment]?
    var onboardingPrimaryFocus: OnboardingPrimaryFocus?
    var onboardingDebloatDrivers: [OnboardingDebloatDriver]
    var onboardingRoutineChallenges: [OnboardingRoutineChallenge]

    // MARK: - Préférences utilisateur
    var preferences: UserPreferences

    // MARK: - Métadonnées système
    var version: String = "2.0"
    var isAnonymous: Bool = false
    var appleUserId: String?
    var hasCompletedOnboarding: Bool = false

    // MARK: - Abonnement Premium
    var isPremium: Bool = false
    var subscriptionExpiresAt: Date?
    var subscriptionStatus: String? // "subscribed", "expired", etc.

    // MARK: - Badges
    var isFounder: Bool = false // Badge "Fondateur" pour les 100 premiers utilisateurs

    // MARK: - Initializer Principal
    init(
        userId: String,
        firstName: String,
        lastName: String? = nil,
        username: String? = nil,
        email: String? = nil,
        downloadDate: Date? = nil, // ✅ CORRECTION : Optionnel pour utiliser la vraie date
        birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date(),
        gender: Gender = .male,
        height: Double = 0.0,
        weight: Double = 0.0,
        idealWeight: Double? = nil,
        profilePictureURL: String? = nil,
        backgroundImageURL: String? = nil,
        sports: [Sport] = [],
        activityLevel: ActivityLevel = .moderate,
        preferences: UserPreferences = UserPreferences(),
        isAnonymous: Bool = false,
        appleUserId: String? = nil,
        isPremium: Bool = false,
        subscriptionExpiresAt: Date? = nil,
        subscriptionStatus: String? = nil
    ) {
        self.id = "\(userId)_profile"
        self.userId = userId
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.email = email
        self.phoneNumber = nil
        self.birthPlace = nil
        self.address = nil
        self.accountObjective = nil
        self.taxResidence = "France"
        self.professionalSituation = nil
        self.otherServices = nil
        self.onboardingPrimaryFocus = nil
        self.onboardingDebloatDrivers = []
        self.onboardingRoutineChallenges = []
        // ✅ CORRECTION : Utiliser la vraie date de téléchargement ou la récupérer
        self.downloadDate = downloadDate ?? UnifiedUserProfile.getActualDownloadDate()
        self.birthDate = birthDate
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        self.gender = gender
        self.height = height
        self.weight = weight
        self.idealWeight = idealWeight
        self.profilePictureURL = profilePictureURL
        self.backgroundImageURL = backgroundImageURL
        self.sports = sports
        self.activityLevel = activityLevel
        self.preferences = preferences
        self.isAnonymous = isAnonymous
        self.appleUserId = appleUserId
        self.isPremium = isPremium
        self.subscriptionExpiresAt = subscriptionExpiresAt
        self.subscriptionStatus = subscriptionStatus
    }

    // MARK: - Computed Properties

    var fullName: String {
        if let lastName = lastName, !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        }
        return firstName
    }

    var displayUsername: String {
        if let username = username, !username.isEmpty {
            return "@\(username)"
        }
        return ""
    }

    var bmi: Double {
        let heightInMeters = height / 100.0
        return weight / (heightInMeters * heightInMeters)
    }

    var bmiCategory: BMICategory {
        switch bmi {
        case ..<18.5: return .underweight
        case 18.5..<25: return .normal
        case 25..<30: return .overweight
        default: return .obese
        }
    }

    var profileCompletionPercentage: Double {
        let totalFields = 10.0
        var completedFields = 0.0

        if !firstName.isEmpty { completedFields += 1 }
        if lastName != nil && !lastName!.isEmpty { completedFields += 1 }
        if age > 0 { completedFields += 1 }
        if height > 0 { completedFields += 1 }
        if weight > 0 { completedFields += 1 }
        if profilePictureURL != nil { completedFields += 1 }
        if backgroundImageURL != nil { completedFields += 1 }
        if !sports.isEmpty { completedFields += 1 }
        if idealWeight != nil { completedFields += 1 }

        return (completedFields / totalFields) * 100
    }

    var ageFormatted: String {
        return "\(age) ans"
    }

    var heightFormatted: String {
        return "\(Int(height)) cm"
    }

    var weightFormatted: String {
        return "\(String(format: "%.1f", weight)) kg"
    }

    var idealWeightFormatted: String {
        if let idealWeight = idealWeight {
            return "\(String(format: "%.1f", idealWeight)) kg"
        }
        return AppCopy.tSync("Non défini", en: "Not set")
    }

    var downloadDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: downloadDate)
    }

    // ✅ CORRECTION : Calculer le nombre de jours depuis le téléchargement
    var daysSinceDownload: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: downloadDate, to: Date())
        return max(0, components.day ?? 0)
    }

    // ✅ CORRECTION : Vérifier si on a assez de données pour les baselines
    var hasEnoughDataForBaselines: Bool {
        return daysSinceDownload >= 4
    }

    // ✅ CORRECTION : Statut de calibration basé sur les jours disponibles
    var calibrationStatus: String {
        switch daysSinceDownload {
        case 0..<4:
            return AppCopy.tSync(
                "Calibration en cours (\(daysSinceDownload)/4 jours)",
                en: "Calibration in progress (\(daysSinceDownload)/4 days)"
            )
        case 4..<14:
            return AppCopy.tSync(
                "Calibration partielle (\(daysSinceDownload)/14 jours)",
                en: "Partial calibration (\(daysSinceDownload)/14 days)"
            )
        default:
            return AppCopy.tSync(
                "Calibration complète (\(daysSinceDownload) jours)",
                en: "Calibration complete (\(daysSinceDownload) days)"
            )
        }
    }

    var birthDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: birthDate)
    }

    var sportsList: String {
        return sports.map { $0.name }.joined(separator: ", ")
    }

    // MARK: - Méthodes de Mise à Jour

    mutating func updateLastUpdated() {
        self.lastUpdated = Date()
    }

    mutating func updateProfilePicture(url: String?) {
        self.profilePictureURL = url
        updateLastUpdated()
    }

    mutating func updateBackgroundImage(url: String?) {
        self.backgroundImageURL = url
        updateLastUpdated()
    }

    mutating func addSport(_ sport: Sport) {
        if !sports.contains(where: { $0.id == sport.id }) {
            sports.append(sport)
            updateLastUpdated()
        }
    }

    mutating func removeSport(withId sportId: String) {
        sports.removeAll { $0.id == sportId }
        updateLastUpdated()
    }

    mutating func updatePhysicalData(height: Double? = nil, weight: Double? = nil, idealWeight: Double? = nil) {
        if let height = height { self.height = height }
        if let weight = weight { self.weight = weight }
        if let idealWeight = idealWeight { self.idealWeight = idealWeight }

        // Recalculer l'âge depuis la date de naissance
        self.age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0

        updateLastUpdated()
    }

    /// ✅ NOUVEAU: Mettre à jour l'âge et la date de naissance de manière cohérente
    mutating func updateAge(_ newAge: Int) {
        let validAge = min(120, max(0, newAge))
        self.age = validAge

        // Toujours mettre à jour la date de naissance pour correspondre à l'âge
        let calendar = Calendar.current
        if let birthDate = calendar.date(byAdding: .year, value: -validAge, to: Date()) {
            self.birthDate = birthDate
        }

        updateLastUpdated()
    }

    // MARK: - Custom Decoding pour compatibilité backward

    /// Décodage personnalisé pour gérer les champs manquants dans les anciens profils
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Décoder tous les champs requis
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        birthPlace = try container.decodeIfPresent(String.self, forKey: .birthPlace)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        accountObjective = try container.decodeIfPresent(String.self, forKey: .accountObjective)
        taxResidence = try container.decodeIfPresent(String.self, forKey: .taxResidence)
        professionalSituation = try container.decodeIfPresent(String.self, forKey: .professionalSituation)
        otherServices = try container.decodeIfPresent(String.self, forKey: .otherServices)
        downloadDate = try container.decode(Date.self, forKey: .downloadDate)
        birthDate = try container.decode(Date.self, forKey: .birthDate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        age = try container.decode(Int.self, forKey: .age)
        gender = try container.decode(Gender.self, forKey: .gender)
        height = try container.decode(Double.self, forKey: .height)
        weight = try container.decode(Double.self, forKey: .weight)
        idealWeight = try container.decodeIfPresent(Double.self, forKey: .idealWeight)
        profilePictureURL = try container.decodeIfPresent(String.self, forKey: .profilePictureURL)
        backgroundImageURL = try container.decodeIfPresent(String.self, forKey: .backgroundImageURL)
        sports = try container.decode([Sport].self, forKey: .sports)
        activityLevel = try container.decode(ActivityLevel.self, forKey: .activityLevel)
        mainGoal = try container.decodeIfPresent(MainGoal.self, forKey: .mainGoal)
        weightGoal = try container.decodeIfPresent(WeightGoal.self, forKey: .weightGoal)
        goalDeadline = try container.decodeIfPresent(GoalDeadline.self, forKey: .goalDeadline)
        goalPace = try container.decodeIfPresent(GoalPace.self, forKey: .goalPace)
        nutritionProfile = try container.decodeIfPresent(NutritionProfile.self, forKey: .nutritionProfile)
        sleepProfile = try container.decodeIfPresent(SleepProfile.self, forKey: .sleepProfile)
        experienceLevel = try container.decodeIfPresent(ExperienceLevel.self, forKey: .experienceLevel)
        yearsOfExperience = try container.decodeIfPresent(Int.self, forKey: .yearsOfExperience)
        sessionsPerWeek = try container.decodeIfPresent(Int.self, forKey: .sessionsPerWeek)
        sessionDuration = try container.decodeIfPresent(Int.self, forKey: .sessionDuration)
        trainingLocation = try container.decodeIfPresent(TrainingLocation.self, forKey: .trainingLocation)
        availableEquipment = try container.decodeIfPresent([PlanEquipment].self, forKey: .availableEquipment)
        onboardingPrimaryFocus = try container.decodeIfPresent(OnboardingPrimaryFocus.self, forKey: .onboardingPrimaryFocus)
        if let drivers = try container.decodeIfPresent([OnboardingDebloatDriver].self, forKey: .onboardingDebloatDrivers) {
            onboardingDebloatDrivers = drivers
        } else if let legacy = try container.decodeIfPresent(OnboardingDebloatDriver.self, forKey: .onboardingDebloatDriver) {
            onboardingDebloatDrivers = [legacy]
        } else {
            onboardingDebloatDrivers = []
        }
        onboardingRoutineChallenges = try container.decodeIfPresent(
            [OnboardingRoutineChallenge].self,
            forKey: .onboardingRoutineChallenges
        ) ?? []
        preferences = try container.decodeIfPresent(UserPreferences.self, forKey: .preferences) ?? UserPreferences()
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "2.0"
        isAnonymous = try container.decodeIfPresent(Bool.self, forKey: .isAnonymous) ?? false
        appleUserId = try container.decodeIfPresent(String.self, forKey: .appleUserId)
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
        subscriptionExpiresAt = try container.decodeIfPresent(Date.self, forKey: .subscriptionExpiresAt)
        subscriptionStatus = try container.decodeIfPresent(String.self, forKey: .subscriptionStatus)

        // ✅ CORRECTION : isFounder avec valeur par défaut pour compatibilité backward
        isFounder = try container.decodeIfPresent(Bool.self, forKey: .isFounder) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(firstName, forKey: .firstName)
        try container.encodeIfPresent(lastName, forKey: .lastName)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try container.encodeIfPresent(birthPlace, forKey: .birthPlace)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(accountObjective, forKey: .accountObjective)
        try container.encodeIfPresent(taxResidence, forKey: .taxResidence)
        try container.encodeIfPresent(professionalSituation, forKey: .professionalSituation)
        try container.encodeIfPresent(otherServices, forKey: .otherServices)
        try container.encode(downloadDate, forKey: .downloadDate)
        try container.encode(birthDate, forKey: .birthDate)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encode(age, forKey: .age)
        try container.encode(gender, forKey: .gender)
        try container.encode(height, forKey: .height)
        try container.encode(weight, forKey: .weight)
        try container.encodeIfPresent(idealWeight, forKey: .idealWeight)
        try container.encodeIfPresent(profilePictureURL, forKey: .profilePictureURL)
        try container.encodeIfPresent(backgroundImageURL, forKey: .backgroundImageURL)
        try container.encode(sports, forKey: .sports)
        try container.encode(activityLevel, forKey: .activityLevel)
        try container.encodeIfPresent(mainGoal, forKey: .mainGoal)
        try container.encodeIfPresent(weightGoal, forKey: .weightGoal)
        try container.encodeIfPresent(goalDeadline, forKey: .goalDeadline)
        try container.encodeIfPresent(goalPace, forKey: .goalPace)
        try container.encodeIfPresent(nutritionProfile, forKey: .nutritionProfile)
        try container.encodeIfPresent(sleepProfile, forKey: .sleepProfile)
        try container.encodeIfPresent(experienceLevel, forKey: .experienceLevel)
        try container.encodeIfPresent(yearsOfExperience, forKey: .yearsOfExperience)
        try container.encodeIfPresent(sessionsPerWeek, forKey: .sessionsPerWeek)
        try container.encodeIfPresent(sessionDuration, forKey: .sessionDuration)
        try container.encodeIfPresent(trainingLocation, forKey: .trainingLocation)
        try container.encodeIfPresent(availableEquipment, forKey: .availableEquipment)
        try container.encodeIfPresent(onboardingPrimaryFocus, forKey: .onboardingPrimaryFocus)
        try container.encode(onboardingDebloatDrivers, forKey: .onboardingDebloatDrivers)
        try container.encode(onboardingRoutineChallenges, forKey: .onboardingRoutineChallenges)
        try container.encode(preferences, forKey: .preferences)
        try container.encode(version, forKey: .version)
        try container.encode(isAnonymous, forKey: .isAnonymous)
        try container.encodeIfPresent(appleUserId, forKey: .appleUserId)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(isPremium, forKey: .isPremium)
        try container.encodeIfPresent(subscriptionExpiresAt, forKey: .subscriptionExpiresAt)
        try container.encodeIfPresent(subscriptionStatus, forKey: .subscriptionStatus)
        try container.encode(isFounder, forKey: .isFounder)
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case firstName
        case lastName
        case username
        case email
        case phoneNumber
        case birthPlace
        case address
        case accountObjective
        case taxResidence
        case professionalSituation
        case otherServices
        case downloadDate
        case birthDate
        case createdAt
        case lastUpdated
        case age
        case gender
        case height
        case weight
        case idealWeight
        case profilePictureURL
        case backgroundImageURL
        case sports
        case activityLevel
        case mainGoal
        case weightGoal
        case goalDeadline
        case goalPace
        case nutritionProfile
        case sleepProfile
        case experienceLevel
        case yearsOfExperience
        case sessionsPerWeek
        case sessionDuration
        case trainingLocation
        case availableEquipment
        case onboardingPrimaryFocus
        case onboardingDebloatDrivers
        case onboardingDebloatDriver
        case onboardingRoutineChallenges
        case preferences
        case version
        case isAnonymous
        case appleUserId
        case hasCompletedOnboarding
        case isPremium
        case subscriptionExpiresAt
        case subscriptionStatus
        case isFounder
    }
}

// MARK: - Enums et Structures de Support

enum Gender: String, CaseIterable, Codable {
    case male = "male"
    case female = "female"
    case other = "other"
    case preferNotToSay = "prefer_not_to_say"

    @MainActor
    var displayName: String {
        switch self {
        case .male: return AppCopy.t("Homme", en: "Male")
        case .female: return AppCopy.t("Femme", en: "Female")
        case .other: return AppCopy.t("Autre", en: "Other")
        case .preferNotToSay: return AppCopy.t("Préfère ne pas dire", en: "Prefer not to say")
        }
    }
}

enum BMICategory: String, CaseIterable, Codable {
    case underweight = "underweight"
    case normal = "normal"
    case overweight = "overweight"
    case obese = "obese"

    @MainActor
    var displayName: String {
        switch self {
        case .underweight: return AppCopy.t("Sous-poids", en: "Underweight")
        case .normal: return AppCopy.t("Poids normal", en: "Normal weight")
        case .overweight: return AppCopy.t("Surpoids", en: "Overweight")
        case .obese: return AppCopy.t("Obésité", en: "Obesity")
        }
    }

    var color: String {
        switch self {
        case .underweight: return "blue"
        case .normal: return "green"
        case .overweight: return "orange"
        case .obese: return "red"
        }
    }
}

struct Sport: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let category: SportCategory
    let frequency: SportFrequency
    let intensity: SportIntensity
    let addedDate: Date

    init(name: String, category: SportCategory, frequency: SportFrequency, intensity: SportIntensity) {
        self.id = UUID().uuidString
        self.name = name
        self.category = category
        self.frequency = frequency
        self.intensity = intensity
        self.addedDate = Date()
    }

    // ✅ CRITIQUE: Décodage personnalisé pour gérer les champs manquants depuis Firebase
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Générer un ID si manquant (pour compatibilité avec anciennes données)
        if let existingId = try? container.decode(String.self, forKey: .id) {
            self.id = existingId
        } else {
            self.id = UUID().uuidString
        }

        // Décoder le nom (requis)
        self.name = try container.decode(String.self, forKey: .name)

        // Décoder la catégorie avec valeur par défaut
        if let categoryString = try? container.decode(String.self, forKey: .category),
           let decodedCategory = SportCategory(rawValue: categoryString) {
            self.category = decodedCategory
        } else {
            self.category = .other // Valeur par défaut
        }

        // Décoder la fréquence avec valeur par défaut
        if let frequencyString = try? container.decode(String.self, forKey: .frequency),
           let decodedFrequency = SportFrequency(rawValue: frequencyString) {
            self.frequency = decodedFrequency
        } else {
            self.frequency = .weekly // Valeur par défaut
        }

        // Décoder l'intensité avec valeur par défaut
        if let intensityString = try? container.decode(String.self, forKey: .intensity),
           let decodedIntensity = SportIntensity(rawValue: intensityString) {
            self.intensity = decodedIntensity
        } else {
            self.intensity = .moderate // Valeur par défaut
        }

        // Décoder la date d'ajout avec valeur par défaut
        if let decodedDate = try? container.decode(Date.self, forKey: .addedDate) {
            self.addedDate = decodedDate
        } else {
            self.addedDate = Date() // Valeur par défaut
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case frequency
        case intensity
        case addedDate
    }
}

enum SportCategory: String, CaseIterable, Codable {
    case cardio = "cardio"
    case strength = "strength"
    case flexibility = "flexibility"
    case team = "team"
    case individual = "individual"
    case water = "water"
    case combat = "combat"
    case other = "other"

    @MainActor
    var displayName: String {
        switch self {
        case .cardio: return AppCopy.t("Cardio", en: "Cardio")
        case .strength: return AppCopy.t("Musculation", en: "Strength")
        case .flexibility: return AppCopy.t("Flexibilité", en: "Flexibility")
        case .team: return AppCopy.t("Sport d'équipe", en: "Team sport")
        case .individual: return AppCopy.t("Sport individuel", en: "Individual sport")
        case .water: return AppCopy.t("Sport aquatique", en: "Water sport")
        case .combat: return AppCopy.t("Sport de combat", en: "Combat sport")
        case .other: return AppCopy.t("Autre", en: "Other")
        }
    }
}

enum SportFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    case occasional = "occasional"

    @MainActor
    var displayName: String {
        switch self {
        case .daily: return AppCopy.t("Quotidien", en: "Daily")
        case .weekly: return AppCopy.t("Hebdomadaire", en: "Weekly")
        case .biweekly: return AppCopy.t("Bi-hebdomadaire", en: "Biweekly")
        case .monthly: return AppCopy.t("Mensuel", en: "Monthly")
        case .occasional: return AppCopy.t("Occasionnel", en: "Occasional")
        }
    }
}

enum SportIntensity: String, CaseIterable, Codable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case veryHigh = "very_high"

    @MainActor
    var displayName: String {
        switch self {
        case .low: return AppCopy.t("Faible", en: "Low")
        case .moderate: return AppCopy.t("Modérée", en: "Moderate")
        case .high: return AppCopy.t("Élevée", en: "High")
        case .veryHigh: return AppCopy.t("Très élevée", en: "Very high")
        }
    }
}

// MARK: - Chronotype pour le système d'énergie
enum ChronotypeEnergy: String, Codable, CaseIterable, Equatable {
    case morning = "morning"    // Lève-tôt (larks)
    case neutral = "neutral"    // Neutre
    case evening = "evening"    // Couche-tard (owls)

    @MainActor
    var displayName: String {
        switch self {
        case .morning: return AppCopy.t("Personne du matin", en: "Morning person")
        case .neutral: return AppCopy.t("Rythme neutre", en: "Neutral rhythm")
        case .evening: return AppCopy.t("Personne du soir", en: "Evening person")
        }
    }

    var description: String {
        return displayName
    }

    var emoji: String {
        switch self {
        case .morning: return "🌅"
        case .neutral: return "☀️"
        case .evening: return "🌙"
        }
    }

    var offset: Double {
        // Offset en heures pour le pic circadien
        switch self {
        case .morning: return -2.0  // Pic plus tôt
        case .neutral: return 0.0   // Pic standard
        case .evening: return 2.0   // Pic plus tard
        }
    }
}

struct UserPreferences: Codable, Equatable {
    var notificationsEnabled: Bool = true
    var smsNotificationsEnabled: Bool = true
    var emailNotificationsEnabled: Bool = true
    var pushNotificationsEnabled: Bool = true
    var dataSharingEnabled: Bool = false
    var analyticsEnabled: Bool = true
    var darkModeEnabled: Bool = false
    var language: String = ProcessAppLanguage.resolveFromDevice().rawValue
    var timezone: String = "Europe/Paris"
    var units: MeasurementUnits = .metric

    // ✅ NOUVEAU: Préférences pour le système d'énergie
    var chronotype: ChronotypeEnergy = .neutral  // Type circadien simplifié (3 options)
    var autoDetectChronotype: Bool = true        // Détection auto du chronotype
    var napNotificationsEnabled: Bool = true     // Notifications pour siestes recommandées
    var energyDipAlerts: Bool = true             // Alertes avant creux d'énergie
}

enum MeasurementUnits: String, CaseIterable, Codable {
    case metric = "metric"
    case imperial = "imperial"

    @MainActor
    var displayName: String {
        switch self {
        case .metric: return OnboardingCopy.t("Métrique", en: "Metric")
        case .imperial: return OnboardingCopy.t("Impérial", en: "Imperial")
        }
    }
}

// MARK: - Extensions pour la Compatibilité

extension UnifiedUserProfile {
    /// Convertir depuis l'ancien ProfilData
    static func fromProfilData(_ profilData: UnifiedUserProfile) -> UnifiedUserProfile {
        return UnifiedUserProfile(
            userId: profilData.userId,
            firstName: profilData.firstName,
            username: profilData.username?.isEmpty == false ? profilData.username : nil,
            downloadDate: profilData.downloadDate,
            birthDate: profilData.birthDate,
            gender: profilData.gender,
            height: profilData.height,
            weight: profilData.weight,
            idealWeight: profilData.idealWeight == 0.0 ? nil : profilData.idealWeight,
            profilePictureURL: profilData.profilePictureURL,
            backgroundImageURL: profilData.backgroundImageURL,
            sports: profilData.sports
        )
    }

    /// Convertir depuis l'ancien UserProfile
    static func fromUserProfile(_ userProfile: UnifiedUserProfile) -> UnifiedUserProfile {
        return UnifiedUserProfile(
            userId: userProfile.userId,
            firstName: userProfile.firstName,
            username: userProfile.username,
            downloadDate: userProfile.downloadDate,
            birthDate: userProfile.birthDate,
            gender: userProfile.gender,
            height: userProfile.height,
            weight: userProfile.weight,
            idealWeight: userProfile.idealWeight,
            profilePictureURL: userProfile.profilePictureURL,
            backgroundImageURL: userProfile.backgroundImageURL,
            sports: userProfile.sports
        )
    }

}

// MARK: - Static Methods pour la Date de Téléchargement

extension UnifiedUserProfile {

    /// ✅ CORRECTION : Récupère la vraie date de téléchargement depuis UserDefaults
    static func getActualDownloadDate() -> Date {
        let key = "actualDownloadDate"

        // Vérifier si on a déjà une date stockée
        if let storedDate = UserDefaults.standard.object(forKey: key) as? Date {
            return storedDate
        }

        // Si pas de date stockée, c'est la première fois → sauvegarder la date actuelle
        let currentDate = Date()
        UserDefaults.standard.set(currentDate, forKey: key)

        return currentDate
    }

    /// ✅ CORRECTION : Met à jour la date de téléchargement (pour les migrations)
    static func updateDownloadDate(_ newDate: Date) {
        UserDefaults.standard.set(newDate, forKey: "actualDownloadDate")
    }

    /// ✅ CORRECTION : Réinitialise la date de téléchargement (pour les tests)
    static func resetDownloadDate() {
        UserDefaults.standard.removeObject(forKey: "actualDownloadDate")
    }
}
