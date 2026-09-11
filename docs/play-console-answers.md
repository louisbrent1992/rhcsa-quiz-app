# Play Console — App content & store listing answers

Reference for RHCSA Quiz (`com.louisbrent.rhcsa_quiz`).
Answers reflect what the app actually does: fully offline, no permissions,
no network, no accounts, no ads, no third-party SDKs.

## App content

### Privacy policy
URL: `<your GitHub Pages URL>` (serves `docs/index.html`)

### Sign in details
- Does your app require users to sign in? **No**
- Leave demo credentials and instructions blank.

### Ads
- Does your app contain ads? **No**
(No ad SDK is present. Answering yes adds an "Contains ads" badge you don't want.)

### Content rating
Fill the questionnaire. For this app every question is answered **No**:
- Violence, sexuality, profanity, controlled substances: No
- User-generated content / user interaction: No
- Shares location: No
- Digital purchases: No
- Category: **Reference, News, or Educational**
Expected result: Everyone / PEGI 3.

### Target audience and content
- Target age group: **18 and over** only.
  Do NOT tick any under-13 bracket — that triggers Families policy,
  which brings extra requirements and stricter review.
- Is your app appealing to children? **No**

### Data safety
- Does your app collect or share any of the required user data types? **No**
- Is all of the user data encrypted in transit? N/A (no data is transmitted)
- Do you provide a way for users to request data deletion? N/A
Note: study progress saved via `shared_preferences` lives in the app's private
sandbox and never leaves the device. Play does not count on-device-only storage
as collection, so "No data collected" is the accurate answer.

### Government apps
- Is your app a government app? **No**

### Financial features
- Does your app provide financial features? **No**

### Health
- Does your app have health features? **No**

## Store presence

### App category and contact details
- App or game: **App**
- Category: **Education**
- Tags: education, study, reference
- Contact email: louisbrent1992@gmail.com  (shown publicly on the listing)
- Website / phone: optional, may be left blank

### Store listing
- App name (30 chars max): `RHCSA Quiz`
- Short description (80 chars max):
  `Offline practice quiz for the RHCSA exam objectives. Unofficial study aid.`
- Full description (4000 chars max): draft below.

Graphics required before you can publish:
- App icon: 512x512 PNG, 32-bit
- Feature graphic: 1024x500 PNG or JPG
- Phone screenshots: at least 2 (16:9 or 9:16, min 320px on the short side)

### Full description draft

RHCSA Quiz is an offline practice tool for anyone studying the Red Hat Certified
System Administrator exam objectives.

Work through practice questions organised by exam objective, check your answers
with explanations, and track which topics you have covered. Everything runs
entirely on your device.

FEATURES
- Practice questions grouped by exam objective
- Answer explanations so a missed question teaches you something
- Local progress tracking across sessions
- Works completely offline — no account, no sign-up
- No ads, no tracking, no data collection

RHCSA Quiz is an independent, unofficial study aid. It is not affiliated with,
endorsed by, or sponsored by Red Hat, Inc. Red Hat and RHCSA are trademarks of
Red Hat, Inc. This app does not provide certification and is not a substitute
for official Red Hat training.

## Known blockers before rollout
- [ ] Privacy policy URL live and reachable
- [ ] All App content sections green
- [ ] Store listing graphics uploaded
- [ ] `android:label` and pubspec description set to real values
- [ ] Version bumped in pubspec.yaml for each upload
