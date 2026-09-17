import AppKit

private let calendar = Calendar.autoupdatingCurrent

private struct CalendarDay {
    let day: Int
    let isInDisplayedMonth: Bool
    let isToday: Bool
}

private func startOfMonth(_ date: Date) -> Date {
    calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
}

private func monthDays(for displayedMonth: Date, today: Date = Date()) -> [CalendarDay] {
    let monthStart = startOfMonth(displayedMonth)
    let weekday = calendar.component(.weekday, from: monthStart)
    let leadingCount = (weekday - calendar.firstWeekday + 7) % 7
    let gridStart = calendar.date(byAdding: .day, value: -leadingCount, to: monthStart)!

    return (0..<42).map { offset in
        let date = calendar.date(byAdding: .day, value: offset, to: gridStart)!
        return CalendarDay(
            day: calendar.component(.day, from: date),
            isInDisplayedMonth: calendar.isDate(date, equalTo: monthStart, toGranularity: .month),
            isToday: calendar.isDate(date, inSameDayAs: today)
        )
    }
}

private final class InactivityApplication: NSApplication {
    private var inactivityTimer: Timer?
    private let inactivityInterval: TimeInterval = 30

    func restartInactivityTimer() {
        inactivityTimer?.invalidate()
        let timer = Timer(timeInterval: inactivityInterval, repeats: false) { _ in
            NSApp.terminate(nil)
        }
        inactivityTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
             .otherMouseDown, .otherMouseUp, .mouseMoved, .leftMouseDragged,
             .rightMouseDragged, .otherMouseDragged, .scrollWheel, .keyDown,
             .keyUp, .flagsChanged:
            restartInactivityTimer()
        default:
            break
        }
        super.sendEvent(event)
    }
}

private final class CalendarDayView: NSView {
    private let label = NSTextField(labelWithString: "")
    private let selectionCircle = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        selectionCircle.wantsLayer = true
        selectionCircle.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        selectionCircle.isHidden = true
        addSubview(selectionCircle)

        label.alignment = .center
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        let diameter = min(bounds.width, bounds.height, 38)
        selectionCircle.frame = NSRect(
            x: (bounds.width - diameter) / 2,
            y: (bounds.height - diameter) / 2,
            width: diameter,
            height: diameter
        )
        selectionCircle.layer?.cornerRadius = diameter / 2
    }

    func configure(with day: CalendarDay) {
        label.stringValue = String(day.day)
        selectionCircle.isHidden = !day.isToday
        if day.isToday {
            label.textColor = .white
            label.font = .systemFont(ofSize: 15, weight: .semibold)
        } else {
            label.textColor = day.isInDisplayedMonth ? .labelColor : .tertiaryLabelColor
            label.font = .systemFont(ofSize: 15, weight: .medium)
        }
    }
}

