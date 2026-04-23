import SwiftUI
import SwiftData

struct PoolSessionDetailView: View {
    @Bindable var session: PoolSession
    @State private var selectedStudentID: PersistentIdentifier?

    private var students: [Student] { session.students ?? [] }
    private var selectedStudent: Student? {
        students.first { $0.id == selectedStudentID } ?? students.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if students.count > 1 {
                    studentPicker
                }
                if let student = selectedStudent {
                    SkillAssessmentGrid(
                        student: student,
                        slotCode: session.slotCode,
                        courseType: session.courseType,
                        context: .pool(session)
                    )
                }
            }
            .padding()
        }
        .navigationTitle("\(session.slotCode) · \(session.formattedDate)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedStudentID == nil { selectedStudentID = students.first?.id }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "figure.pool.swim").foregroundStyle(Color.appAccent)
                Text(session.courseType).font(.headline)
                Text("·").foregroundStyle(.tertiary)
                Text(session.slotCode).font(.headline)
            }
            if !session.location.isEmpty {
                Text(session.location)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Text("\(session.durationMinutes) min · \(session.formattedTime)")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
    }

    private var studentPicker: some View {
        Picker("", selection: $selectedStudentID) {
            ForEach(students) { s in
                Text(s.fullName).tag(Optional(s.id))
            }
        }
        .pickerStyle(.segmented)
    }
}
