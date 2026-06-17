import SwiftData
import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \AppNotice.createdAt, order: .reverse) private var notices: [AppNotice]
    @State private var selectedNotice: AppNotice?

    private var unreadCount: Int {
        notices.filter { !$0.isRead }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if notices.isEmpty {
                    EmptyStateView(
                        icon: "bell.slash",
                        title: "No Notifications",
                        message: "Updates about tips, quiz rewards, and settled bets will appear here."
                    )
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(notices) { notice in
                                Button {
                                    notice.isRead = true
                                    selectedNotice = notice
                                } label: {
                                    AppCard {
                                        HStack(alignment: .top, spacing: 14) {
                                            Image(systemName: notice.kind.icon)
                                                .foregroundStyle(notice.isRead ? AppTheme.secondaryText : AppTheme.accent)
                                                .frame(width: 42, height: 42)
                                                .background(AppTheme.raised, in: Circle())
                                            VStack(alignment: .leading, spacing: 5) {
                                                HStack {
                                                    Text(notice.title)
                                                        .font(.headline)
                                                        .foregroundStyle(.white)
                                                    Spacer()
                                                    if !notice.isRead {
                                                        Circle()
                                                            .fill(AppTheme.accent)
                                                            .frame(width: 8, height: 8)
                                                    }
                                                }
                                                Text(notice.message)
                                                    .font(.subheadline)
                                                    .foregroundStyle(AppTheme.secondaryText)
                                                    .lineLimit(2)
                                                Text(notice.createdAt, style: .relative)
                                                    .font(.caption)
                                                    .foregroundStyle(AppTheme.secondaryText)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .appScreen()
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading) {
                        Text("\(unreadCount) unread")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(item: $selectedNotice) { notice in
                NotificationDetailView(notice: notice)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct NotificationDetailView: View {
    let notice: AppNotice

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: notice.kind.icon)
                .font(.system(size: 42))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 80, height: 80)
                .background(AppTheme.accent.opacity(0.2), in: Circle())

            Text(notice.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(notice.createdAt.formatted(date: .abbreviated, time: .shortened))
                .foregroundStyle(AppTheme.secondaryText)

            AppCard {
                Text(notice.message)
                    .font(.body)
                    .lineSpacing(5)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Notification")
        .navigationBarTitleDisplayMode(.inline)
        .appScreen()
    }
}
