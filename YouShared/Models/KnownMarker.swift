//
//  KnownMarker.swift
//  You
//

import Foundation

/// A blood test marker the app already understands: the name labs print, its usual
/// unit on Australian reports, the other spellings labs use, and what it means in
/// everyday words.
///
/// Business rules:
/// - The catalogue covers the standard GP blood panel. Anything else is entered by
///   hand as "Other", the app never pretends to know a marker it doesn't.
/// - Explanations teach what a marker measures. They never say what a value means
///   for this patient, that is the GP's job.
/// - One marker, one place. The Add a result picker, the camera reader and the
///   plain-language explanations all read from this list.
struct KnownMarker: Identifiable, Hashable {
    /// How reports group markers, used as the section headings in the picker.
    enum Group: String, CaseIterable {
        case bloodCount = "Blood count"
        case iron = "Iron"
        case sugar = "Sugar"
        case fats = "Fats"
        case kidney = "Kidney"
        case liver = "Liver"
        case thyroid = "Thyroid"
        case vitamins = "Vitamins and minerals"
    }

    /// The name as a lab prints it, e.g. "Ferritin".
    let name: String

    /// The unit labs normally use for this marker in Australia.
    let unit: String

    /// Other ways labs print the same marker, e.g. "Hb" for haemoglobin.
    let aliases: [String]

    let group: Group

    /// What this marker measures, in the patient's words.
    let plainLanguageExplanation: String

    var id: String { name }

    // MARK: - Looking a marker up

    /// The marker whose name or alias is exactly this text, ignoring case.
    static func matching(_ text: String) -> KnownMarker? {
        let wanted = text.trimmingCharacters(in: .whitespaces).lowercased()
        return all.first { marker in
            ([marker.name] + marker.aliases).contains { $0.lowercased() == wanted }
        }
    }

    /// The explanation for a typed marker name, with an honest fallback for one
    /// the app doesn't know.
    static func explanation(for markerName: String) -> String {
        matching(markerName)?.plainLanguageExplanation
            ?? "Your GP can explain what this marker measures and what your value means for you."
    }

    // MARK: - Finding a marker on a line of a report

    /// Where this marker's name or an alias is printed on a line, as whole words so
    /// "Hb" never matches inside "HbA1c". The longest match wins. Nil if absent.
    func printedRange(in line: String) -> Range<String.Index>? {
        ([name] + aliases)
            .compactMap { line.range(of: Self.wholeWordPattern($0), options: [.regularExpression, .caseInsensitive]) }
            .max { line.distance(from: $0.lowerBound, to: $0.upperBound) < line.distance(from: $1.lowerBound, to: $1.upperBound) }
    }

    /// The marker a line is about: the one with the longest printed match, so
    /// "LDL cholesterol" is read as LDL, not as total cholesterol. Nil if none.
    static func printed(on line: String) -> KnownMarker? {
        all.compactMap { marker -> (KnownMarker, Int)? in
            guard let range = marker.printedRange(in: line) else { return nil }
            return (marker, line.distance(from: range.lowerBound, to: range.upperBound))
        }
        .max { $0.1 < $1.1 }?.0
    }

    private static func wholeWordPattern(_ text: String) -> String {
        "(?<![A-Za-z])" + NSRegularExpression.escapedPattern(for: text) + "(?![A-Za-z])"
    }

    // MARK: - The catalogue

