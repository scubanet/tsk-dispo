import SwiftUI

struct ExtraSkillPickerSheet: View {
    let courseType: String
    let currentSlotCode: String
    let alreadyAdded: Set<String>
    let onPick: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCourse: String
    @State private var searchText = ""
    @State private var selected: Set<String> = []

    init(courseType: String, currentSlotCode: String, alreadyAdded: Set<String>, onPick: @escaping ([String]) -> Void) {
        self.courseType = courseType
        self.currentSlotCode = currentSlotCode
        self.alreadyAdded = alreadyAdded
        self.onPick = onPick
        self._selectedCourse = State(initialValue: courseType)
    }

    private var courses: [String] {
        PADIStandards.shared.availableCourses
    }

    private var slots: [PADISlot] {
        PADIStandards.shared.slots(for: selectedCourse)
            .filter { $0.code != currentSlotCode || selectedCourse != courseType }
            .filter { $0.code != "FLEX" }
    }

    private var filteredSlots: [(slot: PADISlot, skills: [PADISkill])] {
        slots.compactMap { slot in
            let skills = slot.skills.filter(\.isActive).filter { skill in
                !alreadyAdded.contains(skill.code) && matchesSearch(skill)
            }
            return skills.isEmpty ? nil : (slot, skills)
        }
    }

    private func matchesSearch(_ skill: PADISkill) -> Bool {
        guard !searchText.isEmpty else { return true }
        let q = searchText.lowercased()
        return skill.title.lowercased().contains(q) || skill.code.lowercased().contains(q)
    }

    @ViewBuilder
    private func skillRow(_ skill: PADISkill) -> some View {
        let isSelected = selected.contains(skill.code)
        Button {
            if isSelected {
                selected.remove(skill.code)
            } else {
                selected.insert(skill.code)
            }
        } label: {
            skillRowLabel(skill, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func skillRowLabel(_ skill: PADISkill, isSelected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.code)
                    .font(.system(size: 10, weight: .bold).monospaced())
                    .foregroundStyle(.tertiary)
                Text(skill.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.appAccent : Color.secondary)
                .font(.system(size: 20))
        }
    }

    @ViewBuilder
    private func slotHeader(_ slot: PADISlot, skills: [PADISkill]) -> some View {
        let slotCodes = Set(skills.map(\.code))
        let allSelected = slotCodes.isSubset(of: selected)
        HStack {
            Text("\(selectedCourse) — \(slot.title)")
            Spacer()
            Button {
                if allSelected {
                    selected.subtract(slotCodes)
                } else {
                    selected.formUnion(slotCodes)
                }
            } label: {
                let label: String = allSelected
                    ? (L10n.currentLanguage == "de" ? "Alle abwählen" : "Deselect all")
                    : (L10n.currentLanguage == "de" ? "Alle auswählen" : "Select all")
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.appAccent)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HeroBackground()

                VStack(spacing: 0) {
                    List {
                        if courses.count > 1 {
                            Section {
                                Picker(L10n.currentLanguage == "de" ? "Kurs" : "Course", selection: $selectedCourse) {
                                    ForEach(courses, id: \.self) { c in
                                        Text(c).tag(c)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .listRowBackground(Color.surfaceCard)
                        }

                        ForEach(filteredSlots, id: \.slot.code) { item in
                            Section {
                                ForEach(item.skills, id: \.code) { skill in
                                    skillRow(skill)
                                }
                            } header: {
                                slotHeader(item.slot, skills: item.skills)
                            }
                            .listRowBackground(Color.surfaceCard)
                        }

                        if filteredSlots.isEmpty {
                            Section {
                                VStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.quaternary)
                                    Text(L10n.currentLanguage == "de" ? "Keine passenden Skills gefunden" : "No matching skills found")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .searchable(text: $searchText, prompt: L10n.currentLanguage == "de" ? "Skill suchen…" : "Search skills…")
                    .scrollContentBackground(.hidden)

                    if !selected.isEmpty {
                        Button {
                            onPick(Array(selected))
                            dismiss()
                        } label: {
                            Text(L10n.currentLanguage == "de"
                                 ? "\(selected.count) Skill\(selected.count == 1 ? "" : "s") übernehmen"
                                 : "Add \(selected.count) skill\(selected.count == 1 ? "" : "s")")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.appAccent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: DSRadius.m))
                        }
                        .padding(.horizontal, DSSpacing.l)
                        .padding(.vertical, DSSpacing.s)
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .navigationTitle(L10n.currentLanguage == "de" ? "Skills hinzufügen" : "Add Skills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.currentLanguage == "de" ? "Fertig" : "Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
