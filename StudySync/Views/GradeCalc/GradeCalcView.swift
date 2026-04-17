import SwiftUI
import SwiftData

struct GradeCalcView: View {
    @Bindable var viewModel: GradeCalculatorViewModel
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<GradeCourse> { !$0.isArchived }, sort: \GradeCourse.createdAt, order: .reverse)
    private var activeCourses: [GradeCourse]

    @Query(filter: #Predicate<GradeCourse> { $0.isArchived }, sort: \GradeCourse.createdAt, order: .reverse)
    private var archivedCourses: [GradeCourse]

    @State private var showingArchived = false

    var body: some View {
        NavigationStack {
            ZStack {
                SSColor.backgroundPrimary.ignoresSafeArea()

                if activeCourses.isEmpty && archivedCourses.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: SSSpacing.xl) {
                            // Active courses
                            ForEach(activeCourses) { course in
                                NavigationLink {
                                    GradeCourseDetailView(course: course, viewModel: viewModel)
                                } label: {
                                    GradeCourseCard(course: course)
                                }
                                .buttonStyle(.plain)
                            }

                            // Add button
                            addCourseButton

                            // Archived section
                            if !archivedCourses.isEmpty {
                                archivedSection
                            }
                        }
                        .padding(.horizontal, SSSpacing.xl)
                        .padding(.top, SSSpacing.md)
                        .padding(.bottom, SSSpacing.xxxl)
                    }
                }
            }
            .navigationTitle(L10n.gradeCalcTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.tryAddCourse(activeCount: activeCourses.count)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddCourse) {
                AddGradeCourseView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingPaywall) {
                PaywallView()
            }
            .task {
                await GradeCourseSyncService.shared.pullAll(context: modelContext)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: SSSpacing.xl) {
            Image(systemName: "function")
                .font(SSFont.displayIcon)
                .foregroundStyle(.tertiary)
            Text(L10n.gradeEmptyTitle)
                .font(SSFont.heading2)
            Text(L10n.gradeEmptySubtitle)
                .font(SSFont.secondary)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                viewModel.tryAddCourse(activeCount: 0)
            } label: {
                Text(L10n.gradeAddCourse)
                    .font(SSFont.bodySemibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, SSSpacing.xxl)
                    .padding(.vertical, SSSpacing.lg)
                    .background(Capsule().fill(SSColor.brand))
            }
        }
        .padding(SSSpacing.xxxl)
    }

    // MARK: - Add Button

    private var addCourseButton: some View {
        Button {
            viewModel.tryAddCourse(activeCount: activeCourses.count)
        } label: {
            HStack(spacing: SSSpacing.md) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text(L10n.gradeAddCourse)
                    .font(SSFont.bodyMedium)
            }
            .foregroundStyle(SSColor.brand)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SSSpacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                    .strokeBorder(SSColor.brand.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
            )
        }
    }

    // MARK: - Archived Section

    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: SSSpacing.lg) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    showingArchived.toggle()
                }
            } label: {
                HStack(spacing: SSSpacing.sm) {
                    Text(L10n.gradeArchived)
                        .font(SSFont.sectionHeader)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showingArchived ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if showingArchived {
                ForEach(archivedCourses) { course in
                    HStack(spacing: SSSpacing.md) {
                        Text(course.emoji)
                            .font(.title3)
                        Text(course.name)
                            .font(SSFont.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            _ = viewModel.reactivateCourse(course, activeCount: activeCourses.count, context: modelContext)
                        } label: {
                            Text(L10n.gradeReactivate)
                                .font(SSFont.chipLabel)
                                .foregroundStyle(SSColor.brand)
                        }
                    }
                    .padding(SSSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                            .fill(SSColor.backgroundCard)
                    )
                }
            }
        }
    }
}

// MARK: - Course Card

struct GradeCourseCard: View {
    let course: GradeCourse
    @Environment(\.colorScheme) private var colorScheme

    private var courseColor: Color { Color(hex: course.colorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: SSSpacing.lg) {
            // Header
            HStack(spacing: SSSpacing.md) {
                Text(course.emoji)
                    .font(SSFont.emojiLarge)
                    .frame(width: SSSize.emojiCircle, height: SSSize.emojiCircle)
                    .background(courseColor.opacity(SSOpacity.tagBackground), in: RoundedRectangle(cornerRadius: SSRadius.small))

                VStack(alignment: .leading, spacing: 2) {
                    Text(course.name)
                        .font(SSFont.bodyMedium)
                        .lineLimit(1)
                    Text("\(L10n.gradeTarget) \(Int(course.targetGradePercent))%")
                        .font(SSFont.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Current weighted score (confirmed points)
                if course.enteredWeight > 0 {
                    Text(String(format: "%.1f%%", course.currentWeightedScore))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(courseColor)
                } else {
                    Text("--")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(courseColor.opacity(SSOpacity.tagBackground))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(courseColor)
                        .frame(width: max(0, geo.size.width * progress), height: 6)
                }
            }
            .frame(height: 6)

            // Bottom: needed score or status
            if let needed = course.neededScore {
                HStack(spacing: SSSpacing.sm) {
                    Image(systemName: needed <= 100 ? "target" : "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(needed <= 100 ? courseColor : .orange)
                    Text(L10n.gradeNeededPercent(Int(needed.rounded())))
                        .font(SSFont.caption)
                        .foregroundStyle(needed <= 100 ? Color.primary : Color.orange)
                    Spacer()
                    Text(L10n.gradeWeightSum(Int(course.totalWeight)))
                        .font(SSFont.caption)
                        .foregroundStyle(.tertiary)
                }
            } else if course.enteredWeight > 0 {
                HStack(spacing: SSSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text(L10n.gradeAlreadyPassed)
                        .font(SSFont.caption)
                        .foregroundStyle(.green)
                    Spacer()
                }
            }
        }
        .padding(SSSpacing.xl)
        .ssCard(color: courseColor)
    }

    private var progress: Double {
        guard course.targetGradePercent > 0 else { return 0 }
        return min(course.currentWeightedScore / course.targetGradePercent, 1.0)
    }
}