    static let all: [KnownMarker] = [
        // Blood count
        KnownMarker(
            name: "Haemoglobin", unit: "g/L", aliases: ["Hb"], group: .bloodCount,
            plainLanguageExplanation: "Haemoglobin is the part of your red blood cells that carries oxygen around your body."
        ),
        KnownMarker(
            name: "White cell count", unit: "x10⁹/L", aliases: ["WCC", "White cells", "WBC", "Leukocytes"], group: .bloodCount,
            plainLanguageExplanation: "White cells are your body's defence against infection. The count rises when you're fighting something off and can dip with some viruses or medicines."
        ),
        KnownMarker(
            name: "Platelets", unit: "x10⁹/L", aliases: ["Platelet count", "PLT"], group: .bloodCount,
            plainLanguageExplanation: "Platelets help your blood clot when you're cut. Too few can mean easy bruising, too many is something your GP will want to look into."
        ),

        // Iron
        KnownMarker(
            name: "Ferritin", unit: "µg/L", aliases: [], group: .iron,
            plainLanguageExplanation: "Ferritin shows how much iron your body has stored. Low iron stores are a common reason for feeling tired or short of breath."
        ),
        KnownMarker(
            name: "Iron", unit: "µmol/L", aliases: ["Serum iron"], group: .iron,
            plainLanguageExplanation: "Iron is the amount circulating in your blood right now. It changes with meals and time of day, so ferritin is usually the better guide to your stores."
        ),
        KnownMarker(
            name: "Transferrin saturation", unit: "%", aliases: ["Tsat", "Transferrin sat", "Iron saturation"], group: .iron,
            plainLanguageExplanation: "Transferrin saturation shows how much of your iron-carrying protein is actually loaded with iron. Low numbers go with low iron, high numbers with iron overload."
        ),

        // Sugar
        KnownMarker(
            name: "HbA1c", unit: "%", aliases: ["Glycated haemoglobin", "A1c"], group: .sugar,
            plainLanguageExplanation: "HbA1c shows your average blood sugar over the past two to three months. It is the main number used to diagnose and keep track of diabetes."
        ),
        KnownMarker(
            name: "Fasting glucose", unit: "mmol/L", aliases: ["Glucose", "Glucose fasting", "Blood glucose"], group: .sugar,
            plainLanguageExplanation: "Fasting glucose is the sugar in your blood after not eating overnight. It is one of the checks used to look for diabetes."
        ),

        // Fats
        KnownMarker(
            name: "Total cholesterol", unit: "mmol/L", aliases: ["Cholesterol"], group: .fats,
            plainLanguageExplanation: "Total cholesterol adds up all the cholesterol in your blood. On its own it says less than the LDL and HDL parts beneath it."
        ),
        KnownMarker(
            name: "LDL cholesterol", unit: "mmol/L", aliases: ["LDL", "LDL-C"], group: .fats,
            plainLanguageExplanation: "LDL is often called the bad cholesterol because it can build up in artery walls. Lower is generally better for your heart."
        ),
        KnownMarker(
            name: "HDL cholesterol", unit: "mmol/L", aliases: ["HDL", "HDL-C"], group: .fats,
            plainLanguageExplanation: "HDL is often called the good cholesterol because it carries cholesterol away from your arteries. Higher is generally better."
        ),
        KnownMarker(
            name: "Triglycerides", unit: "mmol/L", aliases: ["Trig", "TG"], group: .fats,
            plainLanguageExplanation: "Triglycerides are fats your body stores from the food you eat. They rise after meals and with sugary food or alcohol, which is why this test is usually done fasting."
        ),

        // Kidney
        KnownMarker(
            name: "Creatinine", unit: "µmol/L", aliases: [], group: .kidney,
            plainLanguageExplanation: "Creatinine is a waste product your muscles make and your kidneys clear. A rising level can mean the kidneys are filtering less well."
        ),
        KnownMarker(
            name: "eGFR", unit: "mL/min/1.73m²", aliases: ["Estimated GFR", "GFR"], group: .kidney,
            plainLanguageExplanation: "eGFR estimates how well your kidneys are filtering, a bit like a percentage of normal. Above 90 is usual for healthy kidneys and it drifts down a little with age."
        ),
        KnownMarker(
            name: "Urea", unit: "mmol/L", aliases: [], group: .kidney,
            plainLanguageExplanation: "Urea is another waste product the kidneys remove. It can rise when you're dehydrated as well as when the kidneys are under strain."
        ),
        KnownMarker(
            name: "Urine albumin to creatinine ratio", unit: "mg/mmol", aliases: ["ACR", "uACR", "Urine ACR", "Albumin/creatinine ratio"], group: .kidney,
            plainLanguageExplanation: "This urine test looks for small amounts of protein leaking from the kidneys, an early sign of kidney strain that is checked every year in diabetes."
        ),

        // Liver
        KnownMarker(
            name: "ALT", unit: "U/L", aliases: ["Alanine aminotransferase"], group: .liver,
            plainLanguageExplanation: "ALT is an enzyme that leaks from liver cells when they are irritated. It is the most common sign of a liver under stress from fat, alcohol or medicines."
        ),
        KnownMarker(
            name: "AST", unit: "U/L", aliases: ["Aspartate aminotransferase"], group: .liver,
            plainLanguageExplanation: "AST is a liver enzyme like ALT, but it also comes from muscle, so your GP reads the two together."
        ),
        KnownMarker(
            name: "GGT", unit: "U/L", aliases: ["Gamma GT", "Gamma-glutamyl transferase"], group: .liver,
            plainLanguageExplanation: "GGT is a liver enzyme that is sensitive to alcohol and to bile flow. It often rises before the others do."
        ),
        KnownMarker(
            name: "ALP", unit: "U/L", aliases: ["Alkaline phosphatase"], group: .liver,
            plainLanguageExplanation: "ALP comes from the liver and from bone. It can rise with bile duct problems or with bone growth and healing."
        ),
        KnownMarker(
            name: "Bilirubin", unit: "µmol/L", aliases: ["Total bilirubin"], group: .liver,
            plainLanguageExplanation: "Bilirubin is the yellow pigment left over when old red blood cells are broken down. High levels cause jaundice, but a mildly raised level is often harmless."
        ),

        // Thyroid
        KnownMarker(
            name: "TSH", unit: "mIU/L", aliases: ["Thyroid stimulating hormone"], group: .thyroid,
            plainLanguageExplanation: "TSH tells your thyroid how hard to work. It is a common check when energy levels feel off."
        ),

        // Vitamins and minerals
        KnownMarker(
            name: "Vitamin D", unit: "nmol/L", aliases: ["25-OH vitamin D", "25-hydroxyvitamin D", "Vitamin D (25-OH)"], group: .vitamins,
            plainLanguageExplanation: "Vitamin D helps your body absorb calcium and keep bones and muscles strong. Most of it comes from sunlight."
        ),
        KnownMarker(
            name: "Vitamin B12", unit: "pmol/L", aliases: ["B12", "Cobalamin"], group: .vitamins,
            plainLanguageExplanation: "Vitamin B12 keeps your nerves and red blood cells healthy. Low levels can cause tiredness, pins and needles and low mood, and are more common on plant-based diets."
        ),
        KnownMarker(
            name: "Folate", unit: "nmol/L", aliases: ["Serum folate", "Folic acid"], group: .vitamins,
            plainLanguageExplanation: "Folate is a B vitamin your body uses to make new cells, including red blood cells. Leafy greens and fortified bread are the main sources."
        )
    ]
}