private final class CalendarViewController: NSViewController {
    private var displayedMonth = startOfMonth(Date())
    private let monthLabel = NSTextField(labelWithString: "")
    private let yearButton = NSButton(title: "", target: nil, action: nil)
    private let weekdaysRow = NSStackView()
    private let calendarGrid = NSGridView()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter
    }()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 550))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        buildInterface()
        updateCalendar()
    }

    private func buildInterface() {
        let title = NSTextField(labelWithString: "Quick Calendar")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .secondaryLabelColor

        let previousButton = navigationButton(symbol: "chevron.left", action: #selector(previousMonth))
        previousButton.toolTip = "Previous month"
        let nextButton = navigationButton(symbol: "chevron.right", action: #selector(nextMonth))
        nextButton.toolTip = "Next month"

        monthLabel.font = .systemFont(ofSize: 30, weight: .bold)
        monthLabel.setContentHuggingPriority(.required, for: .horizontal)

        yearButton.target = self
        yearButton.action = #selector(showYearMenu(_:))
        yearButton.isBordered = false
        yearButton.font = .systemFont(ofSize: 30, weight: .regular)
        yearButton.contentTintColor = .secondaryLabelColor
        yearButton.toolTip = "Choose a year"
        yearButton.setButtonType(.momentaryChange)

        let monthYearRow = NSStackView(views: [monthLabel, yearButton])
        monthYearRow.orientation = .horizontal
        monthYearRow.alignment = .centerY
        monthYearRow.spacing = 8

        let headerSpacer = NSView()
        let header = NSStackView(views: [previousButton, headerSpacer, monthYearRow, NSView(), nextButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12
        header.translatesAutoresizingMaskIntoConstraints = false

        let flexibleViews = [headerSpacer, header.views[3]]
        flexibleViews.forEach { $0.setContentHuggingPriority(.defaultLow, for: .horizontal) }

        configureWeekdays()
        configureCalendarGrid()

        let divider = NSBox()
        divider.boxType = .separator

        let content = NSStackView(views: [title, header, divider, weekdaysRow, calendarGrid])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 16
        content.setCustomSpacing(22, after: title)
        content.setCustomSpacing(12, after: divider)
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            content.topAnchor.constraint(equalTo: view.topAnchor, constant: 28),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -30),
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            divider.widthAnchor.constraint(equalTo: content.widthAnchor),
            weekdaysRow.widthAnchor.constraint(equalTo: content.widthAnchor),
            calendarGrid.widthAnchor.constraint(equalTo: content.widthAnchor),
            calendarGrid.heightAnchor.constraint(greaterThanOrEqualToConstant: 330)
        ])
    }

    private func navigationButton(symbol: String, action: Selector) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil)!, target: self, action: action)
        button.bezelStyle = .circular
        button.controlSize = .large
        button.imagePosition = .imageOnly
        button.widthAnchor.constraint(equalToConstant: 42).isActive = true
        button.heightAnchor.constraint(equalToConstant: 42).isActive = true
        return button
    }

    private func configureWeekdays() {
        weekdaysRow.orientation = .horizontal
        weekdaysRow.distribution = .fillEqually
        weekdaysRow.alignment = .centerY
        weekdaysRow.spacing = 0

        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let startIndex = max(0, calendar.firstWeekday - 1)
        let ordered = Array(symbols[startIndex...]) + Array(symbols[..<startIndex])
        for symbol in ordered {
            let label = NSTextField(labelWithString: symbol.uppercased())
            label.alignment = .center
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = .secondaryLabelColor
            weekdaysRow.addArrangedSubview(label)
        }
    }

    private func configureCalendarGrid() {
        var rows: [[NSView]] = []
        for _ in 0..<6 {
            rows.append((0..<7).map { _ in CalendarDayView() })
        }
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 4
        grid.columnSpacing = 4
        grid.xPlacement = .fill
        grid.yPlacement = .fill
        grid.translatesAutoresizingMaskIntoConstraints = false

        for rowIndex in 0..<grid.numberOfRows { grid.row(at: rowIndex).height = 50 }
        for columnIndex in 0..<grid.numberOfColumns { grid.column(at: columnIndex).width = 66 }

        calendarGrid.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: calendarGrid.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: calendarGrid.trailingAnchor),
            grid.topAnchor.constraint(equalTo: calendarGrid.topAnchor),
            grid.bottomAnchor.constraint(equalTo: calendarGrid.bottomAnchor)
        ])
    }

    private func updateCalendar() {
        monthLabel.stringValue = dateFormatter.string(from: displayedMonth)
        yearButton.title = String(calendar.component(.year, from: displayedMonth))

        let days = monthDays(for: displayedMonth)
        guard let grid = calendarGrid.subviews.first as? NSGridView else { return }
        for index in 0..<min(days.count, 42) {
            let row = index / 7
            let column = index % 7
            (grid.cell(atColumnIndex: column, rowIndex: row).contentView as? CalendarDayView)?.configure(with: days[index])
        }
    }

    @objc private func previousMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)!
        updateCalendar()
    }

    @objc private func nextMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)!
        updateCalendar()
    }

    @objc private func showYearMenu(_ sender: NSButton) {
        let currentYear = calendar.component(.year, from: Date())
        let displayedYear = calendar.component(.year, from: displayedMonth)
        let menu = NSMenu()

        for year in (currentYear - 2)...(currentYear + 2) {
            let item = NSMenuItem(title: String(year), action: #selector(selectYear(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = year
            item.state = year == displayedYear ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: menu.item(withTitle: String(displayedYear)), at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func selectYear(_ sender: NSMenuItem) {
        guard let year = sender.representedObject as? Int else { return }
        var components = calendar.dateComponents([.year, .month], from: displayedMonth)
        components.year = year
        components.day = 1
        if let date = calendar.date(from: components) {
            displayedMonth = date
            updateCalendar()
        }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = CalendarViewController()
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 550),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Quick Calendar"
        window.contentViewController = controller
        window.center()
        window.isReleasedWhenClosed = false
        window.acceptsMouseMovedEvents = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        (NSApp as? InactivityApplication)?.restartInactivityTimer()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

private func runSelfTests() {
    let sampleCalendar = Calendar(identifier: .gregorian)
    let formatter = DateFormatter()
    formatter.calendar = sampleCalendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    let leapDay = formatter.date(from: "2024-02-29")!
    let days = monthDays(for: leapDay, today: leapDay)
    precondition(days.count == 42)
    precondition(days.filter(\.isToday).count == 1)
    precondition(days.filter { $0.isInDisplayedMonth }.count == 29)
    print("Quick Calendar self-tests passed")
}

if CommandLine.arguments.contains("--self-test") {
    runSelfTests()
} else {
    let app = InactivityApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
