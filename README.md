# You.

You is an iOS app that helps everyday people understand their own health and act on it. It takes the paper that comes out of a GP visit, pathology results and referrals, and turns it into something a patient can read, keep track of and follow through on, without any of it leaving their phone.

## The problem

Around 60% of Australian adults have low health literacy (Australian Government Department of Health, Disability and Ageing, 2026). Pathology results arrive as raw numbers against a reference range nobody explains, referrals expire quietly in drawers, and people leave appointments without asking about the results that worried them. Existing apps store records or book appointments, but none of them translate anything.

The primary stakeholder is a patient managing their own health admin for the first time, someone who receives results on paper or as a PDF from the lab, holds a referral or two at once, and sees their GP a few times a year. Everything in the app, from the order of the screens to the wording of the error messages, is written for that person. The design persona is Sana, a university student, carried over from Assessment 1.

## What the app does

The app has three tabs and eight screens.

- **Home** shows what needs attention right now: results outside their healthy range on the latest report, referrals to use and tasks to do in the next fortnight, and any reports shared in from other apps that are waiting to be read. It also offers to write questions for an upcoming GP appointment.
- **Results** lists every pathology report newest first and is where a new result is added, either by picking the marker and typing the numbers, or by photographing the report and letting the app read them.
- **Result detail** shows each marker on a visual healthy range bar with a plain language explanation, and the photo of the report it came from when there is one.
- **Add a result** offers the standard GP blood panel as a picker, fills in the unit, and reads the value and healthy range off a photo of the report. Impossible values are refused, believable ones are confirmed against the paper before saving.
- **Marker list** is the catalogue of markers the app knows, grouped the way reports print them, with an Other option for anything not listed.
- **Follow-up** holds the to do list, what has been done, and every referral with its use by date.
- **Track a referral** records a referral and books a reminder task three days before it expires.
- **Before your appointment** writes one question for each result outside its healthy range, backed by that marker's history across every report, lets the patient add their own, and shares the list or saves it as a task due on the appointment day.

## Architecture

```
SwiftUI Views       HomeView, ResultsView, ResultDetailView, RecordResultView,
                    MarkerPickerView, FollowUpsView, AddReferralView,
                    AppointmentQuestionsView
ViewModels (MVVM)   ResultsViewModel, FollowUpsViewModel
Use Cases           RecordPathologyResultUseCase, TrackReferralUseCase,
                    PrepareAppointmentQuestionsUseCase, ReadReportPhotoUseCase,
                    OpenSharedReportUseCase
Domain Models       PathologyResult, MarkerReading, ReferenceRange, Referral,
                    FollowUpTask, AppointmentPrep, KnownMarker, ReportLine,
                    SharedReport, PatientActionable
Repository          HealthRecordRepository protocol
                      CoreDataHealthRecordRepository (the app and the widget)
                      InMemoryHealthRecordRepository (tests and previews)
Data                Core Data store in the App Group container
                    ReportPhotoStore and ReportInbox, folders in the same container
Services            VisionReportTextReader, ReportFileRenderer (behind protocols)
```

Business rules live only in the use cases. Each one is named for a business operation, enforces its rules in order, and throws a typed error written for the patient with a way forward. The ViewModels run the use cases and turn their errors into messages for the screens. Views never see the repository or Core Data.

The repository is defined as a protocol with two implementations. The Core Data one is what the app and the widget use. The in-memory one is the mock every unit test runs against, and the previews use it too. Swapping storage changes one line in `YouApp`.

Device frameworks sit behind small protocols in the same way, so the ViewModel that reads a report photo can be tested with a reader that answers with fixed lines of text, and the one that opens a shared PDF can be tested with a renderer that returns a fixed picture.

## The two extensions

**Coming up widget (WidgetKit).** A patient who has been handed a referral and a follow-up form needs to know what is due without opening anything. The widget reads the shared Core Data store directly, through the same repository the app uses, and shows the soonest thing to do with its countdown. The small size shows the countdown, the item and its date. The medium size adds a fortnight calendar with a dot on every day something is due. The Lock Screen size shows the countdown and the item without unlocking the phone. The patient can change how far ahead it looks, 7, 14 or 30 days, from the widget's own settings. The app calls the WidgetKit reload after every save, so the widget changes the moment a result or referral is recorded.

