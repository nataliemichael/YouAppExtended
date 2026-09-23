# You.

You is an iOS app that helps everyday people understand their own health and act on it.

## The domain problem

Around 60% of Australian adults have low health literacy (Australian Government Department of Health, Disability and Ageing, 2026). Pathology results arrive as raw numbers, referrals expire forgotten in drawers, and people leave GP appointments without asking about the results that worried them. Along with the fact that existing apps store records or book appointments, they don't translate anything. You. brings results, referrals and follow ups into one place, explains results in plain language, and nudges the user to follow through before paperwork expires.

The design stakeholder is Sana, a university student managing her own health admin for the first time (from Assessment 1). Everything in the app, from screen order to error message wording, is written for her.

## What the app does

- **Home**: anything needing attention, then pathology results newest first
- **Needs your attention**: Home picks the single most urgent thing to do next across referrals and tasks, so the patient always knows what comes first
- **Greeting**: Home asks for a first name and keeps it in UserDefaults. It is a display preference, not health data, so it stays out of the record store
- **Result detail**: each marker on a visual healthy-range bar with a plain-language explanation (educational only, never medical advice)
- **Add a result**: type a marker in from a paper report; impossible values are refused, believable ones are confirmed against the paper before saving
- **Follow-ups**: tracked referrals with expiry warnings, and tasks sorted by due date, tracking a referral automatically books a reminder three days before it expires

## Architecture

```
SwiftUI Views          HomeView, ResultDetailView, RecordResultView,
                       FollowUpsView, AddReferralView
ViewModels (MVVM)      ResultsViewModel, FollowUpsViewModel
Use Cases              RecordPathologyResultUseCase, TrackReferralUseCase,
                       PrepareAppointmentQuestionsUseCase
Domain Models + Repos  PathologyResult, MarkerReading, ReferenceRange, Referral,
                       FollowUpTask, AppointmentPrep, PatientActionable protocol
                       HealthRecordRepository
Data                   HealthRecord.json — on device only, atomic writes
```

- Business rules live only in the use cases, each throws a typed error written for the patient with a recovery path.
- Domain records are structs. The repository is the app's one shared class, behind a protocol with two implementations: in-memory (used by tests) and JSON (used by the app). Swapping storage changes one line in `YouApp`.
- Records never leave the device: no account, no cloud, honouring the privacy first commitment from Assessment 1.
- PrepareAppointmentQuestionsUseCase is built and tested but not yet wired to a screen. It is the next feature to add.

## Running it

1. Open `You.xcodeproj` in Xcode 16 or later
2. Xcode will download the Lottie package (lottie-ios) the first time the project opens. Wait for it to finish before building
3. Pick an iPhone simulator and press Cmd+R
4. First launch seeds sample records for the persona Sana; everything you add persists between launches

## Tests

Cmd+U runs 17 unit tests (Swift Testing) covering every use case: happy paths, boundary conditions (a value exactly on a range bound; a referral expiring within the reminder window) and every domain error case. Tests run against the in-memory store with fixed dates, so they are deterministic.

## Disclaimer

You. explains what markers measure in everyday words. It does not interpret results or give medical advice, that is a job for the user's GP, and the app says so.
