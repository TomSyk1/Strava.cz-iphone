import SwiftUI

struct MenuView: View {
    @ObservedObject var vm: AppViewModel
    @State private var selectedDate: String?
    @State private var imageQuery: ImageQuery?

    private var visibleDays: [MenuDay] { MenuLogic.visibleDays(vm.days) }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if !visibleDays.isEmpty { dateChips(proxy) }

                ZStack(alignment: .top) {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            headerCard

                            if let error = vm.error {
                                ErrorCard(text: error) { Task { await vm.refreshMenu() } }
                            }
                            if vm.days.isEmpty && !vm.loading {
                                Text("Jídelníček je prázdný.")
                                    .font(.title2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            ForEach(visibleDays) { day in
                                DayCard(
                                    day: day,
                                    selection: vm.selected,
                                    onSelect: { key, id in vm.select(key, id) },
                                    onImages: { name in imageQuery = ImageQuery(name: name) }
                                )
                                .id(day.dateKey)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 16)
                    }
                    .refreshable { await vm.refreshMenu() }

                    if vm.loading { ProgressView().progressViewStyle(.linear) }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { if vm.dirty { saveBar } }
        .overlay(alignment: .bottom) { toast }
        .sheet(item: $imageQuery) { query in GoogleImagesSheet(query: query.name) }
        .task(id: vm.message) { await vm.dismissMessageAfterDelay() }
        .onAppear(perform: syncSelectedDate)
        .onChange(of: vm.days.map { $0.dateKey }) { _ in syncSelectedDate() }
    }

    // MARK: - Části obrazovky

    private func dateChips(_ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visibleDays) { day in
                    let isSelected = selectedDate == day.dateKey
                    Button {
                        selectedDate = day.dateKey
                        withAnimation { proxy.scrollTo(day.dateKey, anchor: .top) }
                    } label: {
                        Text(Czech.chipDate(day.date))
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(isSelected ? Theme.onPrimaryContainer : .primary)
                            .background(Capsule().fill(isSelected ? Theme.primaryContainer : Theme.field))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    private var headerCard: some View {
        let name = (vm.userName ?? "").trimmed
        return SurfaceCard(radius: 28, fill: Theme.primaryContainer) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name.isEmpty ? "Vítej!" : name).font(.headline)
                    Text("Jídelníček").font(.title.bold())
                    HStack(spacing: 8) {
                        Image(systemName: "banknote")
                        Text(vm.balance.map { "Zůstatek \(Czech.price($0)) Kč" } ?? "Zůstatek není dostupný")
                    }
                    .padding(.top, 4)
                }
                Spacer()
                Image(systemName: "calendar").font(.system(size: 40))
            }
            .foregroundStyle(Theme.onPrimaryContainer)
            .padding(20)
        }
    }

    private var saveBar: some View {
        HStack(spacing: 12) {
            Button { vm.discardChanges() } label: {
                Text("Zahodit")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.outline))
            }
            .buttonStyle(.plain)

            Button { Task { await vm.save() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Uložit změny").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(Theme.onPrimary)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.primary))
            }
            .buttonStyle(.plain)
            .layoutPriority(1)
        }
        .disabled(vm.loading)
        .padding(12)
        .background(.regularMaterial)
    }

    @ViewBuilder private var toast: some View {
        if let message = vm.message {
            Text(message)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.black.opacity(0.85)))
                .foregroundStyle(.white)
                .padding(.bottom, vm.dirty ? 90 : 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func syncSelectedDate() {
        let keys = visibleDays.map { $0.dateKey }
        if let current = selectedDate, keys.contains(current) { return }
        selectedDate = keys.first
    }
}
