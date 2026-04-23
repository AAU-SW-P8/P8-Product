import SwiftUI

struct PersonPickerSheetView: View {
    let people: [Person]
    let onSelectPerson: (Person) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Who is this scan for?")
                    .font(.headline)
                    .padding(.top, 6)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(people) { person in
                            Button {
                                onSelectPerson(person)
                            } label: {
                                HStack {
                                    Text(person.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("Select")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.blue)
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.black.opacity(0.28))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 260)

                HStack(spacing: 12) {
                    Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
                    Text("or")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
                }

                Button("Cancel") {
                    onCancel()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
        }
    }
}