**Share extension.** Lab results arrive as a PDF in Mail or as a photo someone sends in Messages. From any share sheet the patient picks You and the report is saved into an inbox folder in the App Group container. The extension shows "Saved to You" and dismisses itself, and turns away anything that is not a photo or PDF with a plain message. Next time the app opens, Home shows the report with a thumbnail. Tapping it opens Add a result with the report already loaded, so picking a marker reads the value straight off it using the same text reader the camera uses. One reader, two ways in.

## Database

The app uses Core Data, with the store file inside the App Group container so the widget reads exactly what the app writes.

Core Data was chosen over CloudKit because the data has to be private and fast. Results stay on the phone with no account and no cloud, which is the privacy commitment from Assessment 1 made concrete. Home and the widget ask real questions of the record through predicates, what is due in the next fortnight, which readings are outside their healthy range from the last twelve months, rather than loading everything and filtering in memory, which matters most for the widget's tight memory budget. The schema is kept CloudKit ready, every attribute optional and an inverse on every relationship, so sync could be switched on later without a rewrite. The trade off is accepted openly: deleting the app deletes the records, and there is no sync to a second device.

Four entities in two related pairs:

- **StoredPathologyResult** owns its **StoredMarkerReading**s with a cascade delete, because a reading never exists without the report it was printed on.
- **StoredReferral** links to its **StoredFollowUpTask**s with nullify, because if a referral is removed the record of what the patient did about it should survive.

Report photos are kept as JPEG files in a folder in the App Group container, with only the file name stored in Core Data, so every fetch of results stays fast and the share extension can use the same folder. On first launch the store seeds itself with sample records for the persona, then becomes the single source of truth.

## App Group

App Group identifier: `group.com.nootnoot.You`

The main app, the widget and the share extension all have the capability. The container holds the Core Data store, the ReportPhotos folder of photos attached to results, and the Inbox folder the share extension drops reports into.

## Running it

1. Open `You.xcodeproj` in Xcode 26 or later. The deployment target is iOS 26.5.
2. Xcode downloads the Lottie package the first time the project opens. Wait for it to finish before building.
3. Select the You scheme and an iPhone simulator, then press Cmd+R. First launch seeds sample records for the persona.
4. To try the widget, go to the simulator's Home Screen, long press, and add the Coming up widget in small and medium. Long press it and choose Edit Widget to change how far ahead it looks.
5. To try the share extension, open Photos in the simulator, pick an image, tap Share and choose You. A report image can be added to the simulator with `xcrun simctl addmedia booted <file>`. Open You afterwards and the report is waiting on Home.
6. To try reading a report, add a result, pick a marker, and choose a photo of a report. The simulator has no camera, so use the photo library option there. On a phone the camera button appears as well.

## Tests

Cmd+U runs 67 unit tests in Swift Testing, all against the in-memory repository with fixed dates. They cover every use case's happy paths, boundary conditions and domain error cases, the repository's domain queries, the report reader on table style and cumulative reports, the inbox, and the ViewModels' handling of photos, shared reports and appointment questions.

## Notes

- Deleting the app deletes its records. That is by design, see the database section.
- The report reader is built for the structured shape of a results line and for table style reports. On a cumulative report with several dates per row it fills in the first value it meets, and the confirmation step is there to catch that.
- Referral letters are free text, so the camera does not read them. That would need a different approach, probably dates only.
- The marker catalogue is the standard GP blood panel. Anything else is entered as Other.
- The simulator has no camera. The photo library path is the one to test there.

## Attributions

- Lottie animations are played with [lottie-ios](https://github.com/airbnb/lottie-ios) 4.6.1 by Airbnb, via Swift Package Manager. The animations themselves come from LottieFiles and have been recoloured to the app's palette.
- The handwritten heading uses Nothing You Could Do by Kimberly Geswein, under the SIL Open Font License, included in the project.
- Core Data, WidgetKit, Vision, PDFKit and the share extension follow Apple's developer documentation and the Xcode templates.

## Disclaimer

You explains what markers measure in everyday words. It does not interpret results or give medical advice, that is a job for the patient's GP, and the app says so.
